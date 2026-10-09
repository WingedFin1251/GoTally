// entry/src/main/ets/data/ConsoleAggregator.ets
import { http } from '@kit.NetworkKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { Constants } from '../common/constants/Constants';
import { WebCookies } from '../common/utils/WebCookies';
import { ConsoleSnapshotStore } from './ConsoleSnapshotStore';
import { ConsoleCsv } from './ConsoleCsv';
import { ConsoleIntraday } from './ConsoleIntraday';
import type { Totals, ModelStat, DailyStat, TrendPoint, SessionStat, RecordRow, UsageAggregator } from '../model/Stats';

/** 控制台用量通用字段（summary 与 models 条目共用）。 */
interface ConsoleUsageFields {
  totalRequests?: string;
  totalInputTokens?: string;
  totalOutputTokens?: string;
  totalCacheReadTokens?: string;
  totalCacheWrite5mTokens?: string;
  totalCacheWrite1hTokens?: string;
  totalCostMicroCents?: string;
}

/** 控制台 /console/api/usage/summary 响应（字段均为字符串）。 */
interface ConsoleSummary extends ConsoleUsageFields {
}

interface ConsoleModelItem extends ConsoleUsageFields {
  model?: string;
  provider?: string;
}

interface ConsoleModelsResponse {
  items?: ConsoleModelItem[];
}

/** 控制台 /console/api/usage/cost-by-day 单日。 */
interface ConsoleDayItem {
  date?: string;
  totalCostMicroCents?: string;
  totalTokens?: string;
  totalRequests?: string;
}

/** 控制台 /console/api/orgs 单项（用于发现工作区 ID）。 */
interface ConsoleOrgLite {
  id?: string;
  name?: string;
}

/**
 * 控制台聚合数据源（新登录方式下的主数据源）。
 *
 * 背景：OpenCode 更换鉴权后，旧的逐请求明细接口（`_server usage.list`）对会话 cookie 已不生效，
 * 本地因此没有记录；但控制台提供了官方聚合接口，用同一会话 cookie 即可读取（**必须带 `x-org-id`**）：
 *   GET /console/api/usage/summary        总量
 *   GET /console/api/usage/models         模型维度
 *   GET /console/api/usage/cost-by-day    按天
 * 策略：本地有记录时用本地（明细更全），本地为空时回退到控制台聚合数据。
 */
export class ConsoleAggregator implements UsageAggregator {
  private local: UsageAggregator;
  private tokenProvider: () => Promise<string>;
  private wsProvider: () => Promise<string>;
  private static cache: Map<string, string> = new Map<string, string>();
  private static cacheAt: Map<string, number> = new Map<string, number>();
  private static wsCache: string = '';
  /** 最近一次请求是否只能拿到「过期缓存/快照」（网络失败时为 true）。 */
  private static lastStale: boolean = false;
  private static readonly TTL_MS: number = 60000;

  constructor(local: UsageAggregator, tokenProvider: () => Promise<string>, wsProvider: () => Promise<string>) {
    this.local = local;
    this.tokenProvider = tokenProvider;
    this.wsProvider = wsProvider;
  }

  /** 使聚合缓存失效（「立即刷新」/同步按钮触发，强制下次读取实时官方数据）。 */
  static invalidate(): void {
    ConsoleAggregator.cache.clear();
    ConsoleAggregator.cacheAt.clear();
  }

  async totals(period: string): Promise<Totals> {
    const t = await this.local.totals(period);
    if (t.requestCount > 0) {
      return t;
    }
    const key = `t:${period}`;
    const json = await this.getJson(`/console/api/usage/summary${ConsoleAggregator.rangeQuery(period)}`);
    if (json !== null) {
      const mapped = ConsoleAggregator.mapTotals(JSON.parse(json) as ConsoleSummary);
      await ConsoleSnapshotStore.saveTotals(key, mapped);
      if (period === Constants.PERIOD_TODAY) {
        // 顺带记一个当日累计采样点：官方无小时级接口，「今日趋势」靠这些采样点重建
        await ConsoleSnapshotStore.appendIntradaySample(mapped.totalInputTokens,
          mapped.totalOutputTokens, mapped.requestCount, mapped.totalCostUsd, Date.now());
      }
      ConsoleAggregator.setStale(false);
      return mapped;
    }
    // 网络不可用：回退到本地快照（离线可看上次的官方数据）
    const cached = await ConsoleSnapshotStore.loadTotals(key);
    if (cached !== null) {
      ConsoleAggregator.setStale(true);
      return cached;
    }
    return t;
  }

  async modelStats(period: string): Promise<ModelStat[]> {
    const rows = await this.local.modelStats(period);
    if (rows.length > 0) {
      return rows;
    }
    // 「全部」：若本地累计历史已超出官方窗口（> 30 天），用历史明细汇总更长期限的排行
    if (period === Constants.PERIOD_ALL) {
      const days = await ConsoleSnapshotStore.historyDayCount();
      if (days > 30) {
        const hist = await ConsoleSnapshotStore.loadHistoryModelStats();
        if (hist.length > 0) {
          return hist;
        }
      }
    }
    const key = `m:${period}`;
    const json = await this.getJson(`/console/api/usage/models${ConsoleAggregator.rangeQuery(period)}`);
    if (json !== null) {
      const data = JSON.parse(json) as ConsoleModelsResponse;
      const items = data.items !== undefined ? data.items : [];
      const out: ModelStat[] = [];
      for (const it of items) {
        const model = it.model !== undefined ? it.model : '';
        if (model === '') {
          continue;
        }
        const base = ConsoleAggregator.mapTotals(it);
        out.push({
          model: model,
          requestCount: base.requestCount,
          sessionCount: 0,
          totalInputTokens: base.totalInputTokens,
          uncachedInputTokens: base.uncachedInputTokens,
          totalReasoningTokens: 0,
          cacheHitTokens: base.cacheHitTokens,
          cacheWriteTokens: base.cacheWriteTokens,
          totalOutputTokens: base.totalOutputTokens,
          totalCostUsd: base.totalCostUsd,
          hitRate: base.hitRate,
        });
      }
      await ConsoleSnapshotStore.saveModels(key, out);
      ConsoleAggregator.setStale(false);
      return out;
    }
    const cached = await ConsoleSnapshotStore.loadModels(key);
    if (cached.length > 0) {
      ConsoleAggregator.setStale(true);
      return cached;
    }
    return rows;
  }

  async dailyStats(days: number): Promise<DailyStat[]> {
    const rows = await this.local.dailyStats(days);
    if (rows.length > 0) {
      return rows;
    }
    const key = `d:${days}`;
    const json = await this.getJson(`/console/api/usage/cost-by-day${ConsoleAggregator.rangeForDays(days)}`);
    if (json !== null) {
      const items = JSON.parse(json) as ConsoleDayItem[];
      const out: DailyStat[] = [];
      for (const it of items) {
        const date = it.date !== undefined ? it.date : '';
        if (date === '') {
          continue;
        }
        out.push({
          date: date,
          // 控制台按天只给总量：整块计入输入侧（总 TOKEN 口径一致），费用/请求数精确
          totalInputTokens: ConsoleAggregator.n(it.totalTokens),
          uncachedInputTokens: 0,
          totalReasoningTokens: 0,
          cacheHitTokens: 0,
          cacheWriteTokens: 0,
          totalOutputTokens: 0,
          totalCostUsd: ConsoleAggregator.n(it.totalCostMicroCents) / 1e8,
          requestCount: ConsoleAggregator.n(it.totalRequests),
          hitRate: 0,
        });
      }
      await ConsoleSnapshotStore.saveDaily(key, out);
      // 并入本地累计历史：官方窗口只有 30 天，滑出窗口的日期靠这里留住
      await ConsoleSnapshotStore.appendHistory(out);
      ConsoleAggregator.setStale(false);
      if (days >= 90) {
        // 「全部」：优先展示本地累计的更长期历史（可能已超过官方 30 天窗口）
        const hist = await ConsoleSnapshotStore.loadHistory();
        if (hist.length > out.length) {
          return hist;
        }
      }
      return out;
    }
    const cached = await ConsoleSnapshotStore.loadDaily(key);
    if (cached.length > 0) {
      ConsoleAggregator.setStale(true);
      return cached;
    }
    if (days >= 90) {
      const hist = await ConsoleSnapshotStore.loadHistory();
      if (hist.length > 0) {
        ConsoleAggregator.setStale(true);
        return hist;
      }
    }
    return rows;
  }

  /** 离线快照标志：界面据此提示「离线快照」。仅在状态变化时写，避免无谓刷新。 */
  private static setStale(stale: boolean): void {
    if (AppStorage.get<boolean>('consoleStale') !== stale) {
      AppStorage.setOrCreate('consoleStale', stale);
    }
  }

  /** 最近一次聚合数据是否来自缓存/快照（供界面决定「失败时保留上次数值」）。 */
  static isStale(): boolean {
    return ConsoleAggregator.lastStale;
  }

  /**
   * 今日逐小时趋势。
   *
   * 官方控制台**没有小时级接口**，所以：
   *  1. 旧登录（能同步逐条明细）→ 用本地明细逐小时聚合（真实数据）；
   *  2. 控制台登录 → 用每次刷新记录的**当日累计采样点**重建逐小时用量。
   */
  async todayTrend(): Promise<TrendPoint[]> {
    const rows = await this.local.todayTrend();
    if (rows.length > 0) {
      return rows;
    }
    return ConsoleSnapshotStore.buildTodayTrend();
  }

  /** 逐条明细控制台不提供，保留本地（新登录下为空）。 */
  async sessionStatsPage(page: number, pageSize: number, period: string): Promise<[SessionStat[], number]> {
    return this.local.sessionStatsPage(page, pageSize, period);
  }

  async usageRecordsPage(page: number, pageSize: number, model: string | null, period: string): Promise<[RecordRow[], number]> {
    return this.local.usageRecordsPage(page, pageSize, model, period);
  }

  async listModels(): Promise<string[]> {
    return this.local.listModels();
  }

  // ---- 周期 → 控制台 range 参数 ----
  private static rangeQuery(period: string): string {
    if (period === Constants.PERIOD_TODAY) {
      return '?range=24h';
    }
    if (period === '7d') {
      return '?range=7d';
    }
    if (period === '30d') {
      return '?range=30d';
    }
    return '';
  }

  private static rangeForDays(days: number): string {
    if (days <= 1) {
      return '?range=24h';
    }
    if (days <= 7) {
      return '?range=7d';
    }
    return '?range=30d';
  }

  /** 带 TTL 缓存的 JSON 读取（自动补 x-org-id）；未登录或失败返回 null。 */
  private async getJson(path: string): Promise<string | null> {
    let token = '';
    try {
      token = (await this.tokenProvider()).trim();
    } catch (e) {
      token = '';
    }
    if (token === '') {
      return null;
    }
    const org = await this.resolveOrgId(token);
    if (org === '') {
      return null;
    }
    return ConsoleAggregator.request(path, org, token);
  }

  /**
   * 工作区 ID：优先本地已解析的值，缺失时用 `/console/api/orgs`（该接口无需 x-org-id）发现。
   * 控制台的 usage/go 接口都要求 `x-org-id`，缺了会直接 400。
   */
  private async resolveOrgId(token: string): Promise<string> {
    if (ConsoleAggregator.wsCache !== '') {
      return ConsoleAggregator.wsCache;
    }
    let hint = '';
    try {
      hint = (await this.wsProvider()).trim();
    } catch (e) {
      hint = '';
    }
    const m = /wrk_[A-Za-z0-9]+/.exec(hint);
    if (m !== null) {
      ConsoleAggregator.wsCache = m[0];
      return ConsoleAggregator.wsCache;
    }
    const json = await ConsoleAggregator.request('/console/api/orgs', '', token);
    if (json !== null) {
      const arr = JSON.parse(json) as ConsoleOrgLite[];
      for (const o of arr) {
        const id = o.id !== undefined ? o.id : '';
        if (id !== '') {
          ConsoleAggregator.wsCache = id;
          return id;
        }
      }
    }
    return '';
  }

  /**
   * 用官方 CSV 导出（`/console/api/v2/usage/export`，支持 90d）回填本地历史。
   *
   * 比 JSON 接口强的地方：窗口 30d → **90d**，且给出「天 × 模型」的
   * requests / input / output / cache 明细。成功返回 true，失败则由调用方退回 JSON 路径。
   */
  static async backfillFromCsv(token: string): Promise<boolean> {
    const t = token.trim();
    if (t === '') {
      return false;
    }
    try {
      const orgJson = await ConsoleAggregator.request('/console/api/orgs', '', t);
      if (orgJson === null) {
        return false;
      }
      let org = ConsoleAggregator.wsCache;
      if (org === '') {
        const orgs = JSON.parse(orgJson) as ConsoleOrgLite[];
        for (const o of orgs) {
          const id = o.id !== undefined ? o.id : '';
          if (id !== '') {
            org = id;
            ConsoleAggregator.wsCache = id;
            break;
          }
        }
      }
      if (org === '') {
        return false;
      }
      const csv = await ConsoleAggregator.request('/console/api/v2/usage/export?range=90d', org, t);
      if (csv === null) {
        return false;
      }
      const rows = ConsoleCsv.parse(csv);
      if (rows.length === 0) {
        return false;
      }
      await ConsoleSnapshotStore.appendHistory(ConsoleCsv.aggregateByDay(rows));
      await ConsoleSnapshotStore.appendHistoryModels(rows);
      // 今日趋势采样：CSV 中「今天」的各模型行相加即为当日累计值（无需额外请求），
      // 这样即使用户停留在别的页面，小时级曲线也能持续累积。
      const today = ConsoleIntraday.localDay(new Date());
      let inSum = 0;
      let outSum = 0;
      let reqSum = 0;
      let costSum = 0;
      let hasToday = false;
      for (const r of rows) {
        if (r.day === today) {
          hasToday = true;
          inSum += r.inputTokens + r.cacheRead + r.cacheWrite;
          outSum += r.outputTokens;
          reqSum += r.requests;
          costSum += r.costUsd;
        }
      }
      if (hasToday) {
        await ConsoleSnapshotStore.appendIntradaySample(inSum, outSum, reqSum, costSum, Date.now());
      }
      return true;
    } catch (e) {
      console.error('backfillFromCsv failed: ' + (e instanceof Error ? e.message : String(e)));
      return false;
    }
  }

  /**
   * 主动把官方逐日数据并入本地历史（优先 CSV 90d，失败退回 JSON 30d）。
   *
   * 为什么需要：逐日数据只在「当前浏览的周期」被拉取，若用户只看「今天」，
   * 历史就攒不到整天。每次刷新（含自动刷新）都调用本方法，保证历史始终尽量完整，
   * 从而让滑出官方窗口的日期不会丢。
   */
  static async captureHistory(token: string): Promise<void> {
    if (await ConsoleAggregator.backfillFromCsv(token)) {
      return;
    }
    await ConsoleAggregator.captureHistoryJson(token);
  }

  /** JSON 兜底：把官方 30 天窗口的逐日数据并入本地历史。 */
  static async captureHistoryJson(token: string): Promise<void> {
    const t = token.trim();
    if (t === '') {
      return;
    }
    try {
      // 该接口无需 x-org-id，可直接发现工作区
      const orgJson = await ConsoleAggregator.request('/console/api/orgs', '', t);
      if (orgJson === null) {
        return;
      }
      const orgs = JSON.parse(orgJson) as ConsoleOrgLite[];
      let org = ConsoleAggregator.wsCache;
      if (org === '') {
        for (const o of orgs) {
          const id = o.id !== undefined ? o.id : '';
          if (id !== '') {
            org = id;
            ConsoleAggregator.wsCache = id;
            break;
          }
        }
      }
      if (org === '') {
        return;
      }
      const json = await ConsoleAggregator.request('/console/api/usage/cost-by-day?range=30d', org, t);
      if (json === null) {
        return;
      }
      const items = JSON.parse(json) as ConsoleDayItem[];
      const out: DailyStat[] = [];
      for (const it of items) {
        const date = it.date !== undefined ? it.date : '';
        if (date === '') {
          continue;
        }
        out.push({
          date: date,
          totalInputTokens: ConsoleAggregator.n(it.totalTokens),
          uncachedInputTokens: 0,
          totalReasoningTokens: 0,
          cacheHitTokens: 0,
          cacheWriteTokens: 0,
          totalOutputTokens: 0,
          totalCostUsd: ConsoleAggregator.n(it.totalCostMicroCents) / 1e8,
          requestCount: ConsoleAggregator.n(it.totalRequests),
          hitRate: 0,
        });
      }
      await ConsoleSnapshotStore.appendHistory(out);
    } catch (e) {
      console.error('captureHistory failed: ' + (e instanceof Error ? e.message : String(e)));
    }
  }

  private static async request(path: string, orgId: string, token: string): Promise<string | null> {    const now = Date.now();
    const at = ConsoleAggregator.cacheAt.get(path);
    if (at !== undefined && now - at < ConsoleAggregator.TTL_MS) {
      const hit = ConsoleAggregator.cache.get(path);
      if (hit !== undefined) {
        return hit;
      }
    }
    const header: Record<string, string> = {
      'Cookie': ConsoleAggregator.consoleCookie(token),
      'Accept': 'application/json',
      'User-Agent': Constants.USER_AGENT,
      'Origin': Constants.OPENCODE_ORIGIN,
      'Referer': `${Constants.OPENCODE_ORIGIN}/console`,
    };
    if (orgId !== '') {
      header['x-org-id'] = orgId;
    }
    // 统计页会并发拉取 summary/models/cost-by-day，实测偶发单条失败（BusinessError）：
    // 失败重试一次，避免一条抖动导致整块指标为 0。
    let lastErr = '';
    for (let attempt = 0; attempt < 2; attempt++) {
      const req = http.createHttp();
      try {
        const resp = await req.request(`${Constants.OPENCODE_ORIGIN}${path}`, {
          method: http.RequestMethod.GET,
          header: header,
          connectTimeout: Constants.REQUEST_TIMEOUT_MS,
          readTimeout: Constants.REQUEST_TIMEOUT_MS,
        });
        req.destroy();
        if (resp.responseCode === 200) {
          const text = resp.result as string;
          ConsoleAggregator.cache.set(path, text);
          ConsoleAggregator.cacheAt.set(path, now);
          ConsoleAggregator.lastStale = false;
          return text;
        }
        lastErr = `HTTP ${resp.responseCode}`;
      } catch (e) {
        req.destroy();
        lastErr = ConsoleAggregator.errText(e);
      }
      if (attempt === 0) {
        await ConsoleAggregator.sleep(400);
      }
    }
    console.error(`console api failed [${path}] org=${orgId === '' ? 'none' : 'set'} ${lastErr}`);
    // 网络失败时，先用「过期缓存」顶上（避免界面闪 0），并标记为陈旧
    const stale = ConsoleAggregator.cache.get(path);
    if (stale !== undefined) {
      ConsoleAggregator.lastStale = true;
      ConsoleAggregator.setStale(true);
      return stale;
    }
    ConsoleAggregator.lastStale = true;
    return null;
  }

  /** BusinessError 不是 Error 实例，直接 String() 会得到 [object Object]，这里取出 code/message。 */
  private static errText(e: Object): string {
    const be = e as BusinessError;
    if (be !== undefined && be.code !== undefined) {
      return `code=${be.code} msg=${be.message}`;
    }
    return e instanceof Error ? e.message : String(e);
  }

  private static sleep(ms: number): Promise<void> {
    return new Promise<void>((resolve: () => void) => {
      setTimeout(resolve, ms);
    });
  }

  /** 控制台接口所需 cookie：优先现读控制台会话，退回整串凭据。 */
  private static consoleCookie(token: string): string {
    const session = WebCookies.read(Constants.CONSOLE_COOKIE_NAME, Constants.OPENCODE_ORIGIN);
    if (session !== '') {
      return `${Constants.CONSOLE_COOKIE_NAME}=${session}`;
    }
    return token;
  }

  private static n(v: string | undefined): number {
    const x = v !== undefined ? Number(v) : 0;
    return Number.isNaN(x) ? 0 : x;
  }

  /** 控制台字段 → 本地口径 Totals（控制台 totalInputTokens 为「未命中输入」）。 */
  private static mapTotals(s: ConsoleUsageFields): Totals {
    const uncached = ConsoleAggregator.n(s.totalInputTokens);
    const cacheRead = ConsoleAggregator.n(s.totalCacheReadTokens);
    const cacheWrite = ConsoleAggregator.n(s.totalCacheWrite5mTokens) + ConsoleAggregator.n(s.totalCacheWrite1hTokens);
    const denom = cacheRead + uncached;
    return {
      requestCount: ConsoleAggregator.n(s.totalRequests),
      sessionCount: 0,
      totalInputTokens: uncached + cacheRead + cacheWrite,
      uncachedInputTokens: uncached,
      totalReasoningTokens: 0,
      cacheHitTokens: cacheRead,
      cacheWriteTokens: cacheWrite,
      totalOutputTokens: ConsoleAggregator.n(s.totalOutputTokens),
      totalCostUsd: ConsoleAggregator.n(s.totalCostMicroCents) / 1e8,
      hitRate: denom > 0 ? Number(((cacheRead / denom) * 100).toFixed(2)) : 0,
    };
  }
}
// entry/src/main/ets/network/SyncManager.ets
import { Constants } from '../common/constants/Constants';
import { ConsoleAggregator } from '../data/ConsoleAggregator';
import { OpenCodeApi } from './OpenCodeApi';
import type { ConsoleUsagePage } from './OpenCodeApi';
import type { UsageStore } from '../data/UsageStore';
import type { UsageFetcher } from './UsageFetcher';
import type { UsageRecord } from '../model/UsageRecord';
import type { KeyNamePair } from '../model/Stats';

export interface SyncProgress {
  running: boolean;
  mode: string;
  page: number;
  inserted: number;
  phase: string; // idle | usage | done | error
  message: string;
}

export interface SyncResult {
  ok: boolean;
  error?: string;
  inserted?: number;
  partial?: boolean;
  failedPages?: number;
}

const IDLE_PROGRESS: SyncProgress = { running: false, mode: '', page: 0, inserted: 0, phase: 'idle', message: '' };

/** 同步状态机：增量/全量拉取、去重写入、窗口裁剪、进度回调。 */
export class SyncManager {
  private store: UsageStore;
  private fetcher: UsageFetcher;
  private progress: SyncProgress = SyncManager.copyProgress(IDLE_PROGRESS);
  private busy = false;
  private timer: number | null = null;
  private intervalProvider: () => Promise<number>;
  private resolveWorkspace: ((hint: string, token: string) => Promise<string>) | null;
  /** 可选的 Key 名称拉取器（同步收尾时刷新 key_id → 名称缓存）。 */
  private keyNameFetcher: ((workspaceId: string, token: string) => Promise<KeyNamePair[]>) | null;
  /** 最近一次「启动即刷新」的时间戳：避免页面频繁 onPageShow 造成重复刷新。 */
  private lastAutoKickMs: number = 0;
  /** 本次同步开始时间：用于看门狗判断 busy 是否卡死。 */
  private busySince: number = 0;
  onProgress: (p: SyncProgress) => void = () => {};
  /** 同步终止回调（成功/部分成功/失败均触发，且无论哪个页面在前台）：供应用外壳统一广播「数据已变更」。 */
  onFinished: (result: SyncResult) => void = () => {};

  constructor(
    store: UsageStore,
    fetcher: UsageFetcher,
    intervalProvider?: () => Promise<number>,
    resolveWorkspace?: (hint: string, token: string) => Promise<string>,
    keyNameFetcher?: (workspaceId: string, token: string) => Promise<KeyNamePair[]>) {
    this.store = store;
    this.fetcher = fetcher;
    this.intervalProvider = intervalProvider !== undefined ? intervalProvider : async (): Promise<number> => 300;
    this.resolveWorkspace = resolveWorkspace !== undefined ? resolveWorkspace : null;
    this.keyNameFetcher = keyNameFetcher !== undefined ? keyNameFetcher : null;
  }

  /** 拉取并合并保存 Key 名称映射；任何失败都只记日志，不影响同步结果与既有缓存。 */
  private async refreshKeyNames(workspaceId: string, token: string): Promise<void> {
    if (this.keyNameFetcher === null) {
      return;
    }
    try {
      const pairs = await this.keyNameFetcher(workspaceId, token);
      if (pairs.length > 0) {
        await this.store.saveKeyNames(pairs);
      }
    } catch (e) {
      console.error('refreshKeyNames failed: ' + (e instanceof Error ? e.message : String(e)));
    }
  }

  getProgress(): SyncProgress {
    return SyncManager.copyProgress(this.progress);
  }

  private static copyProgress(p: SyncProgress): SyncProgress {
    return { running: p.running, mode: p.mode, page: p.page, inserted: p.inserted, phase: p.phase, message: p.message };
  }

  private setPhase(phase: string, message: string): void {
    this.progress.phase = phase;
    this.progress.message = message;
    this.progress.running = phase === 'usage';
    this.onProgress(this.getProgress());
  }

  /** 终止收尾：复位 busy 并广播终止事件（所有终止分支统一走这里，避免漏通知导致界面数据不刷新）。 */
  private finish(result: SyncResult): SyncResult {
    this.busy = false;
    this.onFinished(result);
    return result;
  }

  async sync(mode: 'incremental' | 'full'): Promise<SyncResult> {
    const token = await this.store.getToken();
    if (token.trim() === '') {
      return { ok: false, error: '未登录' };
    }
    if (this.busy) {
      // 看门狗：正常路径都会经 finish() 复位；万一异常路径漏了复位（写库抛错等），
      // 超过 10 分钟视为卡死并强制重开，否则「同步」按钮会永远点不动。
      if (Date.now() - this.busySince < 600000) {
        return { ok: false, error: '已有同步任务进行中' };
      }
      console.error('sync: resetting stale busy flag after 10min');
      this.busy = false;
    }
    this.busy = true;
    this.busySince = Date.now();
    this.progress.mode = mode;
    this.progress.page = 0;
    this.progress.inserted = 0;
    this.setPhase('usage', '');

    try {
      let workspaceId = await this.store.getWorkspaceHint();
      if (this.resolveWorkspace !== null && !workspaceId.startsWith('wrk_')) {
        try {
          workspaceId = await this.resolveWorkspace(workspaceId, token);
          await this.store.saveResolvedWorkspace(workspaceId);
        } catch (e) {
          const msg = e instanceof Error ? e.message : String(e);
          await this.store.updateSyncState('error', msg, 0);
          this.setPhase('error', msg);
          return this.finish({ ok: false, error: msg });
        }
      }
      const windowDays = await this.store.getWindowDays();
      // 控制台会话（cookie 里已无 auth）：明细走新接口 `/console/api/request-logs`
      //（旧 `/_server` 明细 server-fn 已失效，不再是「没有明细」——新接口可用）
      if (!token.includes('auth=')) {
        const consoleInserted = await this.syncConsoleDetail(workspaceId, token, mode, windowDays);
        await this.refreshKeyNames(workspaceId, token);
        // 官方聚合数据与历史同步刷新（配额/总览/趋势 + 90 天历史 + 离线快照）
        ConsoleAggregator.invalidate();
        await ConsoleAggregator.captureHistory(token);
        await this.store.updateSyncState('ok', '', consoleInserted);
        this.progress.inserted = consoleInserted;
        this.setPhase('done', `已同步 ${consoleInserted} 条明细`);
        return this.finish({ ok: true, inserted: consoleInserted });
      }

      const maxPages = mode === 'full' ? Constants.MAX_FULL_PAGES : Constants.INCREMENTAL_PAGES;
      let totalInserted = 0;
      let failedPages = 0;
      let page = 0;
      let emptyBatches = 0;

      while (page < maxPages) {
        const batchPages: number[] = [];
        for (let p = page; p < Math.min(page + Constants.FETCH_BATCH, maxPages); p++) {
          batchPages.push(p);
        }
        this.progress.page = page;
        this.onProgress(this.getProgress());

        const results: Array<UsageRecordOrError> = [];
        for (const p of batchPages) {
          results.push(await this.fetchOne(workspaceId, p));
        }

        let batchInserted = 0;
        let batchFullPages = 0;
        let batchFailed = 0;
        for (let i = 0; i < results.length; i++) {
          const result = results[i];
          if (result.error !== undefined) {
            batchFailed += 1;
            failedPages += 1;
            continue;
          }
          const recs = result.records;
          if (recs.length === 0) {
            continue;
          }
          const inserted = await this.store.insertUsageRecords(recs);
          totalInserted += inserted;
          batchInserted += inserted;
          if (recs.length >= Constants.PAGE_SIZE) {
            batchFullPages += 1;
          }
          this.progress.inserted = totalInserted;
          this.onProgress(this.getProgress());
        }

        page += Constants.FETCH_BATCH;

        if (batchFailed > 0) {
          if (mode === 'incremental') {
            const msg = '网络请求失败 (超时/中断)';
            this.setPhase('error', msg);
            await this.store.updateSyncState('error', msg, totalInserted);
            return this.finish({ ok: false, error: msg, inserted: totalInserted });
          }
        }

        if (batchFullPages === 0) {
          break;
        }
        if (mode === 'incremental' && batchInserted === 0) {
          emptyBatches += 1;
          if (emptyBatches >= 2) {
            break;
          }
        } else {
          emptyBatches = 0;
        }
      }

      if (windowDays !== null && windowDays > 0) {
        await this.store.pruneOldRecords(windowDays);
      }

      // 刷新 API Key 名称缓存（合并写入；单次失败不清空既有名称）
      await this.refreshKeyNames(workspaceId, token);

      if (failedPages > 0) {
        await this.store.updateSyncState('partial', '部分页拉取失败 (数据可能不完整)', totalInserted);
        this.setPhase('done', '部分页拉取失败');
        return this.finish({ ok: true, partial: true, failedPages: failedPages, inserted: totalInserted });
      }

      await this.store.updateSyncState('ok', '', totalInserted);
      this.setPhase('done', `同步完成, 新增 ${totalInserted} 条`);
      return this.finish({ ok: true, inserted: totalInserted });
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      await this.store.updateSyncState('error', msg, this.progress.inserted);
      this.setPhase('error', msg);
      return this.finish({ ok: false, error: msg });
    }
  }

  /**
   * 控制台会话下的逐条明细同步（`GET /console/api/request-logs`）。
   *
   * 与旧接口的差异：**游标分页**（按时间倒序，不能并发跳页）、单页上限 100 条、
   * 服务端只保留 30 天明细；增量同步用 `since`（本地最新记录往前留 1 小时重叠防边界漏记）。
   * 命中不到更早的数据就停止翻页，既快又省请求。
   */
  private async syncConsoleDetail(workspaceId: string, token: string, mode: string,
    windowDays: number | null): Promise<number> {
    const maxPages = mode === 'full' ? Constants.MAX_FULL_PAGES : Constants.INCREMENTAL_PAGES;
    let sinceMs = 0;
    if (mode !== 'full') {
      const state = await this.store.getSyncState();
      if (state.newestRecordAt !== '') {
        const ms = Date.parse(state.newestRecordAt) - Constants.INCREMENTAL_OVERLAP_MS;
        sinceMs = Number.isNaN(ms) || ms <= 0 ? 0 : ms;
      }
    }
    // 同步窗口边界（0 表示不限，交由官方 30 天保留期约束）
    const boundaryMs = windowDays !== null && windowDays > 0 ? Date.now() - windowDays * 86400000 : 0;
    let cursor = '';
    let page = 0;
    let inserted = 0;
    while (page < maxPages) {
      this.progress.page = page;
      this.onProgress(this.getProgress());
      let pageData: ConsoleUsagePage;
      try {
        pageData = await OpenCodeApi.fetchConsoleUsagePage(token, workspaceId, cursor,
          Constants.CONSOLE_LOGS_MAX_LIMIT, sinceMs);
      } catch (e) {
        const msg = e instanceof Error ? e.message : String(e);
        console.error(`console detail page ${page} failed: ${msg}`);
        break;
      }
      if (pageData.records.length === 0) {
        break;
      }
      // 记录按时间倒序返回：早于同步窗口边界的丢弃，并停止继续翻页
      const keep: UsageRecord[] = [];
      let reachedBoundary = false;
      for (const r of pageData.records) {
        const t = Date.parse(r.createdAt);
        if (boundaryMs > 0 && !Number.isNaN(t) && t < boundaryMs) {
          reachedBoundary = true;
          continue;
        }
        keep.push(r);
      }
      if (keep.length > 0) {
        inserted += await this.store.insertUsageRecords(keep);
        this.progress.inserted = inserted;
        this.onProgress(this.getProgress());
      }
      if (reachedBoundary || pageData.nextCursor === '') {
        break;
      }
      cursor = pageData.nextCursor;
      page++;
    }
    if (windowDays !== null && windowDays > 0) {
      await this.store.pruneOldRecords(windowDays);
    }
    return inserted;
  }

  private async fetchOne(workspaceId: string, page: number): Promise<UsageRecordOrError> {
    try {
      const records = await this.fetcher.fetchUsagePage(workspaceId, page);
      return { records: records };
    } catch (e) {
      return { records: [], error: e instanceof Error ? e.message : String(e) };
    }
  }

  async startAutoSyncLoop(): Promise<void> {
    this.stopAutoSync();
    const intervalSec = await this.intervalProvider();
    // 启动即刷新一次（60 秒内不重复）：否则只在定时器到点才刷新，
    // 用户开应用不到一个间隔就退出时，当天的数据（及官方 30 天窗口历史）就抓不到。
    const now = Date.now();
    if (!this.busy && now - this.lastAutoKickMs > 60000) {
      this.lastAutoKickMs = now;
      this.sync('incremental');
    }
    this.timer = setInterval(() => {
      if (this.busy) {
        return;
      }
      this.sync('incremental');
    }, intervalSec * 1000) as number;
  }

  stopAutoSync(): void {
    if (this.timer !== null) {
      clearInterval(this.timer);
      this.timer = null;
    }
  }
}

interface UsageRecordOrError {
  records: UsageRecord[];
  error?: string;
}

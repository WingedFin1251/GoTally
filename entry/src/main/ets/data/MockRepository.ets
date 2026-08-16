// entry/src/main/ets/data/MockRepository.ets
import type { UsageStore } from './UsageStore';
import type { UsageRecord, SyncState } from '../model/UsageRecord';
import type { Totals, ModelStat, DailyStat, TrendPoint, SessionStat, RecordRow } from '../model/Stats';
import { Constants } from '../common/constants/Constants';

interface HourBucket {
  input: number;
  output: number;
  reasoning: number;
}

function seedRecords(): UsageRecord[] {
  const out: UsageRecord[] = [];
  const models: string[] = ['gpt-4o', 'claude-opus-4', 'deepseek-chat', 'glm-4-plus', 'qwen-max'];
  const now = Date.now();
  for (let i = 0; i < 800; i++) {
    const ts = now - i * 5400 * 1000; // 每 1.5 小时一条，覆盖约 50 天
    const input = 800 + Math.floor(Math.random() * 12000);
    const output = 300 + Math.floor(Math.random() * 4000);
    const reasoning = Math.floor(Math.random() * 2000);
    const cacheRead = Math.floor(Math.random() * 20000);
    const cacheWrite = Math.floor(Math.random() * 3000);
    const costRaw = Math.floor((input + output) * 8 + Math.random() * 1000);
    out.push({
      usgId: `usg_mock_${i}`,
      createdAt: new Date(ts).toISOString(),
      model: models[i % models.length],
      provider: models[i % models.length].split('-')[0],
      inputTokens: input,
      outputTokens: output,
      reasoningTokens: reasoning,
      cacheReadTokens: cacheRead,
      cacheWrite5mTokens: cacheWrite,
      cacheWrite1hTokens: 0,
      costRaw: costRaw,
      costUsd: costRaw / 100000000,
      keyId: 'k1',
      sessionId: `ses_${Math.floor(i / 6)}`,
      plan: 'pro',
      syncedAt: new Date().toISOString(),
    });
  }
  return out;
}

/** Mock 数据仓储：无账号时返回示例用量，便于调试 UI 与图表。 */
export class MockRepository implements UsageStore {
  private records: UsageRecord[] = seedRecords();
  private token: string = Constants.USE_MOCK_DATA ? 'auth=mock' : '';
  private syncState: SyncState = {
    lastSyncAt: new Date().toISOString(), lastSyncStatus: 'ok', lastSyncError: '',
    lastInsertedCount: 0, deepestPageFetched: 0, totalRecords: 800,
    oldestRecordAt: this.records[this.records.length - 1].createdAt,
    newestRecordAt: this.records[0].createdAt,
  };

  async getToken(): Promise<string> { return this.token; }
  async getWorkspaceHint(): Promise<string> { return 'wrk_mock'; }
  async saveResolvedWorkspace(workspaceId: string): Promise<void> {}
  async saveToken(token: string, workspaceId: string): Promise<void> {}
  async clearAccount(): Promise<void> {
    this.token = '';
    this.syncState = {
      lastSyncAt: '', lastSyncStatus: 'ok', lastSyncError: '',
      lastInsertedCount: 0, deepestPageFetched: -1, totalRecords: 0,
      oldestRecordAt: '', newestRecordAt: '',
    };
  }
  async insertUsageRecords(records: UsageRecord[]): Promise<number> {
    let n = 0;
    const known = new Set(this.records.map((r) => r.usgId));
    for (const r of records) {
      if (!known.has(r.usgId)) {
        this.records.push(r);
        n++;
      }
    }
    this.syncState.totalRecords = this.records.length;
    return n;
  }
  async pruneOldRecords(windowDays: number): Promise<number> {
    const cutoff = Date.now() - windowDays * 86400 * 1000;
    const before = this.records.length;
    this.records = this.records.filter((r) => Date.parse(r.createdAt) >= cutoff);
    this.syncState.totalRecords = this.records.length;
    return before - this.records.length;
  }
  async getWindowDays(): Promise<number | null> { return 60; }
  async updateSyncState(status: string, error: string, inserted: number): Promise<void> {
    this.syncState.lastSyncStatus = status;
    this.syncState.lastSyncError = error;
    this.syncState.lastInsertedCount += inserted;
  }
  async getSyncState(): Promise<SyncState> { return this.syncState; }

  // 聚合查询（Mock：委托到内存计算）
  async totals(period: string): Promise<Totals> { return this.calcTotals(period); }
  async modelStats(period: string): Promise<ModelStat[]> { return this.calcModels(period); }
  async dailyStats(days: number): Promise<DailyStat[]> { return this.calcDaily(days); }
  async todayTrend(): Promise<TrendPoint[]> { return this.calcTrend(); }
  async sessionStatsPage(page: number, pageSize: number, days: number | null): Promise<[SessionStat[], number]> {
    const dayMs = days !== null && days > 0 ? days * 86400 * 1000 : Number.MAX_SAFE_INTEGER;
    const map = new Map<string, SessionStat>();
    for (const r of this.records) {
      if (Date.now() - Date.parse(r.createdAt) > dayMs) { continue; }
      let s = map.get(r.sessionId);
      if (s === undefined) {
        s = { sessionId: r.sessionId, requestCount: 0, totalInputTokens: 0, uncachedInputTokens: 0, totalOutputTokens: 0, totalReasoningTokens: 0, totalCostUsd: 0, lastAt: r.createdAt };
        map.set(r.sessionId, s);
      }
      s.requestCount++;
      s.totalInputTokens += r.inputTokens + r.cacheReadTokens + r.cacheWrite5mTokens + r.cacheWrite1hTokens;
      s.uncachedInputTokens += r.inputTokens;
      s.totalOutputTokens += r.outputTokens;
      s.totalReasoningTokens += r.reasoningTokens;
      s.totalCostUsd += r.costUsd;
      if (r.createdAt > s.lastAt) { s.lastAt = r.createdAt; }
    }
    const all = Array.from(map.values());
    all.sort((a, b) => b.lastAt.localeCompare(a.lastAt));
    const total = all.length;
    const start = (page - 1) * pageSize;
    const rows = all.slice(start, start + pageSize).map((s): SessionStat => ({
      sessionId: s.sessionId, requestCount: s.requestCount, totalInputTokens: s.totalInputTokens,
      uncachedInputTokens: s.uncachedInputTokens, totalOutputTokens: s.totalOutputTokens,
      totalReasoningTokens: s.totalReasoningTokens, totalCostUsd: Number(s.totalCostUsd.toFixed(6)), lastAt: s.lastAt,
    }));
    return [rows, total];
  }

  async usageRecordsPage(page: number, pageSize: number, model: string | null, days: number | null): Promise<[RecordRow[], number]> {
    const dayMs = days !== null && days > 0 ? days * 86400 * 1000 : Number.MAX_SAFE_INTEGER;
    let list = this.records.filter((r) => model === null || model === '' || r.model === model);
    list = list.filter((r) => Date.now() - Date.parse(r.createdAt) <= dayMs);
    list = list.slice().sort((a, b) => b.createdAt.localeCompare(a.createdAt));
    const total = list.length;
    const start = (page - 1) * pageSize;
    const rows = list.slice(start, start + pageSize).map((r): RecordRow => ({
      usgId: r.usgId, createdAt: r.createdAt, model: r.model, provider: r.provider,
      inputTokens: r.inputTokens, outputTokens: r.outputTokens, reasoningTokens: r.reasoningTokens,
      cacheReadTokens: r.cacheReadTokens, cacheWriteTokens: r.cacheWrite5mTokens + r.cacheWrite1hTokens,
      costUsd: r.costUsd, sessionId: r.sessionId, plan: r.plan,
    }));
    return [rows, total];
  }

  async listModels(): Promise<string[]> { return Array.from(new Set(this.records.map((r) => r.model))).sort(); }

  private inPeriod(r: UsageRecord, period: string): boolean {
    const ms = Date.parse(r.createdAt);
    const now = Date.now();
    if (period === Constants.PERIOD_TODAY) {
      const d = new Date();
      return new Date(ms).getDate() === d.getDate() && new Date(ms).getMonth() === d.getMonth();
    }
    if (period === Constants.PERIOD_ALL) {
      return true;
    }
    const m = /^(\d+)d$/.exec(period);
    const days = m !== null ? Number(m[1]) : 30;
    return now - ms <= days * 86400 * 1000;
  }

  private calcTotals(period: string): Totals {
    const inP = this.inPeriod;
    const recs = this.records.filter((r) => inP(r, period));
    let requestCount = 0;
    const sessions = new Set<string>();
    let totalInput = 0, uncachedInput = 0, reasoning = 0, hit = 0, write = 0, output = 0, cost = 0;
    for (const r of recs) {
      requestCount++;
      if (r.sessionId !== '') { sessions.add(r.sessionId); }
      totalInput += r.inputTokens + r.cacheReadTokens + r.cacheWrite5mTokens + r.cacheWrite1hTokens;
      uncachedInput += r.inputTokens;
      reasoning += r.reasoningTokens;
      hit += r.cacheReadTokens;
      write += r.cacheWrite5mTokens + r.cacheWrite1hTokens;
      output += r.outputTokens;
      cost += r.costUsd;
    }
    const hitRate = hit + uncachedInput > 0 ? Number((hit / (hit + uncachedInput) * 100).toFixed(2)) : 0;
    return {
      requestCount, sessionCount: sessions.size, totalInputTokens: totalInput,
      uncachedInputTokens: uncachedInput, totalReasoningTokens: reasoning,
      cacheHitTokens: hit, cacheWriteTokens: write, totalOutputTokens: output,
      totalCostUsd: Number(cost.toFixed(6)), hitRate,
    };
  }

  private calcModels(period: string): ModelStat[] {
    const inP = this.inPeriod;
    const map = new Map<string, ModelStat>();
    for (const r of this.records) {
      if (!inP(r, period)) { continue; }
      let stat = map.get(r.model);
      if (stat === undefined) {
        stat = { model: r.model, requestCount: 0, sessionCount: 0, totalInputTokens: 0, uncachedInputTokens: 0, totalReasoningTokens: 0, cacheHitTokens: 0, cacheWriteTokens: 0, totalOutputTokens: 0, totalCostUsd: 0, hitRate: 0 };
        map.set(r.model, stat);
      }
      stat.requestCount++;
      if (r.sessionId !== '') { /* 近似：sessionCount 不单独累加 */ }
      stat.totalInputTokens += r.inputTokens + r.cacheReadTokens + r.cacheWrite5mTokens + r.cacheWrite1hTokens;
      stat.uncachedInputTokens += r.inputTokens;
      stat.totalReasoningTokens += r.reasoningTokens;
      stat.cacheHitTokens += r.cacheReadTokens;
      stat.cacheWriteTokens += r.cacheWrite5mTokens + r.cacheWrite1hTokens;
      stat.totalOutputTokens += r.outputTokens;
      stat.totalCostUsd += r.costUsd;
    }
    const out = Array.from(map.values());
    out.sort((a, b) => (b.totalInputTokens + b.totalOutputTokens) - (a.totalInputTokens + a.totalOutputTokens));
    for (const s of out) {
      s.hitRate = s.cacheHitTokens + s.uncachedInputTokens > 0
        ? Number((s.cacheHitTokens / (s.cacheHitTokens + s.uncachedInputTokens) * 100).toFixed(2)) : 0;
      s.totalCostUsd = Number(s.totalCostUsd.toFixed(6));
    }
    return out;
  }

  private calcDaily(days: number): DailyStat[] {
    const now = Date.now();
    const cutoff = now - days * 86400 * 1000;
    const map = new Map<string, DailyStat>();
    for (const r of this.records) {
      const ms = Date.parse(r.createdAt);
      if (ms < cutoff) { continue; }
      const d = new Date(ms);
      const p = (v: number): string => (v < 10 ? `0${v}` : `${v}`);
      const key = `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}`;
      let stat = map.get(key);
      if (stat === undefined) {
        stat = { date: key, totalInputTokens: 0, uncachedInputTokens: 0, totalReasoningTokens: 0, cacheHitTokens: 0, cacheWriteTokens: 0, totalOutputTokens: 0, totalCostUsd: 0, requestCount: 0, hitRate: 0 };
        map.set(key, stat);
      }
      stat.totalInputTokens += r.inputTokens + r.cacheReadTokens + r.cacheWrite5mTokens + r.cacheWrite1hTokens;
      stat.uncachedInputTokens += r.inputTokens;
      stat.totalReasoningTokens += r.reasoningTokens;
      stat.cacheHitTokens += r.cacheReadTokens;
      stat.cacheWriteTokens += r.cacheWrite5mTokens + r.cacheWrite1hTokens;
      stat.totalOutputTokens += r.outputTokens;
      stat.totalCostUsd += r.costUsd;
      stat.requestCount++;
    }
    const out = Array.from(map.values());
    out.sort((a, b) => a.date.localeCompare(b.date));
    for (const s of out) {
      s.hitRate = s.cacheHitTokens + s.uncachedInputTokens > 0
        ? Number((s.cacheHitTokens / (s.cacheHitTokens + s.uncachedInputTokens) * 100).toFixed(2)) : 0;
      s.totalCostUsd = Number(s.totalCostUsd.toFixed(6));
    }
    return out;
  }

  private calcTrend(): TrendPoint[] {
    const d = new Date();
    const map = new Map<number, HourBucket>();
    for (const r of this.records) {
      const ms = Date.parse(r.createdAt);
      const rd = new Date(ms);
      if (rd.getDate() !== d.getDate() || rd.getMonth() !== d.getMonth()) { continue; }
      const h = rd.getHours();
      const item = map.get(h);
      if (item !== undefined) {
        item.input += r.inputTokens;
        item.output += r.outputTokens;
        item.reasoning += r.reasoningTokens;
      } else {
        map.set(h, { input: r.inputTokens, output: r.outputTokens, reasoning: r.reasoningTokens });
      }
    }
    const out: TrendPoint[] = [];
    for (let h = 0; h < 24; h++) {
      const item = map.get(h);
      const p = (v: number): string => (v < 10 ? `0${v}` : `${v}`);
      out.push({ hour: `${p(h)}:00`, input: item !== undefined ? item.input : 0, output: item !== undefined ? item.output : 0, reasoning: item !== undefined ? item.reasoning : 0 });
    }
    return out;
  }
}

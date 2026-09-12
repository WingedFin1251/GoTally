// entry/src/main/ets/model/Stats.ets
/** 聚合统计结果（对齐 db.py 各查询返回值）。 */

export interface Totals {
  requestCount: number;
  sessionCount: number;
  totalInputTokens: number;
  uncachedInputTokens: number;
  totalReasoningTokens: number;
  cacheHitTokens: number;
  cacheWriteTokens: number;
  totalOutputTokens: number;
  totalCostUsd: number;
  hitRate: number; // 0-100
}

export interface ModelStat {
  model: string;
  requestCount: number;
  sessionCount: number;
  totalInputTokens: number;
  uncachedInputTokens: number;
  totalReasoningTokens: number;
  cacheHitTokens: number;
  cacheWriteTokens: number;
  totalOutputTokens: number;
  totalCostUsd: number;
  hitRate: number;
}

export interface DailyStat {
  date: string;             // 'YYYY-MM-DD'（本地）
  totalInputTokens: number;
  uncachedInputTokens: number;
  totalReasoningTokens: number;
  cacheHitTokens: number;
  cacheWriteTokens: number;
  totalOutputTokens: number;
  totalCostUsd: number;
  requestCount: number;
  hitRate: number;
}

export interface TrendPoint {
  hour: string;   // 'HH:00'
  input: number;
  output: number;
  reasoning: number;
}

export interface SessionStat {
  sessionId: string;
  /** 归属 Key（无会话记录的按 Key 拆分行的 key_id）。 */
  keyId: string;
  /** Key 显示名称（来自 key_names 缓存，取不到时为空串）。 */
  keyName: string;
  requestCount: number;
  totalInputTokens: number;
  uncachedInputTokens: number;
  totalOutputTokens: number;
  totalReasoningTokens: number;
  totalCostUsd: number;
  lastAt: string;
}

export interface RecordRow {
  usgId: string;
  createdAt: string;
  model: string;
  provider: string;
  inputTokens: number;
  outputTokens: number;
  reasoningTokens: number;
  cacheReadTokens: number;
  cacheWriteTokens: number;
  costUsd: number;
  sessionId: string;
  /** 归属 Key 与其显示名称（名称来自 key_names 缓存）。 */
  keyId: string;
  keyName: string;
  plan: string;
}

/** Key 名称缓存条目（key_id → 显示名称）。 */
export interface KeyNamePair {
  keyId: string;
  name: string;
}

/** 聚合查询的最小接口（UsageRepository 与 MockRepository 均实现）。 */
export interface UsageAggregator {
  totals(period: string): Promise<Totals>;
  modelStats(period: string): Promise<ModelStat[]>;
  todayTrend(): Promise<TrendPoint[]>;
  dailyStats(days: number): Promise<DailyStat[]>;
  sessionStatsPage(page: number, pageSize: number, period: string): Promise<[SessionStat[], number]>;
  usageRecordsPage(page: number, pageSize: number, model: string | null, period: string): Promise<[RecordRow[], number]>;
  listModels(): Promise<string[]>;
}

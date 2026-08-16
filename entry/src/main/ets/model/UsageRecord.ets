// entry/src/main/ets/model/UsageRecord.ets
/** 一条请求级用量记录（对齐 db.py UsageRecord）。 */
export interface UsageRecord {
  usgId: string;
  createdAt: string;        // ISO 8601 UTC
  model: string;
  provider: string;
  inputTokens: number;
  outputTokens: number;
  reasoningTokens: number;
  cacheReadTokens: number;
  cacheWrite5mTokens: number;
  cacheWrite1hTokens: number;
  costRaw: number;          // 单位 1e-8 USD
  costUsd: number;
  keyId: string;
  sessionId: string;
  plan: string;
  syncedAt: string;
}

/** 配额窗口（对齐 db.py QuotaWindow）。 */
export interface QuotaWindow {
  label: string;
  used: number;      // 0-100
  remaining: number;
  total: number;
  unit: string;
  resetAt: string;   // ISO
  resetInSec: number;
}

export interface QuotaResult {
  name: string;
  workspaceId: string;
  success: boolean;
  updatedAt: string;
  windows: QuotaWindow[];
  error: string;
}

export interface SyncState {
  lastSyncAt: string;
  lastSyncStatus: string;
  lastSyncError: string;
  lastInsertedCount: number;
  deepestPageFetched: number;
  totalRecords: number;
  oldestRecordAt: string;
  newestRecordAt: string;
}

export interface WorkspaceRef {
  id: string;
  name: string;
}

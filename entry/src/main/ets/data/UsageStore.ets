// entry/src/main/ets/data/UsageStore.ets（最终版本：全部异步）
import type { UsageRecord, SyncState } from '../model/UsageRecord';

/** SyncManager 依赖的最小数据访问面（本地单测注入内存实现）。 */
export interface UsageStore {
  getToken(): Promise<string>;
  getWorkspaceHint(): Promise<string>;
  saveResolvedWorkspace(workspaceId: string): Promise<void>;
  saveToken(token: string, workspaceId: string): Promise<void>;
  clearAccount(): Promise<void>;
  insertUsageRecords(records: UsageRecord[]): Promise<number>;
  pruneOldRecords(windowDays: number): Promise<number>;
  getWindowDays(): Promise<number | null>;
  updateSyncState(status: string, error: string, inserted: number): Promise<void>;
  getSyncState(): Promise<SyncState>;
}

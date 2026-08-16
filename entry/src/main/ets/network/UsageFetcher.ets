// entry/src/main/ets/network/UsageFetcher.ets
import type { UsageRecord } from '../model/UsageRecord';

/** 用量页拉取抽象：SyncManager 通过它取数，便于单测注入。 */
export interface UsageFetcher {
  fetchUsagePage(workspaceId: string, page: number, keyId?: string): Promise<UsageRecord[]>;
}

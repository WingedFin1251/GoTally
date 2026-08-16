// entry/src/test/SyncManager.test.ets
import { describe, it, expect } from '@ohos/hypium';
import { SyncManager } from '../main/ets/network/SyncManager';
import type { UsageFetcher } from '../main/ets/network/UsageFetcher';
import type { UsageStore } from '../main/ets/data/UsageStore';
import type { UsageRecord, SyncState } from '../main/ets/model/UsageRecord';

const mkRec = (i: number): UsageRecord => ({
  usgId: `usg_${i}`, createdAt: `2026-08-1${i % 10}T00:00:00Z`, model: 'gpt-4o',
  provider: 'openai', inputTokens: 100, outputTokens: 50, reasoningTokens: 0,
  cacheReadTokens: 0, cacheWrite5mTokens: 0, cacheWrite1hTokens: 0,
  costRaw: 0, costUsd: 0, keyId: 'k', sessionId: 's', plan: '', syncedAt: '',
});

class FakeStore implements UsageStore {
  records: UsageRecord[] = [];
  token = 'auth=test';
  windowDays: number | null = 30;
  syncState: SyncState = {
    lastSyncAt: '', lastSyncStatus: '', lastSyncError: '', lastInsertedCount: 0,
    deepestPageFetched: -1, totalRecords: 0, oldestRecordAt: '', newestRecordAt: '',
  };
  async getToken(): Promise<string> { return this.token; }
  async getWorkspaceHint(): Promise<string> { return 'wrk_test'; }
  async saveResolvedWorkspace(id: string): Promise<void> {}
  async saveToken(token: string, ws: string): Promise<void> {}
  async insertUsageRecords(records: UsageRecord[]): Promise<number> {
    let n = 0;
    for (const r of records) {
      if (!this.records.some((x) => x.usgId === r.usgId)) {
        this.records.push(r);
        n++;
      }
    }
    return n;
  }
  async pruneOldRecords(windowDays: number): Promise<number> { return 0; }
  async getWindowDays(): Promise<number | null> { return this.windowDays; }
  async updateSyncState(status: string, error: string, inserted: number): Promise<void> {
    this.syncState.lastSyncStatus = status;
    this.syncState.lastSyncError = error;
  }
  async getSyncState(): Promise<SyncState> { return this.syncState; }
  async clearAccount(): Promise<void> { this.records = []; }
}

/** ArkTS 不允许用对象字面量初始化带方法的接口，改用类实现。 */
class FakeFetcher implements UsageFetcher {
  onFetch: (workspaceId: string, page: number) => Promise<UsageRecord[]> =
    async (): Promise<UsageRecord[]> => [];
  async fetchUsagePage(workspaceId: string, page: number, keyId?: string): Promise<UsageRecord[]> {
    return this.onFetch(workspaceId, page);
  }
}

export default function syncManagerTest() {
  describe('SyncManagerTest', () => {
    it('incremental_inserts_new', 0, async () => {
      const store = new FakeStore();
      const fetcher = new FakeFetcher();
      fetcher.onFetch = async (ws: string, page: number): Promise<UsageRecord[]> => {
        if (page === 0) { return [mkRec(1), mkRec(2)]; }
        return [];
      };
      const mgr = new SyncManager(store, fetcher);
      const result = await mgr.sync('incremental');
      expect(result.ok).assertTrue();
      expect(result.inserted).assertEqual(2);
      expect(store.records.length).assertEqual(2);
    });
    it('no_token_fails', 0, async () => {
      const store = new FakeStore();
      store.token = '';
      const mgr = new SyncManager(store, new FakeFetcher());
      const result = await mgr.sync('incremental');
      expect(result.ok).assertFalse();
      expect(result.error).assertEqual('未登录');
    });
    it('dedupe_on_retry', 0, async () => {
      const store = new FakeStore();
      const fetcher = new FakeFetcher();
      fetcher.onFetch = async (ws: string, page: number): Promise<UsageRecord[]> =>
        page === 0 ? [mkRec(1)] : [];
      const mgr = new SyncManager(store, fetcher);
      await mgr.sync('incremental');
      const second = await mgr.sync('incremental');
      expect(second.inserted).assertEqual(0);
      expect(store.records.length).assertEqual(1);
    });
  });
}

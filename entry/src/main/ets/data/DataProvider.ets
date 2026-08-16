// entry/src/main/ets/data/DataProvider.ets
import { Constants } from '../common/constants/Constants';
import type { UsageDataStore } from './UsageStore';
import { UsageRepository } from './UsageRepository';
import { MockRepository } from './MockRepository';
import type { UsageFetcher } from '../network/UsageFetcher';
import { OpenCodeApi } from '../network/OpenCodeApi';
import type { UsageRecord } from '../model/UsageRecord';
import type { UsageAggregator } from '../model/Stats';
import { SyncManager } from '../network/SyncManager';
import { SettingsStore } from './SettingsStore';

class RealFetcher implements UsageFetcher {
  async fetchUsagePage(ws: string, page: number, keyId?: string): Promise<UsageRecord[]> {
    const token = await DataProvider.getStore().getToken();
    return OpenCodeApi.fetchUsagePage(token, ws, page, keyId ?? '');
  }
}

const realFetcher: UsageFetcher = new RealFetcher();

/** 统一入口：按 Constants.USE_MOCK_DATA 返回真实或 Mock 实现。 */
export class DataProvider {
  private static store: UsageDataStore | null = null;
  private static fetcher: UsageFetcher | null = null;
  private static sync: SyncManager | null = null;

  static getStore(): UsageDataStore {
    if (DataProvider.store === null) {
      DataProvider.store = Constants.USE_MOCK_DATA ? new MockRepository() : new UsageRepository();
    }
    return DataProvider.store;
  }

  static getAggregator(): UsageAggregator {
    return DataProvider.getStore();
  }

  static getFetcher(): UsageFetcher {
    if (DataProvider.fetcher === null) {
      DataProvider.fetcher = realFetcher;
    }
    return DataProvider.fetcher;
  }

  static getSyncManager(): SyncManager {
    if (DataProvider.sync === null) {
      DataProvider.sync = new SyncManager(
        DataProvider.getStore(),
        DataProvider.getFetcher(),
        async (): Promise<number> => SettingsStore.getSyncIntervalSec(),
        (hint: string, token: string): Promise<string> => OpenCodeApi.resolveWorkspaceId(hint, token));
    }
    return DataProvider.sync;
  }
}

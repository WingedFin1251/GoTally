// entry/src/main/ets/data/DataProvider.ets
import { Constants } from '../common/constants/Constants';
import type { UsageDataStore } from './UsageStore';
import { UsageRepository } from './UsageRepository';
import { MockRepository } from './MockRepository';
import type { UsageFetcher } from '../network/UsageFetcher';
import { OpenCodeApi } from '../network/OpenCodeApi';
import type { UsageRecord } from '../model/UsageRecord';
import type { KeyNamePair } from '../model/Stats';
import type { UsageAggregator } from '../model/Stats';
import { SyncManager } from '../network/SyncManager';
import { SettingsStore } from './SettingsStore';
import { ConsoleAggregator } from './ConsoleAggregator';

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
  private static agg: UsageAggregator | null = null;

  static getStore(): UsageDataStore {
    if (DataProvider.store === null) {
      DataProvider.store = Constants.USE_MOCK_DATA ? new MockRepository() : new UsageRepository();
    }
    return DataProvider.store;
  }

  static getAggregator(): UsageAggregator {
    if (DataProvider.agg === null) {
      const store = DataProvider.getStore();
      // 非 Mock 模式：包一层控制台聚合回退（本地无记录时用官方 /console/api/usage/* 聚合数据）
      DataProvider.agg = Constants.USE_MOCK_DATA
        ? store
        : new ConsoleAggregator(
          store,
          async (): Promise<string> => DataProvider.getStore().getToken(),
          async (): Promise<string> => DataProvider.getStore().getWorkspaceHint());
    }
    return DataProvider.agg;
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
        (hint: string, token: string): Promise<string> => OpenCodeApi.resolveWorkspaceId(hint, token),
        (workspaceId: string, token: string): Promise<KeyNamePair[]> => OpenCodeApi.fetchKeyNames(token, workspaceId));
    }
    return DataProvider.sync;
  }
}

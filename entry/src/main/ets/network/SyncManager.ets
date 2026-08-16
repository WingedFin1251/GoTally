// entry/src/main/ets/network/SyncManager.ets
import { Constants } from '../common/constants/Constants';
import type { UsageStore } from '../data/UsageStore';
import type { UsageFetcher } from './UsageFetcher';
import type { UsageRecord } from '../model/UsageRecord';

export interface SyncProgress {
  running: boolean;
  mode: string;
  page: number;
  inserted: number;
  phase: string; // idle | usage | done | error
  message: string;
}

const IDLE_PROGRESS: SyncProgress = { running: false, mode: '', page: 0, inserted: 0, phase: 'idle', message: '' };

/** 同步状态机：增量/全量拉取、去重写入、窗口裁剪、进度回调。 */
export class SyncManager {
  private store: UsageStore;
  private fetcher: UsageFetcher;
  private progress: SyncProgress = { ...IDLE_PROGRESS };
  private busy = false;
  private timer: number | null = null;
  private intervalProvider: () => Promise<number>;
  onProgress: (p: SyncProgress) => void = () => {};

  constructor(store: UsageStore, fetcher: UsageFetcher, intervalProvider?: () => Promise<number>) {
    this.store = store;
    this.fetcher = fetcher;
    this.intervalProvider = intervalProvider !== undefined ? intervalProvider : async (): Promise<number> => 300;
  }

  getProgress(): SyncProgress {
    return { ...this.progress };
  }

  private setPhase(phase: string, message: string): void {
    this.progress.phase = phase;
    this.progress.message = message;
    this.progress.running = phase === 'usage';
    this.onProgress(this.getProgress());
  }

  async sync(mode: 'incremental' | 'full'): Promise<{ ok: boolean; error?: string; inserted?: number }> {
    const token = await this.store.getToken();
    if (token.trim() === '') {
      return { ok: false, error: '未登录' };
    }
    if (this.busy) {
      return { ok: false, error: '已有同步任务进行中' };
    }
    this.busy = true;
    this.progress.mode = mode;
    this.progress.page = 0;
    this.progress.inserted = 0;
    this.setPhase('usage', '');

    try {
      const workspaceId = await this.store.getWorkspaceHint();
      const windowDays = await this.store.getWindowDays();
      const maxPages = mode === 'full' ? Constants.MAX_FULL_PAGES : Constants.INCREMENTAL_PAGES;
      let totalInserted = 0;
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
            this.busy = false;
            return { ok: false, error: msg, inserted: totalInserted };
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

      await this.store.updateSyncState('ok', '', totalInserted);
      this.setPhase('done', `同步完成, 新增 ${totalInserted} 条`);
      this.busy = false;
      return { ok: true, inserted: totalInserted };
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      await this.store.updateSyncState('error', msg, this.progress.inserted);
      this.setPhase('error', msg);
      this.busy = false;
      return { ok: false, error: msg };
    }
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
    this.timer = setInterval(() => {
      if (this.busy) {
        return;
      }
      this.sync('incremental');
    }, intervalSec * 1000) as unknown as number;
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

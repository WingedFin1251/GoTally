// entry/src/main/ets/pages/RecordsViewModel.ets
import { DataProvider } from '../data/DataProvider';
import type { SessionStat, RecordRow } from '../model/Stats';

const SESSION_PAGE_SIZE = 10;
const RECORD_PAGE_SIZE = 50;

/** 记录页：会话聚合 + 请求明细，各自分页。 */
export class RecordsViewModel {
  sessions: SessionStat[] = [];
  sessionTotal = 0;
  sessionPage = 1;

  records: RecordRow[] = [];
  recordTotal = 0;
  recordPage = 1;

  models: string[] = [];
  selectedModel = '';

  async loadSessions(page: number): Promise<void> {
    this.sessionPage = Math.max(1, page);
    const agg = DataProvider.getAggregator();
    const [rows, total] = await agg.sessionStatsPage(this.sessionPage, SESSION_PAGE_SIZE, null);
    this.sessions = rows;
    this.sessionTotal = total;
  }

  async loadRecords(page: number): Promise<void> {
    this.recordPage = Math.max(1, page);
    const agg = DataProvider.getAggregator();
    const [rows, total] = await agg.usageRecordsPage(this.recordPage, RECORD_PAGE_SIZE, this.selectedModel === '' ? null : this.selectedModel, null);
    this.records = rows;
    this.recordTotal = total;
    const models = await agg.listModels();
    this.models = models;
  }

  async setModel(m: string): Promise<void> {
    this.selectedModel = m;
    await this.loadRecords(1);
  }
}

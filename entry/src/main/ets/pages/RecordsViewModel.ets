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
  period: string = 'today';

  setPeriod(p: string): void {
    this.period = p;
  }

  async loadSessions(page: number): Promise<void> {
    this.sessionPage = Math.max(1, page);
    const agg = DataProvider.getAggregator();
    const result = await agg.sessionStatsPage(this.sessionPage, SESSION_PAGE_SIZE, this.period);
    this.sessions = result[0];
    this.sessionTotal = result[1];
    const totalPages = Math.ceil(this.sessionTotal / SESSION_PAGE_SIZE);
    this.sessionPage = Math.min(this.sessionPage, Math.max(1, totalPages));
  }

  async loadRecords(page: number): Promise<void> {
    this.recordPage = Math.max(1, page);
    const agg = DataProvider.getAggregator();
    const result = await agg.usageRecordsPage(this.recordPage, RECORD_PAGE_SIZE, this.selectedModel === '' ? null : this.selectedModel, this.period);
    this.records = result[0];
    this.recordTotal = result[1];
    const totalPages = Math.ceil(this.recordTotal / RECORD_PAGE_SIZE);
    this.recordPage = Math.min(this.recordPage, Math.max(1, totalPages));
    const models = await agg.listModels();
    this.models = models;
  }

  async setModel(m: string): Promise<void> {
    this.selectedModel = m;
    await this.loadRecords(1);
  }
}

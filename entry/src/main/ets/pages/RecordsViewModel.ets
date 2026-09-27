// entry/src/main/ets/pages/RecordsViewModel.ets
import { DataProvider } from '../data/DataProvider';
import type { SessionStat, RecordRow, ModelStat } from '../model/Stats';

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
  /** 模型维度聚合（控制台登录下的主数据：官方无逐条明细，但按模型有聚合）。 */
  modelStats: ModelStat[] = [];

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

  /**
   * 模型维度数据：控制台登录下官方没有逐条明细，但提供按模型的聚合
   * （来源：本地历史「天×模型」明细 / 官方 `/usage/models`，见 ConsoleAggregator）。
   */
  async loadModelStats(): Promise<void> {
    const agg = DataProvider.getAggregator();
    this.modelStats = await agg.modelStats(this.period);
    // 模型筛选以聚合结果为准（本地明细为空时也能列出真实模型）
    if (this.modelStats.length > 0) {
      const names: string[] = [];
      for (const m of this.modelStats) {
        names.push(m.model);
      }
      this.models = names;
    }
  }
}

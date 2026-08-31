// entry/src/main/ets/pages/StatsViewModel.ets
import { DataProvider } from '../data/DataProvider';
import type { Totals, ModelStat, DailyStat } from '../model/Stats';

/** 统计页数据：KPI、模型排行、30 天趋势。 */
export class StatsViewModel {
  period: string = '7d';
  totals: Totals = { requestCount: 0, sessionCount: 0, totalInputTokens: 0, uncachedInputTokens: 0, totalReasoningTokens: 0, cacheHitTokens: 0, cacheWriteTokens: 0, totalOutputTokens: 0, totalCostUsd: 0, hitRate: 0 };
  models: ModelStat[] = [];
  daily30: DailyStat[] = [];
  dim: 'input' | 'output' | 'cost' = 'input';
  loading: boolean = false;

  setPeriod(p: string): void {
    this.period = p;
  }

  setDim(d: 'input' | 'output' | 'cost'): void {
    this.dim = d;
  }

  async load(): Promise<void> {
    this.loading = true;
    const agg = DataProvider.getAggregator();
    // 各项独立 try/catch：单项失败保留旧值并记日志，不让一次失败中断整页刷新
    // （否则饼图/趋势图会停留在上一次 period 的数据，造成「今天」显示亿级旧数据）。
    try {
      this.totals = await agg.totals(this.period);
    } catch (e) {
      console.error('load totals failed: ' + (e instanceof Error ? e.message : String(e)));
    }
    try {
      this.models = await agg.modelStats(this.period);
    } catch (e) {
      console.error('load modelStats failed: ' + (e instanceof Error ? e.message : String(e)));
    }
    try {
      this.daily30 = await agg.dailyStats(30);
    } catch (e) {
      console.error('load dailyStats failed: ' + (e instanceof Error ? e.message : String(e)));
    }
    this.loading = false;
  }
}

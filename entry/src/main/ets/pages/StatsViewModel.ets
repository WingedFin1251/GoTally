// entry/src/main/ets/pages/StatsViewModel.ets
import { DataProvider } from '../data/DataProvider';
import type { Totals, ModelStat, DailyStat, TrendPoint } from '../model/Stats';
import { Constants } from '../common/constants/Constants';

/** 统计页数据：KPI、模型排行、趋势（趋势跟随周期筛选）。 */
export class StatsViewModel {
  period: string = '7d';
  totals: Totals = { requestCount: 0, sessionCount: 0, totalInputTokens: 0, uncachedInputTokens: 0, totalReasoningTokens: 0, cacheHitTokens: 0, cacheWriteTokens: 0, totalOutputTokens: 0, totalCostUsd: 0, hitRate: 0 };
  models: ModelStat[] = [];
  /** 非 today 周期：最近 N 天逐日趋势。 */
  daily30: DailyStat[] = [];
  /** today 周期：24 小时逐时趋势。 */
  todayTrend: TrendPoint[] = [];
  dim: 'input' | 'output' | 'cost' = 'input';
  loading: boolean = false;

  setPeriod(p: string): void {
    this.period = p;
  }

  setDim(d: 'input' | 'output' | 'cost'): void {
    this.dim = d;
  }

  async load(period: string): Promise<void> {
    this.loading = true;
    this.period = period;
    const agg = DataProvider.getAggregator();
    // 各项独立 try/catch：单项失败保留旧值并记日志，不让一次失败中断整页刷新
    // （否则饼图/趋势图会停留在上一次 period 的数据，造成「今天」显示亿级旧数据）。
    try {
      this.totals = await agg.totals(period);
    } catch (e) {
      console.error('load totals failed: ' + (e instanceof Error ? e.message : String(e)));
    }
    try {
      this.models = await agg.modelStats(period);
    } catch (e) {
      console.error('load modelStats failed: ' + (e instanceof Error ? e.message : String(e)));
    }
    if (period === Constants.PERIOD_TODAY) {
      // 「今天」：24 小时逐时趋势
      this.daily30 = [];
      try {
        this.todayTrend = await agg.todayTrend();
      } catch (e) {
        console.error('load todayTrend failed: ' + (e instanceof Error ? e.message : String(e)));
      }
    } else {
      this.todayTrend = [];
      const days = period === '7d' ? 7 : (period === '30d' ? 30 : 90);
      try {
        this.daily30 = await agg.dailyStats(days);
      } catch (e) {
        console.error('load dailyStats failed: ' + (e instanceof Error ? e.message : String(e)));
      }
    }
    this.loading = false;
  }
}
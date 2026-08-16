// entry/src/main/ets/pages/DashboardViewModel.ets
import { DataProvider } from '../data/DataProvider';
import type { Totals, TrendPoint, DailyStat, UsageAggregator } from '../model/Stats';
import type { QuotaWindow } from '../model/UsageRecord';
import { Constants } from '../common/constants/Constants';
import { OpenCodeApi } from '../network/OpenCodeApi';

/** 首页数据加载与周期切换（无 UI 依赖，便于单测）。 */
export class DashboardViewModel {
  period: string = Constants.PERIOD_TODAY;
  totals: Totals = { requestCount: 0, sessionCount: 0, totalInputTokens: 0, uncachedInputTokens: 0, totalReasoningTokens: 0, cacheHitTokens: 0, cacheWriteTokens: 0, totalOutputTokens: 0, totalCostUsd: 0, hitRate: 0 };
  todayTotals: Totals = this.totals;
  trend: TrendPoint[] = [];
  daily: DailyStat[] = [];
  quota: QuotaWindow[] = [];
  loading: boolean = false;
  loaded: boolean = false;

  setPeriod(p: string): void {
    this.period = p;
  }

  async load(): Promise<void> {
    this.loading = true;
    const store = DataProvider.getAggregator();
    this.totals = await store.totals(this.period);
    this.todayTotals = await store.totals(Constants.PERIOD_TODAY);
    this.trend = await store.todayTrend();
    this.daily = await store.dailyStats(7);
    this.quota = await this.loadQuota();
    this.loading = false;
    this.loaded = true;
  }

  private async loadQuota(): Promise<QuotaWindow[]> {
    const token = await DataProvider.getStore().getToken();
    if (token.trim() === '' || Constants.USE_MOCK_DATA) {
      // Mock 或未登录：返回模拟配额窗口
      return [
        { label: '5h', used: 42.5, remaining: 57.5, total: 100, unit: '%', resetAt: '', resetInSec: 3720 },
        { label: 'weekly', used: 60.2, remaining: 39.8, total: 100, unit: '%', resetAt: '', resetInSec: 86400 },
        { label: 'monthly', used: 7.8, remaining: 92.2, total: 100, unit: '%', resetAt: '', resetInSec: 2592000 },
      ];
    }
    const hint = await DataProvider.getStore().getWorkspaceHint();
    const result = await OpenCodeApi.fetchQuota(token, hint);
    return result.success ? result.windows : [];
  }
}

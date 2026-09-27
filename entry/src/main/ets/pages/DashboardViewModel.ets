// entry/src/main/ets/pages/DashboardViewModel.ets
import { DataProvider } from '../data/DataProvider';
import type { Totals, TrendPoint, DailyStat, UsageAggregator } from '../model/Stats';
import type { QuotaWindow } from '../model/UsageRecord';
import { Constants } from '../common/constants/Constants';
import { OpenCodeApi } from '../network/OpenCodeApi';
import { SettingsStore } from '../data/SettingsStore';

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
  /** 配额数据来源：official / console / html（界面提示与排查用）。 */
  quotaSource: string = '';

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
    // 可选 API Key：填写后配额优先走官方 /zen/go/v1/usage，其次控制台 JSON，最后页面解析
    const apiKey = await SettingsStore.getGoApiKey();
    // 免登录模式（无 token 但有 API Key）也走真实配额，不能回退成示例数据
    if (Constants.USE_MOCK_DATA || (token.trim() === '' && apiKey.trim() === '')) {
      this.quotaSource = 'mock';
      return [
        { label: '5h', used: 42.5, remaining: 57.5, total: 100, unit: '%', resetAt: '', resetInSec: 3720 },
        { label: 'weekly', used: 60.2, remaining: 39.8, total: 100, unit: '%', resetAt: '', resetInSec: 86400 },
        { label: 'monthly', used: 7.8, remaining: 92.2, total: 100, unit: '%', resetAt: '', resetInSec: 2592000 },
      ];
    }
    const hint = await DataProvider.getStore().getWorkspaceHint();
    const result = await OpenCodeApi.fetchQuota(token, hint, apiKey);
    this.quotaSource = result.success ? (result.source !== undefined ? result.source : '') : '';
    return result.success ? result.windows : [];
  }
}

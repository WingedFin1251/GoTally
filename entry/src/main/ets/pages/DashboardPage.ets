// entry/src/main/ets/pages/DashboardPage.ets
import { DashboardViewModel } from './DashboardViewModel';
import { StatCard } from '../components/ui/StatCard';
import { QuotaProgress } from '../components/ui/QuotaProgress';
import { BarChart } from '../components/charts/BarChart';
import { formatTokens, formatCost, formatPercent } from '../common/utils/Formatter';
import { formatDurationShort } from '../common/utils/TimeUtil';
import { Constants } from '../common/constants/Constants';
import { SettingsStore } from '../data/SettingsStore';
import { OpenCodeApi } from '../network/OpenCodeApi';
import type { TrendPoint } from '../model/Stats';
import type { QuotaWindow } from '../model/UsageRecord';

@Component
export struct DashboardPage {
  @State vm: DashboardViewModel = new DashboardViewModel();
  @State chartVersion: number = 0;
  @State currency: string = 'CNY';
  @State usdCny: number = Constants.DEFAULT_USD_CNY;

  aboutToAppear(): void {
    this.refresh();
    this.initCurrency();
  }

  private async refresh(): Promise<void> {
    await this.vm.load();
    this.chartVersion++;
  }

  private async initCurrency(): Promise<void> {
    this.currency = await SettingsStore.getCurrency();
    this.usdCny = await OpenCodeApi.fetchUsdCny();
  }

  @Builder
  RangePills() {
    Row({ space: 6 }) {
      this.Pill(Constants.PERIOD_TODAY, $r('app.string.today'))
      this.Pill('7d', $r('app.string.days_7'))
      this.Pill('30d', $r('app.string.days_30'))
      this.Pill(Constants.PERIOD_ALL, $r('app.string.all'))
    }
  }

  @Builder
  Pill(period: string, label: Resource) {
    Text(label)
      .fontSize(12)
      .padding({ left: 12, right: 12, top: 5, bottom: 5 })
      .borderRadius(14)
      .backgroundColor(this.vm.period === period ? $r('app.color.accent') : $r('app.color.divider'))
      .fontColor(this.vm.period === period ? Color.White : $r('app.color.text_secondary'))
      .onClick(() => {
        this.vm.setPeriod(period);
        this.refresh();
      })
  }

  @Builder
  QuotaRow() {
    Column({ space: 10 }) {
      Row() {
        Text($r('app.string.quota_title')).fontSize(15).fontWeight(FontWeight.Bold)
        Blank()
      }
      .width('100%')
      ForEach(this.vm.quota, (q: QuotaWindow) => {
        QuotaProgress({
          label: this.quotaLabel(q.label),
          percent: q.used,
          remainingText: `${q.remaining}%`,
          resetText: formatDurationShort(q.resetInSec),
        })
      }, (q: QuotaWindow) => q.label)
    }
    .width('100%')
  }

  private quotaLabel(label: string): string {
    if (label === '5h') { return '5小时'; }
    if (label === 'weekly') { return '每周'; }
    return '每月';
  }

  @Builder
  OverviewGrid() {
    Column({ space: 10 }) {
      Row() {
        Text($r('app.string.overview_title')).fontSize(15).fontWeight(FontWeight.Bold)
        Blank()
      }
      .width('100%')

      Column({ space: 10 }) {
        Row({ space: 10 }) {
          StatCard({ title: $r('app.string.ov_hit_rate'), value: formatPercent(this.vm.totals.hitRate), sub: '', accent: true }).layoutWeight(1)
          StatCard({ title: $r('app.string.ov_hits'), value: formatTokens(this.vm.totals.cacheHitTokens), sub: '', accent: false }).layoutWeight(1)
        }
        .width('100%')
        Row({ space: 10 }) {
          StatCard({ title: $r('app.string.ov_total_tokens'), value: formatTokens(this.vm.totals.totalInputTokens + this.vm.totals.totalOutputTokens + this.vm.totals.totalReasoningTokens), sub: '', accent: false }).layoutWeight(1)
          StatCard({ title: $r('app.string.ov_requests'), value: `${this.vm.totals.requestCount}`, sub: '', accent: false }).layoutWeight(1)
        }
        .width('100%')
        Row({ space: 10 }) {
          StatCard({ title: $r('app.string.ov_cost'), value: formatCost(this.vm.totals.totalCostUsd, this.currency, this.usdCny), sub: '', accent: false }).layoutWeight(1)
          StatCard({ title: $r('app.string.ov_sessions'), value: `${this.vm.totals.sessionCount}`, sub: '', accent: false }).layoutWeight(1)
        }
        .width('100%')
      }
      .width('100%')
    }
    .width('100%')
  }

  @Builder
  TodayTrendCard() {
    Column({ space: 8 }) {
      Row() {
        Text($r('app.string.today_trend')).fontSize(15).fontWeight(FontWeight.Bold)
        Text($r('app.string.hours_24')).fontSize(11).fontColor($r('app.color.text_muted'))
        Blank()
      }
      .width('100%')

      // 输入 + 输出分组柱状图（今日 24h）
      Row({ space: 2 }) {
        ForEach(this.vm.trend, (t: TrendPoint) => {
          Column() {
            BarChart({
              labels: [t.hour],
              values: [t.input],
              // Canvas fillStyle 需要真实色值字符串，用固定调色板（与 Task 9 图表一致，随主题不变）
              colors: ['#2F6FED'],
              version: this.chartVersion,
            })
              .height(180)
              .layoutWeight(1)
          }
        }, (t: TrendPoint) => t.hour)
      }
      .width('100%')
      .height(200)
    }
    .width('100%')
    .padding(12)
    .borderRadius(12)
    .backgroundColor($r('app.color.bg_card'))
  }

  build() {
    Scroll() {
      Column({ space: 12 }) {
        Row() {
          Text($r('app.string.home_title')).fontSize(18).fontWeight(FontWeight.Bold)
          Blank()
          this.RangePills()
        }
        .width('100%')

        this.QuotaRow()
        this.OverviewGrid()
        this.TodayTrendCard()
      }
      .padding(12)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.bg_page'))
    .scrollBar(BarState.Off)
  }
}

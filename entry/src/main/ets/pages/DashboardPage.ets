// entry/src/main/ets/pages/DashboardPage.ets
import { DashboardViewModel } from './DashboardViewModel';
import { StatCard } from '../components/ui/StatCard';
import { QuotaProgress } from '../components/ui/QuotaProgress';
import { BarChart } from '../components/charts/BarChart';
import { formatTokensUi, formatCost, formatPercent } from '../common/utils/Formatter';
import { formatReset } from '../common/utils/TimeUtil';
import { isZh } from '../common/utils/Locale';
import { Constants } from '../common/constants/Constants';
import { SettingsStore } from '../data/SettingsStore';
import { OpenCodeApi } from '../network/OpenCodeApi';
import type { QuotaWindow } from '../model/UsageRecord';

@Component
export struct DashboardPage {
  @State vm: DashboardViewModel = new DashboardViewModel();
  @State chartVersion: number = 0;
  @State currency: string = 'CNY';
  @State usdCny: number = Constants.DEFAULT_USD_CNY;
  @StorageProp('statusBarHeight') statusBarHeight: number = 0;
  @StorageProp('navIndicatorHeight') navIndicatorHeight: number = 0;
  private refreshRetried: boolean = false;

  aboutToAppear(): void {
    this.refresh();
    this.initCurrency();
  }

  private async refresh(): Promise<void> {
    try {
      await this.vm.load();
      this.chartVersion++;
    } catch (e) {
      // 首次加载失败（如 RDB 初始化竞争）时延迟重试一次，避免页面保持空白
      console.error('Dashboard load failed: ' + (e instanceof Error ? e.message : String(e)));
      if (!this.refreshRetried) {
        this.refreshRetried = true;
        setTimeout(() => { this.refresh(); }, 800);
      }
    }
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
          resetText: formatReset(q.resetInSec, isZh()),
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
          StatCard({ title: $r('app.string.ov_hits'), value: formatTokensUi(this.vm.totals.cacheHitTokens), sub: '', accent: false }).layoutWeight(1)
        }
        .width('100%')
        Row({ space: 10 }) {
          StatCard({ title: $r('app.string.ov_total_tokens'), value: formatTokensUi(this.vm.totals.totalInputTokens + this.vm.totals.totalOutputTokens + this.vm.totals.totalReasoningTokens), sub: '', accent: false }).layoutWeight(1)
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

  /** 今日趋势：24 小时 × 输入/输出交替，共享一个 BarChart。 */
  private trendValues(): number[] {
    const out: number[] = [];
    for (const t of this.vm.trend) {
      out.push(t.input, t.output);
    }
    return out;
  }

  private trendColors(): string[] {
    const out: string[] = [];
    for (let i = 0; i < 24; i++) {
      out.push('#2F6FED', '#34A853');
    }
    return out;
  }

  private trendLabels(): string[] {
    const out: string[] = [];
    for (const t of this.vm.trend) {
      out.push(t.hour, '');
    }
    return out;
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

      // 输入 + 输出分组柱状图（今日 24h，共享同一比例尺）
      Row({ space: 2 }) {
        BarChart({
          labels: this.trendLabels(),
          values: this.trendValues(),
          colors: this.trendColors(),
          version: this.chartVersion,
        })
          .width('100%')
          .height(180)
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
    Stack({ alignContent: Alignment.Top }) {
      // 滚动内容：可滚到固定标题栏下方（标题栏模糊蒙版保证可读性）
      Scroll() {
        Column({ space: 12 }) {
          this.QuotaRow()
          this.OverviewGrid()
          this.TodayTrendCard()
        }
        .padding({ left: 12, right: 12, top: this.statusBarHeight + 64, bottom: 96 })
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.bg_page'))
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
      .scrollBar(BarState.Off)

      // 固定标题栏：顶部让出状态栏（不与通知栏重叠），背景模糊
      Column() {
        Row() {
          Text($r('app.string.home_title')).fontSize(18).fontWeight(FontWeight.Bold)
          Blank()
          this.RangePills()
        }
        .width('100%')
      }
      .width('100%')
      .padding({ left: 12, right: 12, top: 12 + this.statusBarHeight, bottom: 10 })
      .backgroundBlurStyle(BlurStyle.Regular)
    }
    .width('100%')
    .height('100%')
  }
}

// entry/src/main/ets/pages/DashboardPage.ets
import { DashboardViewModel } from './DashboardViewModel';
import { StatCard } from '../components/ui/StatCard';
import { RangeSegmented } from '../components/ui/RangeSegmented';
import { QuotaProgress } from '../components/ui/QuotaProgress';
import { SkeletonQuota, SkeletonStatCard, SkeletonChart } from '../components/ui/Skeleton';
import { BarChart } from '../components/charts/BarChart';
import { formatTokensUi, formatCost, formatCostFine, formatPercent } from '../common/utils/Formatter';
import { formatReset } from '../common/utils/TimeUtil';
import { isZh } from '../common/utils/Locale';
import { Constants } from '../common/constants/Constants';
import { SettingsStore } from '../data/SettingsStore';
import { OpenCodeApi } from '../network/OpenCodeApi';
import type { QuotaWindow } from '../model/UsageRecord';
import { HdsNavigation, HdsNavDestination } from '@kit.UIDesignKit';
import { buildTitleBar } from '../common/utils/NavTitleBar';

@Component
export struct DashboardPage {
  @State vm: DashboardViewModel = new DashboardViewModel();
  @State chartVersion: number = 0;
  @StorageProp('currency') currency: string = 'CNY';
  @StorageProp('usdCny') usdCny: number = Constants.DEFAULT_USD_CNY;
  @StorageProp('statusBarHeight') statusBarHeight: number = 0;
  @StorageProp('navIndicatorHeight') navIndicatorHeight: number = 0;
  /** 沉浸光感档位：响应式依赖，改设置后标题栏材质即时更新。 */
  @StorageProp('glowLevel') glowLevel: number = 1;
  /** 是否已登录：未登录即免登录模式（仅配额可用），用于顶部提示。 */
  @StorageProp('hasToken') hasToken: boolean = false;
  /** 当前展示的是否为离线快照（网络不可用时回退本地已存的官方数据）。 */
  @StorageProp('consoleStale') consoleStale: boolean = false;
  /** 页面滚动控制器：绑定给 HDS 标题栏，驱动「内容滚入栏下渐变模糊」。 */
  private scroller: Scroller = new Scroller();
  @Watch('onSyncFinished') @StorageProp('syncFinishedVersion') syncFinishedVersion: number = 0;
  private refreshRetried: boolean = false;
  /** 首屏是否已加载完成：未完成时用骨架屏占位，避免一屏 0 值。 */
  @State loaded: boolean = false;
  /** 滚动联动：向下滚隐藏悬浮导航栏、向上滚显示（由 Index 播放 HDS 滚动动画）。 */
  onNavChanged?: (hide: boolean) => void;
  private scrollHidden: boolean = false;

  /** 滚动联动：向下滚隐藏悬浮导航栏，向上滚显示。 */
  private handleNavScroll(offset: number): void {
    if (offset > 0 && !this.scrollHidden) {
      this.scrollHidden = true;
      if (this.onNavChanged !== undefined) { this.onNavChanged(true); }
    } else if (offset < 0 && this.scrollHidden) {
      this.scrollHidden = false;
      if (this.onNavChanged !== undefined) { this.onNavChanged(false); }
    }
  }

  aboutToAppear(): void {
    this.refresh();
    this.initCurrency();
  }

  /** 其他页面（设置页）同步完成后自动刷新首页数据。 */
  private onSyncFinished(): void {
    this.refresh();
  }

  private async refresh(): Promise<void> {
    try {
      await this.vm.load();
      this.chartVersion++;
      this.loaded = true;
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
    AppStorage.setOrCreate('currency', await SettingsStore.getCurrency());
    AppStorage.setOrCreate('usdCny', await OpenCodeApi.fetchUsdCny());
  }

  /** 切换周期：更新 VM 周期并重新加载。 */
  private onPickPeriod(period: string): void {
    if (this.vm.period === period) {
      return;
    }
    this.vm.setPeriod(period);
    this.refresh();
  }

  @Builder
  QuotaRow() {
    Column({ space: 10 }) {
      Row() {
        Text($r('app.string.quota_title')).fontSize(15).fontWeight(FontWeight.Bold)
        Blank()
        Text(this.sourceLabel(this.vm.quotaSource)).fontSize(11).fontColor($r('app.color.text_muted'))
      }
      .width('100%')
      // 首屏未加载完：铺 3 块配额骨架，而不是 0% 进度条
      if (!this.loaded && this.vm.quota.length === 0) {
        SkeletonQuota()
        SkeletonQuota()
        SkeletonQuota()
      } else {
        ForEach(this.vm.quota, (q: QuotaWindow) => {
          QuotaProgress({
            label: this.quotaLabel(q.label),
            percent: q.used,
            remainingText: `${q.remaining}%`,
            resetText: formatReset(q.resetInSec, isZh()),
            amountText: this.amountText(q),
          })
        }, (q: QuotaWindow) => q.label)
      }
    }
    .width('100%')
  }

  /** 每请求均费（上游把「均费」附在总费用格子里，这里同步对齐）。 */
  private avgCostText(): string {
    const req = this.vm.totals.requestCount;
    const cost = this.vm.totals.totalCostUsd;
    if (req <= 0 || cost <= 0) {
      return '';
    }
    return `${formatCostFine(cost / req, this.currency, this.usdCny)}${this.res($r('app.string.per_request').id)}`;
  }

  /** 取字符串资源（无参）。 */
  private res(id: number): string {
    try {
      const ctx = this.getUIContext().getHostContext();
      return ctx === undefined ? '' : ctx.resourceManager.getStringSync(id);
    } catch (e) {
      return '';
    }
  }

  private quotaLabel(label: string): string {
    if (label === '5h') { return '5小时'; }
    if (label === 'weekly') { return '每周'; }
    return '每月';
  }

  /** 金额明细（仅控制台 JSON 接口提供）：已用 $x / 限额 $y。 */
  private amountText(q: QuotaWindow): string {
    const used = q.usedUsd !== undefined ? q.usedUsd : -1;
    const limit = q.limitUsd !== undefined ? q.limitUsd : -1;
    if (used < 0 || limit <= 0) {
      return '';
    }
    return `$${used.toFixed(2)} / $${limit.toFixed(2)}`;
  }

  /** 配额数据来源标签（便于确认当前走的是哪一级数据源）。 */
  private sourceLabel(source: string): string {
    if (source === 'official') { return '官方 API'; }
    if (source === 'console') { return '控制台接口'; }
    if (source === 'html') { return '页面解析'; }
    if (source === 'snapshot') { return '离线快照'; }
    if (source === 'mock') { return '示例数据'; }
    return '';
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
        // 首屏未加载完：6 格 KPI 骨架（与 StatCard 同尺寸，替换时不跳动）
        if (!this.loaded && this.vm.totals.requestCount === 0) {
          Row({ space: 10 }) {
            SkeletonStatCard().layoutWeight(1)
            SkeletonStatCard().layoutWeight(1)
          }
          .width('100%')
          Row({ space: 10 }) {
            SkeletonStatCard().layoutWeight(1)
            SkeletonStatCard().layoutWeight(1)
          }
          .width('100%')
          Row({ space: 10 }) {
            SkeletonStatCard().layoutWeight(1)
            SkeletonStatCard().layoutWeight(1)
          }
          .width('100%')
        } else {
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
            StatCard({ title: $r('app.string.ov_cost'), value: formatCost(this.vm.totals.totalCostUsd, this.currency, this.usdCny), sub: this.avgCostText(), accent: false }).layoutWeight(1)
            StatCard({ title: $r('app.string.ov_sessions'), value: `${this.vm.totals.sessionCount}`, sub: '', accent: false }).layoutWeight(1)
          }
          .width('100%')
        }
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

  /** 取字符串资源并按 {0} 替换参数（个别版本 getStringSync 不执行占位符格式化，故手动替换）。 */
  private str(id: number, arg: string): string {
    try {
      const ctx = this.getUIContext().getHostContext();
      if (ctx === undefined) {
        return '';
      }
      const tpl = ctx.resourceManager.getStringSync(id);
      return arg === '' ? tpl : tpl.split('{0}').join(arg);
    } catch (e) {
      console.error('res failed: ' + (e instanceof Error ? e.message : String(e)));
      return '';
    }
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
        // 今日趋势由本地采样重建（官方无小时级接口），标注采样点数
        if (this.vm.trend.length > 0) {
          Text(this.str($r('app.string.today_trend_local').id, `${this.vm.trend.length}`))
            .fontSize(11)
            .fontColor($r('app.color.text_muted'))
        }
      }
      .width('100%')

      // 采样点不足时给说明，而不是一张空图；首屏未加载完则铺图表遮罩
      if (!this.loaded && this.vm.trend.length === 0) {
        SkeletonChart({ blockHeight: 140 })
      } else if (this.vm.trend.length === 0) {
        Text($r('app.string.today_trend_empty'))
          .fontSize(11)
          .fontColor($r('app.color.text_muted'))
          .width('100%')
          .padding({ top: 12, bottom: 12 })
      } else {
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
    }
    .width('100%')
    .padding(12)
    .borderRadius(12)
    .backgroundColor($r('app.color.bg_card'))
  }

  build() {
    // HDS 沉浸光感标题栏（对齐参考项目）：内容滚入栏下触发渐变模糊，材质档位跟随「沉浸光感」设置
    HdsNavigation() {
      HdsNavDestination() {
        Scroll(this.scroller) {
          Column({ space: 12 }) {
            // 周期筛选（官方胶囊分段控件，滑块式指示）置于内容顶部
            RangeSegmented({
              current: this.vm.period,
              onPick: (p: string) => { this.onPickPeriod(p); },
            })
              .width('100%')

            // 离线快照提示：网络不可用时展示本地已存的官方数据
            if (this.consoleStale) {
              Text($r('app.string.stale_snapshot'))
                .fontSize(11)
                .fontColor($r('app.color.text_secondary'))
                .width('100%')
                .padding(10)
                .borderRadius(10)
                .backgroundColor($r('app.color.divider'))
            } else if (!this.hasToken) {
              // 免登录模式提示：只配了 API Key 时，记录/统计无数据
              Text($r('app.string.guest_banner'))
                .fontSize(11)
                .fontColor($r('app.color.text_secondary'))
                .width('100%')
                .padding(10)
                .borderRadius(10)
                .backgroundColor($r('app.color.divider'))
            }

            this.QuotaRow()
            this.OverviewGrid()
            this.TodayTrendCard()
          }
          .width('100%')
          .padding({ left: 12, right: 12, top: this.statusBarHeight + 60, bottom: 96 })
        }
        .width('100%')
        .height('100%')
        .backgroundColor($r('app.color.bg_page'))
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
        .onScrollFrameBegin((offset: number) => {
          this.handleNavScroll(offset);
          return { offsetRemain: offset };
        })
      }
      .titleBar(buildTitleBar($r('app.string.home_title'), this.glowLevel))
      .hideBackButton(true)
      .bindToScrollable([this.scroller])
    }
    .mode(NavigationMode.Stack)
    .hideTitleBar(true)
    .hideToolBar(true)
    .width('100%')
    .height('100%')
  }
}

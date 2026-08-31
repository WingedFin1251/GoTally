// entry/src/main/ets/pages/StatsPage.ets
import { StatsViewModel } from './StatsViewModel';
import { StatCard } from '../components/ui/StatCard';
import { DonutChart, DonutItem } from '../components/charts/DonutChart';
import { LineChart, LineSeries } from '../components/charts/LineChart';
import { formatTokensUi, formatCost } from '../common/utils/Formatter';
import { isZh } from '../common/utils/Locale';
import { Constants } from '../common/constants/Constants';
import { SettingsStore } from '../data/SettingsStore';
import { OpenCodeApi } from '../network/OpenCodeApi';
import type { ModelStat } from '../model/Stats';

@Component
export struct StatsPage {
  @State vm: StatsViewModel = new StatsViewModel();
  @State chartVersion: number = 0;
  @StorageProp('currency') currency: string = 'CNY';
  @StorageProp('usdCny') usdCny: number = Constants.DEFAULT_USD_CNY;
  @StorageProp('statusBarHeight') statusBarHeight: number = 0;
  @StorageProp('navIndicatorHeight') navIndicatorHeight: number = 0;
  @Watch('onSyncFinished') @StorageProp('syncFinishedVersion') syncFinishedVersion: number = 0;
  private refreshRetried: boolean = false;

  aboutToAppear(): void {
    this.refresh();
    this.initCurrency();
  }

  /** 其他页面（设置页）同步完成后自动刷新统计页数据。 */
  private onSyncFinished(): void {
    this.refresh();
  }

  private async refresh(): Promise<void> {
    try {
      await this.vm.load();
    } catch (e) {
      // 首次加载失败（如 RDB 初始化竞争）时延迟重试一次，避免页面保持空白
      console.error('Stats load failed: ' + (e instanceof Error ? e.message : String(e)));
      if (!this.refreshRetried) {
        this.refreshRetried = true;
        setTimeout(() => { this.refresh(); }, 800);
      }
    } finally {
      // 无论成败都递增版本号，强制图表按最新数据重建（避免停留在上一次 period 的旧数据）
      this.chartVersion++;
    }
  }

  private async initCurrency(): Promise<void> {
    AppStorage.setOrCreate('currency', await SettingsStore.getCurrency());
    AppStorage.setOrCreate('usdCny', await OpenCodeApi.fetchUsdCny());
  }

  private dimValue(m: ModelStat, dim: string): number {
    if (dim === 'output') { return m.totalOutputTokens; }
    if (dim === 'cost') { return m.totalCostUsd; }
    return m.totalInputTokens;
  }

  private formatDimValue(m: ModelStat): string {
    if (this.vm.dim === 'cost') {
      return formatCost(this.dimValue(m, 'cost'), this.currency, this.usdCny);
    }
    return formatTokensUi(this.dimValue(m, this.vm.dim));
  }

  private donutItems(): DonutItem[] {
    const palette = ['#2F6FED', '#34A853', '#FBBC04', '#EA4335', '#9334E6', '#00ACC1'];
    const items: DonutItem[] = [];
    this.vm.models.forEach((m, i) => {
      items.push({ label: m.model, value: this.dimValue(m, this.vm.dim), color: palette[i % palette.length] });
    });
    return items;
  }

  private trendSeries(): LineSeries[] {
    const costs = this.vm.daily30.map((d) => d.totalCostUsd);
    const requests = this.vm.daily30.map((d) => d.requestCount);
    const tokens = this.vm.daily30.map((d) => d.totalInputTokens + d.totalOutputTokens + d.totalReasoningTokens);
    const zh = isZh();
    return [
      // 成本量纲（美元）远小于 Token/请求，走独立右轴，避免被压成贴 X 轴的一条线
      { name: zh ? '成本' : 'cost', color: '#EA4335', values: costs, axis: 'right' },
      { name: zh ? '请求' : 'requests', color: '#2F6FED', values: requests, axis: 'left' },
      { name: zh ? 'Token' : 'tokens', color: '#34A853', values: tokens, axis: 'left' },
    ];
  }

  private trendLabels(): string[] {
    return this.vm.daily30.map((d) => {
      const parts = d.date.split('-');
      return parts.length >= 2 ? `${parts[1]}-${parts[2]}` : d.date;
    });
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
  KpiCards() {
    // Row/Column 两列布局（Grid 在 Scroll 内无高度会折叠）
    Column({ space: 10 }) {
      Row({ space: 10 }) {
        StatCard({ title: $r('app.string.total_input'), value: formatTokensUi(this.vm.totals.totalInputTokens), sub: '', accent: false }).layoutWeight(1)
        StatCard({ title: $r('app.string.output'), value: formatTokensUi(this.vm.totals.totalOutputTokens), sub: '', accent: false }).layoutWeight(1)
      }
      .width('100%')
      Row({ space: 10 }) {
        StatCard({ title: $r('app.string.reasoning'), value: formatTokensUi(this.vm.totals.totalReasoningTokens), sub: '', accent: false }).layoutWeight(1)
        StatCard({ title: $r('app.string.cost'), value: formatCost(this.vm.totals.totalCostUsd, this.currency, this.usdCny), sub: '', accent: true }).layoutWeight(1)
      }
      .width('100%')
    }
    .width('100%')
  }

  @Builder
  TokenDetail() {
    Column({ space: 8 }) {
      Text($r('app.string.token_breakdown')).fontSize(15).fontWeight(FontWeight.Bold)
      // Row/Column 两列布局（Grid 在 Scroll 内无高度会折叠）
      Column({ space: 10 }) {
        Row({ space: 10 }) {
          StatCard({ title: $r('app.string.uncached_input'), value: formatTokensUi(this.vm.totals.uncachedInputTokens), sub: '', accent: false }).layoutWeight(1)
          StatCard({ title: $r('app.string.output'), value: formatTokensUi(this.vm.totals.totalOutputTokens), sub: '', accent: false }).layoutWeight(1)
        }
        .width('100%')
        Row({ space: 10 }) {
          StatCard({ title: $r('app.string.reasoning'), value: formatTokensUi(this.vm.totals.totalReasoningTokens), sub: '', accent: false }).layoutWeight(1)
          StatCard({ title: $r('app.string.cache_read'), value: formatTokensUi(this.vm.totals.cacheHitTokens), sub: '', accent: false }).layoutWeight(1)
        }
        .width('100%')
        Row({ space: 10 }) {
          StatCard({ title: $r('app.string.cache_write'), value: formatTokensUi(this.vm.totals.cacheWriteTokens), sub: '', accent: false }).layoutWeight(1)
          StatCard({ title: $r('app.string.ov_sessions'), value: `${this.vm.totals.sessionCount}`, sub: '', accent: false }).layoutWeight(1)
        }
        .width('100%')
      }
      .width('100%')
    }
    .width('100%')
    .padding(12)
    .borderRadius(12)
    .backgroundColor($r('app.color.bg_card'))
  }

  @Builder
  ModelRank() {
    Column({ space: 8 }) {
      Row() {
        Text($r('app.string.model_usage')).fontSize(15).fontWeight(FontWeight.Bold)
        Blank()
      }
      .width('100%')

      // 维度切换独立成行，避免窄屏下「成本」标签被卡片边缘截断
      Row({ space: 6 }) {
        this.DimPill('input', $r('app.string.input'))
        this.DimPill('output', $r('app.string.output'))
        this.DimPill('cost', $r('app.string.cost'))
      }
      .width('100%')

      Row() {
        DonutChart({
          items: this.donutItems(),
          centerTitle: this.dimTitle(),
          centerValue: this.dimTotalText(),
        })
          .key(`donut-${this.chartVersion}`)
          .width(160)
          .height(160)

        Column({ space: 6 }) {
          ForEach(this.vm.models.slice(0, 6), (m: ModelStat) => {
            Row({ space: 6 }) {
              Text('●').fontSize(10).fontColor(this.modelColor(m.model))
              Text(m.model).fontSize(12).fontColor($r('app.color.text_primary')).layoutWeight(1).maxLines(1)
              Text(this.formatDimValue(m)).fontSize(12).fontColor($r('app.color.text_secondary'))
              Text(`${this.modelShare(m)}%`).fontSize(10).fontColor($r('app.color.text_muted')).width(44).textAlign(TextAlign.End)
            }
            .width('100%')
          }, (m: ModelStat) => m.model)
        }
        .layoutWeight(1)
      }
      .width('100%')
    }
    .width('100%')
    .padding(12)
    .borderRadius(12)
    .backgroundColor($r('app.color.bg_card'))
  }

  private modelColor(model: string): string {
    const palette = ['#2F6FED', '#34A853', '#FBBC04', '#EA4335', '#9334E6', '#00ACC1'];
    const idx = this.vm.models.findIndex((m) => m.model === model);
    return palette[idx >= 0 ? idx % palette.length : 0];
  }

  /** 模型在当前维度下的占比（百分比，1 位小数；异常数据钳制到 100）。 */
  private modelShare(m: ModelStat): string {
    let total = 0;
    for (const x of this.vm.models) {
      total += this.dimValue(x, this.vm.dim);
    }
    if (total <= 0) {
      return '0.0';
    }
    const pct = Math.min(100, this.dimValue(m, this.vm.dim) / total * 100);
    return pct.toFixed(1);
  }

  /** 饼图中心标题：跟随当前维度（DonutChart centerTitle 为 string，需自行按语言取文案）。 */
  private dimTitle(): string {
    if (this.vm.dim === 'cost') { return isZh() ? '成本' : 'Cost'; }
    if (this.vm.dim === 'output') { return isZh() ? '输出' : 'Output'; }
    return isZh() ? '输入' : 'Input';
  }

  /** 饼图中心数值：与饼图分项同口径（当前维度分项之和），避免「中心总 Token 与分项不符」的观感。 */
  private dimTotalText(): string {
    let total = 0;
    for (const m of this.vm.models) {
      total += this.dimValue(m, this.vm.dim);
    }
    return this.vm.dim === 'cost' ? formatCost(total, this.currency, this.usdCny) : formatTokensUi(total);
  }

  @Builder
  DimPill(dim: string, label: Resource) {
    Text(label)
      .fontSize(10)
      .padding({ left: 6, right: 6, top: 3, bottom: 3 })
      .borderRadius(10)
      .maxLines(1)
      .textOverflow({ overflow: TextOverflow.Ellipsis })
      .backgroundColor(this.vm.dim === dim ? $r('app.color.accent') : $r('app.color.divider'))
      .fontColor(this.vm.dim === dim ? Color.White : $r('app.color.text_secondary'))
      .onClick(() => {
        this.vm.setDim(dim as 'input' | 'output' | 'cost');
        this.chartVersion++;
      })
  }

  @Builder
  TrendCard() {
    Column({ space: 8 }) {
      Row() {
        Text($r('app.string.usage_trend')).fontSize(15).fontWeight(FontWeight.Bold)
        Blank()
      }
      .width('100%')
      LineChart({
        series: this.trendSeries(),
        labels: this.trendLabels(),
      })
        .key(`line-${this.chartVersion}`)
        .width('100%')
        .height(240)
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
          this.KpiCards()
          this.TokenDetail()
          this.ModelRank()
          this.TrendCard()
        }
        .width('100%')
        .padding({ left: 12, right: 12, top: this.statusBarHeight + 52, bottom: 96 })
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.bg_page'))
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
      .scrollBar(BarState.Off)

      // 固定标题栏：顶部让出状态栏（不与通知栏重叠），背景模糊
      Column() {
        Row() {
          Text($r('app.string.stats_title')).fontSize(18).fontWeight(FontWeight.Bold)
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

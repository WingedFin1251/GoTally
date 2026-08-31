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
import type { Totals, ModelStat, DailyStat, TrendPoint } from '../model/Stats';

const EMPTY_TOTALS: Totals = { requestCount: 0, sessionCount: 0, totalInputTokens: 0, uncachedInputTokens: 0, totalReasoningTokens: 0, cacheHitTokens: 0, cacheWriteTokens: 0, totalOutputTokens: 0, totalCostUsd: 0, hitRate: 0 };

@Component
export struct StatsPage {
  // 图表/列表依赖的展示数据全部上提到顶层 @State：赋值即触发本章 build，
  // DonutChart/LineChart 通过 @Prop 接收新值后由 @Watch 自动重绘，无需 key 强制重建。
  @State period: string = '7d';
  @State dim: 'input' | 'output' | 'cost' = 'input';
  @State totals: Totals = EMPTY_TOTALS;
  @State models: ModelStat[] = [];
  @State daily30: DailyStat[] = [];
  @State todayTrend: TrendPoint[] = [];
  /** 数据版本号：每次加载完成后 +1，作为 ForEach 的 key 后缀，强制模型列表项重建（读取最新数据）。 */
  @State dataVersion: number = 0;
  private vm: StatsViewModel = new StatsViewModel();
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
      // 显式传入当前周期，与页面顶层 @State period 保持单一数据源，避免 vm 内部缓存旧周期
      await this.vm.load(this.period);
      // 镜像 VM 结果到顶层 @State：数据进来必然触发 build → 图表 @Prop 更新 → 自动重绘
      this.totals = this.vm.totals;
      this.models = this.vm.models;
      this.daily30 = this.vm.daily30;
      this.todayTrend = this.vm.todayTrend;
    } catch (e) {
      // 首次加载失败（如 RDB 初始化竞争）时延迟重试一次，避免页面保持空白
      console.error('Stats load failed: ' + (e instanceof Error ? e.message : String(e)));
      if (!this.refreshRetried) {
        this.refreshRetried = true;
        setTimeout(() => { this.refresh(); }, 800);
      }
    } finally {
      this.dataVersion++;
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
    if (this.dim === 'cost') {
      return formatCost(this.dimValue(m, 'cost'), this.currency, this.usdCny);
    }
    return formatTokensUi(this.dimValue(m, this.dim));
  }

  private donutItems(): DonutItem[] {
    const palette = ['#2F6FED', '#34A853', '#FBBC04', '#EA4335', '#9334E6', '#00ACC1'];
    const items: DonutItem[] = [];
    this.models.forEach((m, i) => {
      items.push({ label: m.model, value: this.dimValue(m, this.dim), color: palette[i % palette.length] });
    });
    return items;
  }

  private trendSeries(): LineSeries[] {
    const zh = isZh();
    if (this.period === Constants.PERIOD_TODAY) {
      // 「今天」：24 小时逐时趋势（输入/输出/推理，同量纲共左轴）
      const ins = this.todayTrend.map((d) => d.input);
      const out = this.todayTrend.map((d) => d.output);
      const rea = this.todayTrend.map((d) => d.reasoning);
      return [
        { name: zh ? '输入' : 'input', color: '#2F6FED', values: ins },
        { name: zh ? '输出' : 'output', color: '#34A853', values: out },
        { name: zh ? '推理' : 'reasoning', color: '#FBBC04', values: rea },
      ];
    }
    // 非 today：最近 N 天逐日趋势。Token（亿级）走左轴、成本（美元）走独立右轴，
    // 请求数量级介于二者之间、共轴会被压缩，故不在趋势图内展示。
    const costs = this.daily30.map((d) => d.totalCostUsd);
    const tokens = this.daily30.map((d) => d.totalInputTokens + d.totalOutputTokens + d.totalReasoningTokens);
    return [
      { name: zh ? 'Token' : 'tokens', color: '#34A853', values: tokens },
      { name: zh ? '成本' : 'cost', color: '#EA4335', values: costs, axis: 'right' },
    ];
  }

  private trendLabels(): string[] {
    if (this.period === Constants.PERIOD_TODAY) {
      return this.todayTrend.map((d) => d.hour);
    }
    return this.daily30.map((d) => {
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
      .backgroundColor(this.period === period ? $r('app.color.accent') : $r('app.color.divider'))
      .fontColor(this.period === period ? Color.White : $r('app.color.text_secondary'))
      .onClick(() => {
        this.period = period;
        this.refresh();
      })
  }

  @Builder
  KpiCards() {
    // Row/Column 两列布局（Grid 在 Scroll 内无高度会折叠）
    Column({ space: 10 }) {
      Row({ space: 10 }) {
        StatCard({ title: $r('app.string.total_input'), value: formatTokensUi(this.totals.totalInputTokens), sub: '', accent: false }).layoutWeight(1)
        StatCard({ title: $r('app.string.output'), value: formatTokensUi(this.totals.totalOutputTokens), sub: '', accent: false }).layoutWeight(1)
      }
      .width('100%')
      Row({ space: 10 }) {
        StatCard({ title: $r('app.string.reasoning'), value: formatTokensUi(this.totals.totalReasoningTokens), sub: '', accent: false }).layoutWeight(1)
        StatCard({ title: $r('app.string.cost'), value: formatCost(this.totals.totalCostUsd, this.currency, this.usdCny), sub: '', accent: true }).layoutWeight(1)
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
          StatCard({ title: $r('app.string.uncached_input'), value: formatTokensUi(this.totals.uncachedInputTokens), sub: '', accent: false }).layoutWeight(1)
          StatCard({ title: $r('app.string.output'), value: formatTokensUi(this.totals.totalOutputTokens), sub: '', accent: false }).layoutWeight(1)
        }
        .width('100%')
        Row({ space: 10 }) {
          StatCard({ title: $r('app.string.reasoning'), value: formatTokensUi(this.totals.totalReasoningTokens), sub: '', accent: false }).layoutWeight(1)
          StatCard({ title: $r('app.string.cache_read'), value: formatTokensUi(this.totals.cacheHitTokens), sub: '', accent: false }).layoutWeight(1)
        }
        .width('100%')
        Row({ space: 10 }) {
          StatCard({ title: $r('app.string.cache_write'), value: formatTokensUi(this.totals.cacheWriteTokens), sub: '', accent: false }).layoutWeight(1)
          StatCard({ title: $r('app.string.ov_sessions'), value: `${this.totals.sessionCount}`, sub: '', accent: false }).layoutWeight(1)
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
          .width(160)
          .height(160)

        Column({ space: 6 }) {
          ForEach(this.models.slice(0, 6), (m: ModelStat) => {
            Row({ space: 6 }) {
              Text('●').fontSize(10).fontColor(this.modelColor(m.model))
              Text(m.model).fontSize(12).fontColor($r('app.color.text_primary')).layoutWeight(1).maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .onClick(() => { this.toast(m.model); })
              Text(this.formatDimValue(m)).fontSize(12).fontColor($r('app.color.text_secondary'))
              Text(`${this.modelShare(m)}%`).fontSize(10).fontColor($r('app.color.text_muted')).width(44).textAlign(TextAlign.End)
            }
            .width('100%')
          }, (m: ModelStat) => `${m.model}-${this.dataVersion}`)
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
    const idx = this.models.findIndex((m) => m.model === model);
    return palette[idx >= 0 ? idx % palette.length : 0];
  }

  private toast(msg: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: msg });
    } catch (e) {
      console.error('toast failed: ' + (e instanceof Error ? e.message : String(e)));
    }
  }

  /** 模型在当前维度下的占比（百分比，1 位小数；异常数据钳制到 100）。 */
  private modelShare(m: ModelStat): string {
    let total = 0;
    for (const x of this.models) {
      total += this.dimValue(x, this.dim);
    }
    if (total <= 0) {
      return '0.0';
    }
    const pct = Math.min(100, this.dimValue(m, this.dim) / total * 100);
    return pct.toFixed(1);
  }

  /** 饼图中心标题：跟随当前维度（DonutChart centerTitle 为 string，需自行按语言取文案）。 */
  private dimTitle(): string {
    if (this.dim === 'cost') { return isZh() ? '成本' : 'Cost'; }
    if (this.dim === 'output') { return isZh() ? '输出' : 'Output'; }
    return isZh() ? '输入' : 'Input';
  }

  /** 饼图中心数值：与饼图分项同口径（当前维度分项之和），避免「中心总 Token 与分项不符」的观感。 */
  private dimTotalText(): string {
    let total = 0;
    for (const m of this.models) {
      total += this.dimValue(m, this.dim);
    }
    return this.dim === 'cost' ? formatCost(total, this.currency, this.usdCny) : formatTokensUi(total);
  }

  @Builder
  DimPill(dim: string, label: Resource) {
    Text(label)
      .fontSize(10)
      .padding({ left: 6, right: 6, top: 3, bottom: 3 })
      .borderRadius(10)
      .maxLines(1)
      .textOverflow({ overflow: TextOverflow.Ellipsis })
      .backgroundColor(this.dim === dim ? $r('app.color.accent') : $r('app.color.divider'))
      .fontColor(this.dim === dim ? Color.White : $r('app.color.text_secondary'))
      .onClick(() => {
        this.dim = dim as 'input' | 'output' | 'cost';
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
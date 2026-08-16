// entry/src/main/ets/pages/StatsPage.ets
import { display } from '@kit.ArkUI';
import { StatsViewModel } from './StatsViewModel';
import { StatCard } from '../components/ui/StatCard';
import { DonutChart, DonutItem } from '../components/charts/DonutChart';
import { LineChart, LineSeries } from '../components/charts/LineChart';
import { formatTokens, formatCost } from '../common/utils/Formatter';
import { Constants } from '../common/constants/Constants';
import { SettingsStore } from '../data/SettingsStore';
import { OpenCodeApi } from '../network/OpenCodeApi';
import type { ModelStat } from '../model/Stats';

@Component
export struct StatsPage {
  @State vm: StatsViewModel = new StatsViewModel();
  @State chartVersion: number = 0;
  @State currency: string = 'CNY';
  @State usdCny: number = Constants.DEFAULT_USD_CNY;
  @State wide: boolean = false;

  aboutToAppear(): void {
    this.wide = display.getDefaultDisplaySync().width >= 840;
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

  private dimValue(m: ModelStat, dim: string): number {
    if (dim === 'output') { return m.totalOutputTokens; }
    if (dim === 'cost') { return m.totalCostUsd; }
    return m.totalInputTokens;
  }

  private formatDimValue(m: ModelStat): string {
    if (this.vm.dim === 'cost') {
      return formatCost(this.dimValue(m, 'cost'), this.currency, this.usdCny);
    }
    return formatTokens(this.dimValue(m, this.vm.dim));
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
    return [
      { name: 'cost', color: '#EA4335', values: costs },
      { name: 'requests', color: '#2F6FED', values: requests },
      { name: 'tokens', color: '#34A853', values: tokens },
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
        StatCard({ title: $r('app.string.input'), value: formatTokens(this.vm.totals.totalInputTokens), sub: '', accent: false }).layoutWeight(1)
        StatCard({ title: $r('app.string.output'), value: formatTokens(this.vm.totals.totalOutputTokens), sub: '', accent: false }).layoutWeight(1)
      }
      .width('100%')
      Row({ space: 10 }) {
        StatCard({ title: $r('app.string.reasoning'), value: formatTokens(this.vm.totals.totalReasoningTokens), sub: '', accent: false }).layoutWeight(1)
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
          StatCard({ title: $r('app.string.input'), value: formatTokens(this.vm.totals.uncachedInputTokens), sub: '', accent: false }).layoutWeight(1)
          StatCard({ title: $r('app.string.output'), value: formatTokens(this.vm.totals.totalOutputTokens), sub: '', accent: false }).layoutWeight(1)
        }
        .width('100%')
        Row({ space: 10 }) {
          StatCard({ title: $r('app.string.reasoning'), value: formatTokens(this.vm.totals.totalReasoningTokens), sub: '', accent: false }).layoutWeight(1)
          StatCard({ title: $r('app.string.cache_read'), value: formatTokens(this.vm.totals.cacheHitTokens), sub: '', accent: false }).layoutWeight(1)
        }
        .width('100%')
        Row({ space: 10 }) {
          StatCard({ title: $r('app.string.cache_write'), value: formatTokens(this.vm.totals.cacheWriteTokens), sub: '', accent: false }).layoutWeight(1)
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
        Row({ space: 6 }) {
          this.DimPill('input', $r('app.string.input'))
          this.DimPill('output', $r('app.string.output'))
          this.DimPill('cost', $r('app.string.cost'))
        }
      }
      .width('100%')

      Row() {
        DonutChart({
          items: this.donutItems(),
          centerTitle: '总Token',
          centerValue: formatTokens(this.vm.totals.totalInputTokens + this.vm.totals.totalOutputTokens + this.vm.totals.totalReasoningTokens),
        })
          .key(this.chartVersion)
          .width(160)
          .height(160)

        Column({ space: 6 }) {
          ForEach(this.vm.models.slice(0, 6), (m: ModelStat) => {
            Row({ space: 6 }) {
              Text('●').fontSize(10).fontColor(this.modelColor(m.model))
              Text(m.model).fontSize(12).fontColor($r('app.color.text_primary')).layoutWeight(1).maxLines(1)
              Text(this.formatDimValue(m)).fontSize(12).fontColor($r('app.color.text_secondary'))
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

  @Builder
  DimPill(dim: string, label: Resource) {
    Text(label)
      .fontSize(11)
      .padding({ left: 8, right: 8, top: 3, bottom: 3 })
      .borderRadius(10)
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
        .key(this.chartVersion)
        .width('100%')
        .height(240)
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
          Text($r('app.string.stats_title')).fontSize(18).fontWeight(FontWeight.Bold)
          Blank()
          this.RangePills()
        }
        .width('100%')

        this.KpiCards()
        this.TokenDetail()
        if (this.wide) {
          Row({ space: 12 }) {
            this.ModelRank().layoutWeight(1)
            this.TrendCard().layoutWeight(1)
          }
          .width('100%')
        } else {
          this.ModelRank()
          this.TrendCard()
        }
      }
      .padding(12)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.bg_page'))
    .scrollBar(BarState.Off)
  }
}

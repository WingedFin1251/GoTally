// entry/src/main/ets/pages/RecordsPage.ets
import { promptAction } from '@kit.ArkUI';
import { RecordsViewModel } from './RecordsViewModel';
import { Pager } from '../components/ui/Pager';
import { formatTokensUi, formatCost } from '../common/utils/Formatter';
import { formatDateTimeShort, parseIso } from '../common/utils/TimeUtil';
import { SettingsStore } from '../data/SettingsStore';
import { OpenCodeApi } from '../network/OpenCodeApi';
import { Constants } from '../common/constants/Constants';
import type { SessionStat, RecordRow } from '../model/Stats';

@Component
export struct RecordsPage {
  @State vm: RecordsViewModel = new RecordsViewModel();
  @StorageProp('currency') currency: string = 'CNY';
  @StorageProp('usdCny') usdCny: number = Constants.DEFAULT_USD_CNY;
  @StorageProp('statusBarHeight') statusBarHeight: number = 0;
  @StorageProp('navIndicatorHeight') navIndicatorHeight: number = 0;
  private reloadRetried: boolean = false;

  aboutToAppear(): void {
    this.reload();
    this.initCurrency();
  }

  private async reload(): Promise<void> {
    try {
      await this.vm.loadSessions(1);
      await this.vm.loadRecords(1);
    } catch (e) {
      // 首次加载失败（如 RDB 初始化竞争）时延迟重试一次，避免页面保持空白
      console.error('Records load failed: ' + (e instanceof Error ? e.message : String(e)));
      if (!this.reloadRetried) {
        this.reloadRetried = true;
        setTimeout(() => { this.reload(); }, 800);
      }
    }
  }

  private async initCurrency(): Promise<void> {
    AppStorage.setOrCreate('currency', await SettingsStore.getCurrency());
    AppStorage.setOrCreate('usdCny', await OpenCodeApi.fetchUsdCny());
  }

  /** 「共 N 条」本地化（getStringSync 推荐传资源 id，避免已废弃的 Resource 重载）。 */
  private countHint(n: number): string {
    return getContext(this).resourceManager.getStringSync($r('app.string.records_count_hint').id, n);
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
        this.reload();
      })
  }

  @Builder
  SessionsCard() {
    Column({ space: 8 }) {
      Row() {
        Text($r('app.string.session_usage')).fontSize(15).fontWeight(FontWeight.Bold)
        Blank()
        Text(this.countHint(this.vm.sessionTotal)).fontSize(11).fontColor($r('app.color.text_muted'))
      }
      .width('100%')

      Column() {
        Row() {
          Text($r('app.string.col_session')).fontSize(11).layoutWeight(2).fontColor($r('app.color.text_muted'))
          Text($r('app.string.col_input')).fontSize(11).layoutWeight(1).fontColor($r('app.color.text_muted')).textAlign(TextAlign.End)
          Text($r('app.string.col_output')).fontSize(11).layoutWeight(1).fontColor($r('app.color.text_muted')).textAlign(TextAlign.End)
          Text($r('app.string.col_requests')).fontSize(11).layoutWeight(1).fontColor($r('app.color.text_muted')).textAlign(TextAlign.End)
          Text($r('app.string.col_cost')).fontSize(11).layoutWeight(1).fontColor($r('app.color.text_muted')).textAlign(TextAlign.End)
        }
        .width('100%')
        .padding({ top: 6, bottom: 6 })

        if (this.vm.sessions.length === 0) {
          Text($r('app.string.list_empty_hint'))
            .fontSize(12)
            .fontColor($r('app.color.text_muted'))
            .width('100%')
            .textAlign(TextAlign.Center)
            .padding({ top: 14, bottom: 14 })
        } else {
          ForEach(this.vm.sessions, (s: SessionStat) => {
            Row() {
              Text(this.shortSession(s.sessionId)).fontSize(12).layoutWeight(2).fontColor($r('app.color.text_primary')).maxLines(1)
              Text(formatTokensUi(s.totalInputTokens)).fontSize(12).layoutWeight(1).textAlign(TextAlign.End).fontColor($r('app.color.text_secondary'))
              Text(formatTokensUi(s.totalOutputTokens)).fontSize(12).layoutWeight(1).textAlign(TextAlign.End).fontColor($r('app.color.text_secondary'))
              Text(`${s.requestCount}`).fontSize(12).layoutWeight(1).textAlign(TextAlign.End).fontColor($r('app.color.text_secondary'))
              Text(formatCost(s.totalCostUsd, this.currency, this.usdCny)).fontSize(12).layoutWeight(1).textAlign(TextAlign.End).fontColor($r('app.color.text_secondary'))
            }
            .width('100%')
            .padding({ top: 5, bottom: 5 })
          }, (s: SessionStat) => s.sessionId)
        }
      }
      .width('100%')

      if (Math.ceil(this.vm.sessionTotal / 10) > 1) {
        Pager({
          page: this.vm.sessionPage,
          totalPages: Math.ceil(this.vm.sessionTotal / 10),
          onPrev: () => { this.vm.loadSessions(this.vm.sessionPage - 1); },
          onNext: () => { this.vm.loadSessions(this.vm.sessionPage + 1); },
        })
      }
    }
    .width('100%')
    .padding(12)
    .borderRadius(12)
    .backgroundColor($r('app.color.bg_card'))
  }

  private shortSession(id: string): string {
    if (id === '') { return '未归属'; }
    return id.length > 12 ? `…${id.substring(id.length - 12)}` : id;
  }

  /**
   * 记录时间文本：能解析显示为 'MM-DD HH:mm'；解析失败显示原始 createdAt（截断），
   * 便于识别服务器返回的异常时间格式（此时「今天/近7天」过滤也会查不到该行）。
   */
  private timeText(r: RecordRow): string {
    const ms = parseIso(r.createdAt);
    if (ms > 0) {
      return formatDateTimeShort(ms);
    }
    const raw = r.createdAt;
    if (raw === '') {
      return '--';
    }
    return raw.length > 20 ? `${raw.substring(0, 20)}…` : raw;
  }

  /** Select 选项：首项「全部模型」（资源），其后各模型。Select 期望 SelectOption[]。 */
  private modelOptions(): SelectOption[] {
    const out: SelectOption[] = [{ value: $r('app.string.all_models') }];
    for (const m of this.vm.models) {
      out.push({ value: m });
    }
    return out;
  }

  private modelSelectIndex(): number {
    const idx = this.vm.models.indexOf(this.vm.selectedModel);
    return idx >= 0 ? idx + 1 : 0;
  }

  @Builder
  RecordsCard() {
    Column({ space: 8 }) {
      Row() {
        Text($r('app.string.usage_records')).fontSize(15).fontWeight(FontWeight.Bold)
        Blank()
        Select(this.modelOptions())
          .selected(this.modelSelectIndex())
          .value(this.vm.selectedModel === '' ? $r('app.string.all_models') : this.vm.selectedModel)
          .font({ size: 12 })
          .width(140)
          .onSelect((index: number) => {
            this.vm.setModel(index === 0 ? '' : this.vm.models[index - 1]);
          })
        Text(this.countHint(this.vm.recordTotal)).fontSize(11).fontColor($r('app.color.text_muted'))
      }
      .width('100%')

      Column() {
        Row() {
          Text($r('app.string.col_time')).fontSize(11).layoutWeight(2).fontColor($r('app.color.text_muted'))
          Text($r('app.string.col_model')).fontSize(11).layoutWeight(3).fontColor($r('app.color.text_muted'))
          Text($r('app.string.col_input')).fontSize(11).layoutWeight(1).fontColor($r('app.color.text_muted')).textAlign(TextAlign.End)
          Text($r('app.string.col_output')).fontSize(11).layoutWeight(1).fontColor($r('app.color.text_muted')).textAlign(TextAlign.End)
          Text($r('app.string.col_fee')).fontSize(11).layoutWeight(1).fontColor($r('app.color.text_muted')).textAlign(TextAlign.End)
        }
        .width('100%')
        .padding({ top: 6, bottom: 6 })

        if (this.vm.records.length === 0) {
          Text($r('app.string.list_empty_hint'))
            .fontSize(12)
            .fontColor($r('app.color.text_muted'))
            .width('100%')
            .textAlign(TextAlign.Center)
            .padding({ top: 14, bottom: 14 })
        } else {
          ForEach(this.vm.records, (r: RecordRow) => {
            Row() {
              Text(this.timeText(r)).fontSize(11).layoutWeight(2).fontColor($r('app.color.text_secondary')).maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .onClick(() => {
                  promptAction.showToast({ message: r.createdAt === '' ? '--' : r.createdAt });
                })
              Text(r.model).fontSize(11).layoutWeight(3).fontColor($r('app.color.text_primary')).maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
                .onClick(() => {
                  promptAction.showToast({ message: r.model });
                })
              Text(formatTokensUi(r.inputTokens)).fontSize(11).layoutWeight(1).textAlign(TextAlign.End).fontColor($r('app.color.text_secondary'))
              Text(formatTokensUi(r.outputTokens)).fontSize(11).layoutWeight(1).textAlign(TextAlign.End).fontColor($r('app.color.text_secondary'))
              Text(formatCost(r.costUsd, this.currency, this.usdCny)).fontSize(11).layoutWeight(1).textAlign(TextAlign.End).fontColor($r('app.color.text_secondary'))
            }
            .width('100%')
            .padding({ top: 4, bottom: 4 })
          }, (r: RecordRow) => r.usgId)
        }
      }
      .width('100%')

      if (Math.ceil(this.vm.recordTotal / 50) > 1) {
        Pager({
          page: this.vm.recordPage,
          totalPages: Math.ceil(this.vm.recordTotal / 50),
          onPrev: () => { this.vm.loadRecords(this.vm.recordPage - 1); },
          onNext: () => { this.vm.loadRecords(this.vm.recordPage + 1); },
        })
      }
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
          this.SessionsCard()
          this.RecordsCard()
        }
        .width('100%')
        .constraintSize({ minHeight: '100%' })
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
          Text($r('app.string.records_page')).fontSize(18).fontWeight(FontWeight.Bold)
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

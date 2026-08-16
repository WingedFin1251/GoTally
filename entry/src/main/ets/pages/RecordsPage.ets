// entry/src/main/ets/pages/RecordsPage.ets
import { RecordsViewModel } from './RecordsViewModel';
import { Pager } from '../components/ui/Pager';
import { formatTokens, formatCost } from '../common/utils/Formatter';
import { formatDateTime, parseIso } from '../common/utils/TimeUtil';
import { SettingsStore } from '../data/SettingsStore';
import { OpenCodeApi } from '../network/OpenCodeApi';
import { Constants } from '../common/constants/Constants';
import type { SessionStat, RecordRow } from '../model/Stats';

@Component
export struct RecordsPage {
  @State vm: RecordsViewModel = new RecordsViewModel();
  @State currency: string = 'CNY';
  @State usdCny: number = Constants.DEFAULT_USD_CNY;

  aboutToAppear(): void {
    this.reload();
    this.initCurrency();
  }

  private async reload(): Promise<void> {
    await this.vm.loadSessions(1);
    await this.vm.loadRecords(1);
  }

  private async initCurrency(): Promise<void> {
    this.currency = await SettingsStore.getCurrency();
    this.usdCny = await OpenCodeApi.fetchUsdCny();
  }

  @Builder
  SessionsCard() {
    Column({ space: 8 }) {
      Row() {
        Text($r('app.string.session_usage')).fontSize(15).fontWeight(FontWeight.Bold)
        Blank()
        Text(`${this.vm.sessionTotal}`).fontSize(11).fontColor($r('app.color.text_muted'))
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

        ForEach(this.vm.sessions, (s: SessionStat) => {
          Row() {
            Text(this.shortSession(s.sessionId)).fontSize(12).layoutWeight(2).fontColor($r('app.color.text_primary')).maxLines(1)
            Text(formatTokens(s.totalInputTokens)).fontSize(12).layoutWeight(1).textAlign(TextAlign.End).fontColor($r('app.color.text_secondary'))
            Text(formatTokens(s.totalOutputTokens)).fontSize(12).layoutWeight(1).textAlign(TextAlign.End).fontColor($r('app.color.text_secondary'))
            Text(`${s.requestCount}`).fontSize(12).layoutWeight(1).textAlign(TextAlign.End).fontColor($r('app.color.text_secondary'))
            Text(formatCost(s.totalCostUsd, this.currency, this.usdCny)).fontSize(12).layoutWeight(1).textAlign(TextAlign.End).fontColor($r('app.color.text_secondary'))
          }
          .width('100%')
          .padding({ top: 5, bottom: 5 })
        }, (s: SessionStat) => s.sessionId)
      }
      .width('100%')

      Pager({
        page: this.vm.sessionPage,
        totalPages: Math.ceil(this.vm.sessionTotal / 10),
        onPrev: () => { this.vm.loadSessions(this.vm.sessionPage - 1); },
        onNext: () => { this.vm.loadSessions(this.vm.sessionPage + 1); },
      })
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
        Text(`${this.vm.recordTotal}`).fontSize(11).fontColor($r('app.color.text_muted'))
      }
      .width('100%')

      Column() {
        Row() {
          Text($r('app.string.col_time')).fontSize(11).layoutWeight(2).fontColor($r('app.color.text_muted'))
          Text($r('app.string.col_model')).fontSize(11).layoutWeight(2).fontColor($r('app.color.text_muted'))
          Text($r('app.string.col_input')).fontSize(11).layoutWeight(1).fontColor($r('app.color.text_muted')).textAlign(TextAlign.End)
          Text($r('app.string.col_output')).fontSize(11).layoutWeight(1).fontColor($r('app.color.text_muted')).textAlign(TextAlign.End)
          Text($r('app.string.col_fee')).fontSize(11).layoutWeight(1).fontColor($r('app.color.text_muted')).textAlign(TextAlign.End)
        }
        .width('100%')
        .padding({ top: 6, bottom: 6 })

        ForEach(this.vm.records, (r: RecordRow) => {
          Row() {
            Text(formatDateTime(parseIso(r.createdAt))).fontSize(11).layoutWeight(2).fontColor($r('app.color.text_secondary')).maxLines(1)
            Text(r.model).fontSize(11).layoutWeight(2).fontColor($r('app.color.text_primary')).maxLines(1)
            Text(formatTokens(r.inputTokens)).fontSize(11).layoutWeight(1).textAlign(TextAlign.End).fontColor($r('app.color.text_secondary'))
            Text(formatTokens(r.outputTokens)).fontSize(11).layoutWeight(1).textAlign(TextAlign.End).fontColor($r('app.color.text_secondary'))
            Text(formatCost(r.costUsd, this.currency, this.usdCny)).fontSize(11).layoutWeight(1).textAlign(TextAlign.End).fontColor($r('app.color.text_secondary'))
          }
          .width('100%')
          .padding({ top: 4, bottom: 4 })
        }, (r: RecordRow) => r.usgId)
      }
      .width('100%')

      Pager({
        page: this.vm.recordPage,
        totalPages: Math.ceil(this.vm.recordTotal / 50),
        onPrev: () => { this.vm.loadRecords(this.vm.recordPage - 1); },
        onNext: () => { this.vm.loadRecords(this.vm.recordPage + 1); },
      })
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
          Text($r('app.string.records_page')).fontSize(18).fontWeight(FontWeight.Bold)
          Blank()
        }
        .width('100%')

        this.SessionsCard()
        this.RecordsCard()
      }
      .padding(12)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.bg_page'))
    .scrollBar(BarState.Off)
  }
}

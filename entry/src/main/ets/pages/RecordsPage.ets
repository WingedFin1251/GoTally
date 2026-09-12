// entry/src/main/ets/pages/RecordsPage.ets
import { RecordsViewModel } from './RecordsViewModel';
import { Pager } from '../components/ui/Pager';
import { formatTokensUi, formatCost } from '../common/utils/Formatter';
import { formatDateTimeShort, parseIso } from '../common/utils/TimeUtil';
import { SettingsStore } from '../data/SettingsStore';
import { OpenCodeApi } from '../network/OpenCodeApi';
import { Constants } from '../common/constants/Constants';
import type { SessionStat, RecordRow } from '../model/Stats';
import { HdsNavigation, HdsNavDestination } from '@kit.UIDesignKit';
import { buildTitleBar } from '../common/utils/NavTitleBar';

@Component
export struct RecordsPage {
  @State vm: RecordsViewModel = new RecordsViewModel();
  @StorageProp('currency') currency: string = 'CNY';
  @StorageProp('usdCny') usdCny: number = Constants.DEFAULT_USD_CNY;
  @StorageProp('statusBarHeight') statusBarHeight: number = 0;
  @StorageProp('navIndicatorHeight') navIndicatorHeight: number = 0;
  /** 沉浸光感档位：响应式依赖，改设置后标题栏材质即时更新。 */
  @StorageProp('glowLevel') glowLevel: number = 1;
  /** 页面滚动控制器：绑定给 HDS 标题栏，驱动「内容滚入栏下渐变模糊」。 */
  private scroller: Scroller = new Scroller();
  @Watch('onSyncFinished') @StorageProp('syncFinishedVersion') syncFinishedVersion: number = 0;
  /** 数据版本号：每次重载完成 +1，作为 ForEach 键后缀强制列表行重建（避免复用旧闭包导致数值不刷新）。 */
  @State dataVersion: number = 0;
  private reloadRetried: boolean = false;
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
    this.reload();
    this.initCurrency();
  }

  /** 后台/其他页面同步完成后自动刷新记录页数据（无需手动切换周期筛选）。 */
  private onSyncFinished(): void {
    this.reload();
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
    } finally {
      // 无论成败都递增：强制会话/记录列表按最新数据重建
      this.dataVersion++;
    }
  }

  private async initCurrency(): Promise<void> {
    AppStorage.setOrCreate('currency', await SettingsStore.getCurrency());
    AppStorage.setOrCreate('usdCny', await OpenCodeApi.fetchUsdCny());
  }

  /** 「共 N 条」本地化：取模板后手动替换 {0}，避免个别版本 getStringSync 不执行占位符格式化。 */
  private countHint(n: number): string {
    try {
      const ctx = this.getUIContext().getHostContext();
      if (ctx === undefined) {
        return `共 ${n} 条`;
      }
      const tpl = ctx.resourceManager.getStringSync($r('app.string.records_count_hint').id);
      return tpl.split('{0}').join(`${n}`);
    } catch (e) {
      return `共 ${n} 条`;
    }
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
          }, (s: SessionStat) => `${s.sessionId}-${this.dataVersion}`)
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
        Text(this.countHint(this.vm.recordTotal))
          .fontSize(11)
          .fontColor($r('app.color.text_muted'))
          .margin({ left: 10 })
          .constraintSize({ minWidth: 44 })
          .textAlign(TextAlign.End)
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
                  try {
                    this.getUIContext().getPromptAction().showToast({ message: r.createdAt === '' ? '--' : r.createdAt });
                  } catch (e) {
                    console.error('toast failed: ' + (e instanceof Error ? e.message : String(e)));
                  }
                })
              Text(r.model).fontSize(11).layoutWeight(3).fontColor($r('app.color.text_primary')).maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
                .onClick(() => {
                  try {
                    this.getUIContext().getPromptAction().showToast({ message: r.model });
                  } catch (e) {
                    console.error('toast failed: ' + (e instanceof Error ? e.message : String(e)));
                  }
                })
              Text(formatTokensUi(r.inputTokens)).fontSize(11).layoutWeight(1).textAlign(TextAlign.End).fontColor($r('app.color.text_secondary'))
              Text(formatTokensUi(r.outputTokens)).fontSize(11).layoutWeight(1).textAlign(TextAlign.End).fontColor($r('app.color.text_secondary'))
              Text(formatCost(r.costUsd, this.currency, this.usdCny)).fontSize(11).layoutWeight(1).textAlign(TextAlign.End).fontColor($r('app.color.text_secondary'))
            }
            .width('100%')
            .padding({ top: 4, bottom: 4 })
          }, (r: RecordRow) => `${r.usgId}-${this.dataVersion}`)
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
    // HDS 沉浸光感标题栏（对齐参考项目）：内容滚入栏下触发渐变模糊，材质档位跟随「沉浸光感」设置
    HdsNavigation() {
      HdsNavDestination() {
        Scroll(this.scroller) {
          Column({ space: 12 }) {
            // 周期筛选置于内容顶部：滚动时与内容一同滚入标题栏，直观体现沉浸渐变模糊
            Row() {
              this.RangePills()
            }
            .width('100%')

            this.SessionsCard()
            this.RecordsCard()
          }
          .width('100%')
          .constraintSize({ minHeight: '100%' })
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
      .titleBar(buildTitleBar($r('app.string.records_page'), this.glowLevel))
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

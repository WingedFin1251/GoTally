// entry/src/main/ets/pages/RecordsPage.ets
import { RecordsViewModel } from './RecordsViewModel';
import { Pager } from '../components/ui/Pager';
import { RangeSegmented } from '../components/ui/RangeSegmented';
import { ModelIconView } from '../components/ui/ModelIconView';
import { formatTokensUi, formatCost } from '../common/utils/Formatter';
import { formatDateTimeShort, parseIso } from '../common/utils/TimeUtil';
import { SettingsStore } from '../data/SettingsStore';
import { OpenCodeApi } from '../network/OpenCodeApi';
import { Constants } from '../common/constants/Constants';
import { ThemeUtil } from '../common/utils/ThemeUtil';
import type { SessionStat, RecordRow, ModelStat } from '../model/Stats';
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
  /** 是否已登录：未登录即免登录模式，列表无数据，给出来源提示。 */
  @StorageProp('hasToken') hasToken: boolean = false;
  /** 当前登录方式是否无法读取逐条明细（新控制台会话登录）：给出说明而非空列表。 */
  @StorageProp('recordsUnavailable') recordsUnavailable: boolean = false;
  /** 页面滚动控制器：绑定给 HDS 标题栏，驱动「内容滚入栏下渐变模糊」。 */
  private scroller: Scroller = new Scroller();
  @Watch('onSyncFinished') @StorageProp('syncFinishedVersion') syncFinishedVersion: number = 0;
  /** 模型汇总卡的筛选模型（'' = 全部模型；与「使用记录」的筛选互相独立）。 */
  @State summaryModel: string = '';
  /** 主题模式与系统深色状态（跟随系统时随系统变化，驱动图标浅/深两套切换）。 */
  @StorageProp('themeMode') themeMode: string = ThemeUtil.MODE_SYSTEM;
  @StorageProp('systemDark') systemDark: boolean = true;
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
      // 模型维度聚合（控制台登录下这是官方能给的最细粒度）
      await this.vm.loadModelStats();
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

  /** 切换周期：更新 VM 周期并重新加载。 */
  private onPickPeriod(period: string): void {
    if (this.vm.period === period) {
      return;
    }
    this.vm.setPeriod(period);
    this.reload();
  }

  /** 实际是否深色（跟随系统时取系统状态）——决定模型图标用浅色还是深色那一套。 */
  private isDarkNow(): boolean {
    return ThemeUtil.resolveDark(this.themeMode, this.systemDark);
  }

  /** 模型汇总卡：模型名 + 费用（含占比）/ 请求数 / 缓存读 / 输入·输出。 */
  private filteredModelStats(): ModelStat[] {
    if (this.summaryModel === '') {
      return this.vm.modelStats;
    }
    const out: ModelStat[] = [];
    for (const m of this.vm.modelStats) {
      if (m.model === this.summaryModel) {
        out.push(m);
      }
    }
    return out;
  }

  /** 模型名列表（汇总卡筛选用，顺序与 modelStats 一致）。 */
  private modelNames(): string[] {
    const out: string[] = [];
    for (const m of this.vm.modelStats) {
      out.push(m.model);
    }
    return out;
  }

  private summaryOptions(): SelectOption[] {
    const out: SelectOption[] = [{ value: $r('app.string.all_models') }];
    for (const n of this.modelNames()) {
      out.push({ value: n });
    }
    return out;
  }

  private summarySelectIndex(): number {
    const idx = this.modelNames().indexOf(this.summaryModel);
    return idx >= 0 ? idx + 1 : 0;
  }

  /** 当前筛选下的费用合计（未筛选时即所选周期的全部额度）。 */
  private summaryTotalCost(): number {
    let sum = 0;
    for (const m of this.filteredModelStats()) {
      sum += m.totalCostUsd;
    }
    return sum;
  }

  /** 该模型占当前合计的比例（用于费用行后缀）。 */
  private costShare(m: ModelStat): string {
    const total = this.summaryTotalCost();
    if (total <= 0) {
      return '';
    }
    const pct = (m.totalCostUsd / total) * 100;
    return ` · ${pct.toFixed(1)}%`;
  }

  /** 模型卡次行左侧：N 次请求 · 缓存读 X。 */
  private modelMeta(m: ModelStat): string {
    const req = this.str($r('app.string.requests_count').id, `${m.requestCount}`);
    const cr = this.res($r('app.string.cache_read').id);
    return `${req} · ${cr} ${formatTokensUi(m.cacheHitTokens)}`;
  }

  /**
   * 模型汇总卡：按模型看「总共用了多少额度」（费用/请求数/缓存读/输入输出），
   * 数据源为本地历史「天×模型」明细或官方 `/usage/models`，随顶部周期联动；
   * 卡内筛选与下方「使用记录」的筛选互相独立。
   */
  @Builder
  ModelUsageCard() {
    Column({ space: 8 }) {
      Row() {
        Text($r('app.string.model_summary')).fontSize(15).fontWeight(FontWeight.Bold)
        Blank()
        Select(this.summaryOptions())
          .selected(this.summarySelectIndex())
          .value(this.summaryModel === '' ? $r('app.string.all_models') : this.summaryModel)
          .font({ size: 12 })
          .width(140)
          .onSelect((index: number) => {
            this.summaryModel = index === 0 ? '' : this.modelNames()[index - 1];
          })
      }
      .width('100%')

      // 合计行：N 个模型的总额度（选择单个模型时即该模型总额）
      Row() {
        Text(this.str($r('app.string.models_total').id, `${this.filteredModelStats().length}`))
          .fontSize(11)
          .fontColor($r('app.color.text_muted'))
        Blank()
        Text(formatCost(this.summaryTotalCost(), this.currency, this.usdCny))
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.accent'))
      }
      .width('100%')
      .padding({ bottom: 6 })
      .border({ width: { bottom: 1 }, color: $r('app.color.divider') })

      if (this.filteredModelStats().length === 0) {
        Text($r('app.string.list_empty_hint'))
          .fontSize(12)
          .fontColor($r('app.color.text_muted'))
          .width('100%')
          .textAlign(TextAlign.Center)
          .padding({ top: 14, bottom: 14 })
      } else {
        ForEach(this.filteredModelStats(), (m: ModelStat) => {
            Column({ space: 3 }) {
              Row() {
                ModelIconView({ model: m.model, iconSize: 16, dark: this.isDarkNow() })
                  .margin({ right: 6 })
                Text(m.model)
                  .fontSize(13)
                  .fontColor($r('app.color.text_primary'))
                  .layoutWeight(1)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .onClick(() => { this.toast(m.model); })
                Text(formatCost(m.totalCostUsd, this.currency, this.usdCny) + this.costShare(m))
                .fontSize(13)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.accent'))
                .margin({ left: 8 })
            }
            .width('100%')

            Row() {
              Text(this.modelMeta(m))
                .fontSize(11)
                .fontColor($r('app.color.text_muted'))
                .layoutWeight(1)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
              Text(this.tokensTextOf(m.totalInputTokens, m.totalOutputTokens))
                .fontSize(11)
                .fontColor($r('app.color.text_secondary'))
                .margin({ left: 8 })
            }
            .width('100%')
          }
          .width('100%')
          .padding({ top: 7, bottom: 7 })
          .border({ width: { bottom: 1 }, color: $r('app.color.divider') })
        }, (m: ModelStat) => `${m.model}-${this.dataVersion}`)
      }
    }
    .width('100%')
    .padding(12)
    .borderRadius(12)
    .backgroundColor($r('app.color.bg_card'))
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
        if (this.vm.sessions.length === 0) {
          Text($r('app.string.list_empty_hint'))
            .fontSize(12)
            .fontColor($r('app.color.text_muted'))
            .width('100%')
            .textAlign(TextAlign.Center)
            .padding({ top: 14, bottom: 14 })
        } else {
          ForEach(this.vm.sessions, (s: SessionStat) => {
            // 与会话用量同款两行排布：首行 = 会话 + 成本；次行 = Key·请求数 + 输入/输出
            Column({ space: 3 }) {
              Row() {
                Text(this.shortSession(s.sessionId))
                  .fontSize(13)
                  .fontColor($r('app.color.text_primary'))
                  .layoutWeight(1)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .onClick(() => { this.toast(s.sessionId === '' ? '未归属' : s.sessionId); })
                Text(formatCost(s.totalCostUsd, this.currency, this.usdCny))
                  .fontSize(13)
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('app.color.accent'))
                  .margin({ left: 8 })
              }
              .width('100%')

              Row() {
                Text(this.sessionMeta(s))
                  .fontSize(11)
                  .fontColor($r('app.color.text_muted'))
                  .layoutWeight(1)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                Text(this.tokensTextOf(s.totalInputTokens, s.totalOutputTokens))
                  .fontSize(11)
                  .fontColor($r('app.color.text_secondary'))
                  .margin({ left: 8 })
              }
              .width('100%')
            }
            .width('100%')
            .padding({ top: 7, bottom: 7 })
            .border({ width: { bottom: 1 }, color: $r('app.color.divider') })
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

  /** 会话列显示：无 session 的记录按 Key 拆分行，显示「未归属 · key尾号」。 */
  private shortSession(id: string): string {
    if (id === '') { return '未归属'; }
    if (id.startsWith('key_')) { return `未归属 · …${id.substring(Math.max(0, id.length - 6))}`; }
    return id.length > 12 ? `…${id.substring(id.length - 12)}` : id;
  }

  /** Key 列显示：优先显示名称，取不到时退回 key 尾号，完全无归属显示「—」。 */
  private keyLabel(name: string, keyId: string): string {
    if (name !== '') { return name; }
    if (keyId !== '') { return `…${keyId.substring(Math.max(0, keyId.length - 6))}`; }
    return '—';
  }

  /** 记录次行左侧：Key 名称 · 时间。 */
  private recordMeta(r: RecordRow): string {
    const key = this.keyLabel(r.keyName, r.keyId);
    const t = this.timeText(r);
    return key === '—' ? t : `${key} · ${t}`;
  }

  /** 会话次行左侧：Key 名称 · N 次请求 · 最后使用时间（对齐上游会话表的「最后使用」列）。 */
  private sessionMeta(s: SessionStat): string {
    const key = this.keyLabel(s.keyName, s.keyId);
    const req = this.str($r('app.string.requests_count').id, `${s.requestCount}`);
    const base = key === '—' ? req : `${key} · ${req}`;
    const last = this.lastUsedText(s.lastAt);
    return last === '' ? base : `${base} · ${this.str($r('app.string.last_used_short').id, last)}`;
  }

  /** 会话最后使用时间（短格式；解析失败时原样回显，空值返回空串）。 */
  private lastUsedText(iso: string): string {
    if (iso === '') {
      return '';
    }
    const ms = parseIso(iso);
    return ms > 0 ? formatDateTimeShort(ms) : iso;
  }

  /** 记录次行右侧：输入 / 输出 Token。 */
  private tokensText(r: RecordRow): string {
    return this.tokensTextOf(r.inputTokens, r.outputTokens);
  }

  /** 次行右侧文本：输入 / 输出 Token（带本地化标签，避免只用箭头产生歧义）。 */
  private tokensTextOf(input: number, output: number): string {
    const inLabel = this.res($r('app.string.input').id);
    const outLabel = this.res($r('app.string.output').id);
    return `${inLabel} ${formatTokensUi(input)} · ${outLabel} ${formatTokensUi(output)}`;
  }

  /** 取字符串资源文本（无占位符场景）。 */
  private res(id: number): string {
    return this.str(id, '');
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

  private toast(msg: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: msg });
    } catch (e) {
      console.error('toast failed: ' + (e instanceof Error ? e.message : String(e)));
    }
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
        if (this.vm.records.length === 0) {
          Text($r('app.string.list_empty_hint'))
            .fontSize(12)
            .fontColor($r('app.color.text_muted'))
            .width('100%')
            .textAlign(TextAlign.Center)
            .padding({ top: 14, bottom: 14 })
        } else {
          ForEach(this.vm.records, (r: RecordRow) => {
            // 两行式排布（移动端窄屏更易读）：
            // 首行 = 主信息（模型名占满 + 费用强调）；次行 = 次要信息（Key·时间 + 输入/输出）
            Column({ space: 3 }) {
              Row() {
                // 模型图标：品牌 SVG，未知模型显示首字母徽章
                ModelIconView({ model: r.model, iconSize: 16, dark: this.isDarkNow() })
                  .margin({ right: 6 })
                Text(r.model)
                  .fontSize(13)
                  .fontColor($r('app.color.text_primary'))
                  .layoutWeight(1)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .onClick(() => { this.toast(r.model); })
                Text(formatCost(r.costUsd, this.currency, this.usdCny))
                  .fontSize(13)
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('app.color.accent'))
                  .margin({ left: 8 })
              }
              .width('100%')

              Row() {
                Text(this.recordMeta(r))
                  .fontSize(11)
                  .fontColor($r('app.color.text_muted'))
                  .layoutWeight(1)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .onClick(() => { this.toast(r.createdAt === '' ? '--' : r.createdAt); })
                Text(this.tokensText(r))
                  .fontSize(11)
                  .fontColor($r('app.color.text_secondary'))
                  .margin({ left: 8 })
              }
              .width('100%')
            }
            .width('100%')
            .padding({ top: 7, bottom: 7 })
            .border({ width: { bottom: 1 }, color: $r('app.color.divider') })
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
            // 周期筛选（官方胶囊分段控件，滑块式指示）置于内容顶部
            RangeSegmented({
              current: this.vm.period,
              onPick: (p: string) => { this.onPickPeriod(p); },
            })
              .width('100%')

            // 免登录模式提示：记录需登录后同步
            if (!this.hasToken) {
              Text($r('app.string.guest_records_hint'))
                .fontSize(11)
                .fontColor($r('app.color.text_secondary'))
                .width('100%')
                .padding(10)
                .borderRadius(10)
                .backgroundColor($r('app.color.divider'))
            } else if (this.recordsUnavailable) {
              // 官方已更换鉴权与接口：新登录方式拿不到逐条明细（总览/统计仍由官方聚合接口提供）
              Text($r('app.string.records_unavailable'))
                .fontSize(11)
                .fontColor($r('app.color.text_secondary'))
                .width('100%')
                .padding(10)
                .borderRadius(10)
                .backgroundColor($r('app.color.divider'))
            }

            // 模型汇总：一眼看出每个模型总共用了多少额度（与下方「使用记录」的筛选互相独立）
            this.ModelUsageCard()
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



// entry/src/main/ets/pages/SettingsPage.ets
import { SettingsStore } from '../data/SettingsStore';
import type { AppSettings } from '../data/SettingsStore';
import { DataProvider } from '../data/DataProvider';
import type { SyncProgress } from '../network/SyncManager';
import type { SyncState } from '../model/UsageRecord';
import { SettingRow } from '../components/ui/SettingRow';
import { SettingsCard } from '../components/ui/SettingsCard';
import { formatDateTime, parseIso } from '../common/utils/TimeUtil';
import { Constants } from '../common/constants/Constants';
import { ConfigurationConstant, common } from '@kit.AbilityKit';
import { pasteboard } from '@kit.BasicServicesKit';
import { setLanguage } from '../common/utils/Locale';
import { AppInfo } from '../common/utils/AppInfo';
import { Updater } from '../common/utils/Updater';
import { HdsNavigation, HdsNavDestination } from '@kit.UIDesignKit';
import { buildTitleBar } from '../common/utils/NavTitleBar';

interface PillOption {
  value: string;
  label: ResourceStr;
}

@Component
export struct SettingsPage {
  @State settings: AppSettings = {
    syncIntervalSec: 300, windowDays: 60, autoSync: true, theme: 'light', currency: 'CNY', language: 'zh', glowLevel: 1,
  };
  @State loggedIn: boolean = false;
  @State workspace: string = '';
  @State syncState: SyncState = { lastSyncAt: '', lastSyncStatus: '', lastSyncError: '', lastInsertedCount: 0, deepestPageFetched: -1, totalRecords: 0, oldestRecordAt: '', newestRecordAt: '' };
  @State syncing: boolean = false;
  @State syncProgressMsg: string = '';
  /** 应用版本号（读取 bundle 信息，单一来源，避免多处硬编码不一致）。 */
  @State appVersion: string = '';
  @State checkingUpdate: boolean = false;
  /** 上一次 onProgress 上报的阶段，用于捕捉 done/error 完成时刻（仅触发一次 toast/刷新）。 */
  private lastPhase: string = 'idle';
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
  @StorageProp('statusBarHeight') statusBarHeight: number = 0;
  @StorageProp('navIndicatorHeight') navIndicatorHeight: number = 0;
  /** 沉浸光感档位：响应式依赖，改设置后标题栏材质即时更新。 */
  @StorageProp('glowLevel') glowLevel: number = 1;
  /** 页面滚动控制器：绑定给 HDS 标题栏，驱动「内容滚入栏下渐变模糊」。 */
  private scroller: Scroller = new Scroller();

  aboutToAppear(): void {
    this.load();
    this.loadVersion();
    const mgr = DataProvider.getSyncManager();
    // 以当前阶段为基线，避免进入页面时把旧消息误当作新完成事件
    this.lastPhase = mgr.getProgress().phase;
    mgr.onProgress = (p: SyncProgress) => {
      this.syncing = p.running;
      this.syncProgressMsg = p.message;
      if (p.phase !== this.lastPhase) {
        this.lastPhase = p.phase;
        if (p.phase === 'done' || p.phase === 'error') {
          this.onSyncFinished(p);
        }
      }
    };
  }

  aboutToDisappear(): void {
    DataProvider.getSyncManager().onProgress = () => {};
  }

  private async load(): Promise<void> {
    this.settings = await SettingsStore.getAll();
    const token = await DataProvider.getStore().getToken();
    this.loggedIn = token.trim() !== '';
    this.workspace = await DataProvider.getStore().getWorkspaceHint();
    this.syncState = await DataProvider.getStore().getSyncState();
  }

  /** 同步完成/失败收尾：刷新同步状态并弹提示，页面无需重启即可看到最新「最近同步 / 记录总数」。 */
  private async onSyncFinished(p: SyncProgress): Promise<void> {
    this.syncProgressMsg = '';
    try {
      this.syncState = await DataProvider.getStore().getSyncState();
    } catch (e) {
      console.error('reload syncState failed: ' + (e instanceof Error ? e.message : String(e)));
    }
    let msg: string = '';
    try {
      const ctx = this.getUIContext().getHostContext();
      if (ctx !== undefined) {
        const rm = ctx.resourceManager;
        if (p.phase === 'done') {
          const tpl = rm.getStringSync($r('app.string.sync_done').id);
          msg = tpl.split('{0}').join(`${p.inserted}`);
        } else {
          const base = rm.getStringSync($r('app.string.sync_error').id);
          msg = p.message !== '' ? `${base}: ${p.message}` : base;
        }
      }
    } catch (e) {
      msg = p.phase === 'done' ? `同步完成，新增 ${p.inserted} 条` : '同步失败';
    }
    this.showToastSafe(msg);
  }

  /** 当前设置项选中值（Builder 内部读 this.settings，随状态变化刷新选中态）。 */
  private settingCurrent(key: string): string {
    if (key === 'syncIntervalSec') { return `${this.settings.syncIntervalSec}`; }
    if (key === 'windowDays') { return this.settings.windowDays === null ? 'all' : `${this.settings.windowDays}`; }
    if (key === 'theme') { return this.settings.theme; }
    if (key === 'currency') { return this.settings.currency; }
    if (key === 'glowLevel') { return `${this.settings.glowLevel}`; }
    return this.settings.language;
  }

  @Builder
  PillRow(key: string, options: PillOption[], onPick: (v: string) => void) {
    Row({ space: 6 }) {
      ForEach(options, (opt: PillOption) => {
        Text(opt.label)
          .fontSize(11)
          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
          .borderRadius(10)
          .backgroundColor(this.settingCurrent(key) === opt.value ? $r('app.color.accent') : $r('app.color.divider'))
          .fontColor(this.settingCurrent(key) === opt.value ? Color.White : $r('app.color.text_secondary'))
          .onClick(() => onPick(opt.value))
      }, (opt: PillOption) => opt.value)
    }
  }

  build() {
    // HDS 沉浸光感标题栏（对齐参考项目）：内容滚入栏下触发渐变模糊，材质档位跟随「沉浸光感」设置
    HdsNavigation() {
      HdsNavDestination() {
        Stack({ alignContent: Alignment.Top }) {
      // 滚动内容：可滚到固定标题栏下方（标题栏模糊蒙版保证可读性）
          Scroll(this.scroller) {
        Column({ space: 12 }) {
          // 账户
        SettingsCard({ title: $r('app.string.set_account') }) {
          SettingRow({ title: $r('app.string.set_login_state'), desc: this.loggedIn ? $r('app.string.logged_in') : $r('app.string.not_logged_in') }) {}
          SettingRow({ title: $r('app.string.set_workspace'), desc: this.workspace }) {
            Button('复制').fontSize(12).height(30).onClick(() => {
              this.copyWorkspace();
            })
          }
          SettingRow({ title: $r('app.string.set_login_method'), desc: $r('app.string.login_method_desc') }) {
            Button($r('app.string.relogin')).fontSize(12).height(30).onClick(() => {
              this.getUIContext().getRouter().pushUrl({ url: 'pages/Login' });
            })
          }
          SettingRow({ title: $r('app.string.logout'), desc: $r('app.string.logout_desc') }) {
            Button($r('app.string.logout')).fontSize(12).height(30).backgroundColor($r('app.color.danger'))
              .onClick(() => this.confirmLogout())
          }
        }

        // 自动同步
        SettingsCard({ title: $r('app.string.set_auto_sync') }) {
          SettingRow({ title: $r('app.string.auto_sync'), desc: $r('app.string.auto_sync_desc') }) {
            Toggle({ type: ToggleType.Switch, isOn: this.settings.autoSync })
              .onChange((v: boolean) => {
                this.settings.autoSync = v;
                SettingsStore.save(this.settings);
                AppStorage.setOrCreate('autoSyncChanged', (AppStorage.get('autoSyncChanged') as number ?? 0) + 1);
              })
          }
          SettingRow({ title: $r('app.string.sync_interval'), desc: $r('app.string.sync_interval_desc') }) {
            this.PillRow(
              'syncIntervalSec',
              [
                { value: '60', label: $r('app.string.min_1') },
                { value: '300', label: $r('app.string.min_5') },
                { value: '900', label: $r('app.string.min_15') },
                { value: '1800', label: $r('app.string.min_30') },
              ],
              (v: string) => { this.settings.syncIntervalSec = Number(v); SettingsStore.save(this.settings); AppStorage.setOrCreate('autoSyncChanged', (AppStorage.get('autoSyncChanged') as number ?? 0) + 1); })
          }
          SettingRow({ title: $r('app.string.sync_range'), desc: $r('app.string.sync_range_desc') }) {
            this.PillRow(
              'windowDays',
              [
                { value: '30', label: $r('app.string.days_30short') },
                { value: '60', label: $r('app.string.days_60') },
                { value: '90', label: $r('app.string.days_90') },
                { value: '180', label: $r('app.string.days_180') },
                { value: 'all', label: $r('app.string.all') },
              ],
              (v: string) => { this.settings.windowDays = v === 'all' ? null : Number(v); SettingsStore.save(this.settings); AppStorage.setOrCreate('autoSyncChanged', (AppStorage.get('autoSyncChanged') as number ?? 0) + 1); })
          }
          SettingRow({ title: $r('app.string.full_sync'), desc: this.syncProgressMsg !== '' ? this.syncProgressMsg : $r('app.string.full_sync_desc') }) {
            Button(this.syncing ? $r('app.string.syncing') : $r('app.string.start_full_sync'))
              .fontSize(12).height(30)
              .enabled(!this.syncing)
              .onClick(() => { DataProvider.getSyncManager().sync('full'); })
          }
        }

        // 外观
        SettingsCard({ title: $r('app.string.set_appearance') }) {
          SettingRow({ title: $r('app.string.theme'), desc: $r('app.string.theme_desc') }) {
            this.PillRow(
              'theme',
              [{ value: 'light', label: $r('app.string.light') }, { value: 'dark', label: $r('app.string.dark') }],
              (v: string) => { this.settings.theme = v; SettingsStore.save(this.settings); this.applyTheme(v); })
          }
          SettingRow({ title: $r('app.string.currency'), desc: $r('app.string.currency_desc') }) {
            this.PillRow(
              'currency',
              [{ value: 'CNY', label: '¥ CNY' }, { value: 'USD', label: '$ USD' }],
              (v: string) => {
                this.settings.currency = v;
                SettingsStore.save(this.settings);
                // 同步到 AppStorage，首页/统计/记录页费用立即切换货币
                AppStorage.setOrCreate('currency', v);
              })
          }
          SettingRow({ title: $r('app.string.language'), desc: $r('app.string.language_desc') }) {
            this.PillRow(
              'language',
              [{ value: 'zh', label: '中文' }, { value: 'en', label: 'English' }],
              (v: string) => {
                this.settings.language = v;
                SettingsStore.save(this.settings);
                setLanguage(v);
                // 应用级语言切换，界面文案立即生效
                try {
                  const lctx = this.getUIContext().getHostContext();
                  if (lctx !== undefined) {
                    lctx.getApplicationContext()
                      .setLanguage(v === 'zh' ? 'zh-CN' : 'en-US');
                  }
                } catch (e) {
                  console.error('setLanguage failed: ' + (e instanceof Error ? e.message : String(e)));
                }
                this.showToastSafe(v === 'zh' ? '已切换为中文' : 'Switched to English');
              })
          }

          // 沉浸光感：三档映射 HDS 系统材质等级（GENTLE/ADAPTIVE/EXQUISITE），即时作用于底部悬浮导航栏
          SettingRow({ title: $r('app.string.glow'), desc: $r('app.string.glow_desc') }) {
            this.PillRow(
              'glowLevel',
              [
                { value: '0', label: $r('app.string.glow_weak') },
                { value: '1', label: $r('app.string.glow_medium') },
                { value: '2', label: $r('app.string.glow_strong') },
              ],
              (v: string) => {
                const lv = Number(v);
                this.settings.glowLevel = lv;
                SettingsStore.save(this.settings);
                AppStorage.setOrCreate('glowLevel', lv);
              })
          }
        }

        // 数据
        SettingsCard({ title: $r('app.string.set_data') }) {
          SettingRow({ title: $r('app.string.data_dir'), desc: Constants.DB_NAME }) {}
          SettingRow({ title: $r('app.string.sync_info'), desc: this.syncInfoDesc() }) {}
        }

        // 更新
        SettingsCard({ title: $r('app.string.set_update') }) {
          SettingRow({ title: $r('app.string.current_version'), desc: this.appVersion !== '' ? this.appVersion : '—' }) {}
          SettingRow({ title: $r('app.string.check_update'), desc: $r('app.string.check_update_desc') }) {
            Button($r('app.string.check_update_btn')).fontSize(12).height(30).enabled(!this.checkingUpdate)
              .onClick(() => { this.checkUpdate(); })
          }
        }
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
  .width('100%')
  .height('100%')
      }
      .titleBar(buildTitleBar($r('app.string.settings_title'), this.glowLevel))
      .hideBackButton(true)
      .bindToScrollable([this.scroller])
    }
    .mode(NavigationMode.Stack)
    .hideTitleBar(true)
    .hideToolBar(true)
    .width('100%')
    .height('100%')
}

  private async copyWorkspace(): Promise<void> {
    if (this.workspace === '') {
      return;
    }
    const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, this.workspace);
    try {
      await pasteboard.getSystemPasteboard().setData(data);
      this.showToastSafe('已复制');
    } catch (e) {
      this.showToastSafe('复制失败');
    }
  }

  private showToastSafe(msg: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: msg });
    } catch (e) {
      console.error('toast failed: ' + (e instanceof Error ? e.message : String(e)));
    }
  }

  /** 读取应用版本号（单一来源：bundle 信息）。 */
  private async loadVersion(): Promise<void> {
    this.appVersion = await AppInfo.versionName();
  }

  /** 取字符串资源并按 {0} 替换参数（个别版本 getStringSync 不执行占位符格式化，故手动替换）。 */
  private str(resId: number, arg: string): string {
    try {
      const ctx = this.getUIContext().getHostContext();
      if (ctx === undefined) {
        return '';
      }
      const tpl = ctx.resourceManager.getStringSync(resId);
      return arg === '' ? tpl : tpl.split('{0}').join(arg);
    } catch (e) {
      console.error('str failed: ' + (e instanceof Error ? e.message : String(e)));
      return '';
    }
  }

  /**
   * 检查更新（对齐上游 v1.0.2）：API 优先并自动重试，失败降级 Releases Atom 流；
   * 结果分三种呈现：发现新版本（可前往下载）/ 已是最新 / 检查失败（含原因）。
   */
  private async checkUpdate(): Promise<void> {
    if (this.checkingUpdate) {
      return;
    }
    this.checkingUpdate = true;
    this.showToastSafe(this.str($r('app.string.update_checking').id, ''));
    const r = await Updater.check();
    this.checkingUpdate = false;
    if (!r.ok) {
      this.showInfoDialog(this.str($r('app.string.update_failed').id, ''), r.error);
      return;
    }
    if (!r.hasUpdate) {
      this.showToastSafe(this.str($r('app.string.update_none').id, r.current));
      return;
    }
    const title = this.str($r('app.string.update_found').id, r.latest);
    const notes = r.notes !== '' ? r.notes : this.str($r('app.string.update_no_notes').id, '');
    this.showDownloadDialog(title, notes, r.releaseUrl);
  }

  /** 单按钮提示弹窗（检查失败等）。 */
  private showInfoDialog(title: string, message: string): void {
    try {
      this.getUIContext().showAlertDialog({
        title: title,
        message: message,
        primaryButton: { value: $r('app.string.ok'), action: () => {} },
      });
    } catch (e) {
      console.error('dialog failed: ' + (e instanceof Error ? e.message : String(e)));
    }
  }

  /** 发现新版本弹窗：稍后 / 前往下载（打开该 Release 页）。 */
  private showDownloadDialog(title: string, message: string, url: string): void {
    try {
      this.getUIContext().showAlertDialog({
        title: title,
        message: message,
        primaryButton: { value: $r('app.string.update_later'), action: () => {} },
        secondaryButton: {
          value: $r('app.string.update_download'),
          action: () => {
            const lctx = this.getUIContext().getHostContext();
            if (lctx !== undefined) {
              (lctx as common.UIAbilityContext).openLink(url);
            }
          },
        },
      });
    } catch (e) {
      console.error('dialog failed: ' + (e instanceof Error ? e.message : String(e)));
    }
  }

  private syncInfoDesc(): string {
    const last = this.syncState.lastSyncAt !== '' ? formatDateTime(parseIso(this.syncState.lastSyncAt)) : '从未';
    return `最近: ${last} · 总数: ${this.syncState.totalRecords}`;
  }

  private confirmLogout(): void {
    try {
      this.getUIContext().showAlertDialog({
        title: $r('app.string.confirm_title'),
        message: $r('app.string.logout_confirm_msg'),
        primaryButton: {
          value: $r('app.string.cancel'), action: () => {},
        },
        secondaryButton: {
          value: $r('app.string.ok'), action: async () => {
            await DataProvider.getStore().clearAccount();
            AppStorage.setOrCreate('logoutVersion', (AppStorage.get('logoutVersion') as number ?? 0) + 1);
            this.load();
          },
        },
      });
    } catch (e) {
      console.error('alert failed: ' + (e instanceof Error ? e.message : String(e)));
    }
  }

  private applyTheme(mode: string): void {
    const colorMode = mode === 'dark'
      ? ConfigurationConstant.ColorMode.COLOR_MODE_DARK
      : ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT;
    try {
      const ctx = this.getUIContext().getHostContext();
      if (ctx !== undefined) {
        ctx.getApplicationContext().setColorMode(colorMode);
      }
    } catch (e) {
      console.error('applyTheme failed: ' + (e instanceof Error ? e.message : String(e)));
    }
  }
}

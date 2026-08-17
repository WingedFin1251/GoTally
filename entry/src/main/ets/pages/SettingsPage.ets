// entry/src/main/ets/pages/SettingsPage.ets
import { router, promptAction } from '@kit.ArkUI';
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

interface PillOption {
  value: string;
  label: ResourceStr;
}

@Component
export struct SettingsPage {
  @State settings: AppSettings = {
    syncIntervalSec: 300, windowDays: 60, autoSync: true, theme: 'light', currency: 'CNY', language: 'zh',
  };
  @State loggedIn: boolean = false;
  @State workspace: string = '';
  @State syncState: SyncState = { lastSyncAt: '', lastSyncStatus: '', lastSyncError: '', lastInsertedCount: 0, deepestPageFetched: -1, totalRecords: 0, oldestRecordAt: '', newestRecordAt: '' };
  @State syncing: boolean = false;
  @State syncProgressMsg: string = '';
  @StorageProp('statusBarHeight') statusBarHeight: number = 0;
  @StorageProp('navIndicatorHeight') navIndicatorHeight: number = 0;

  aboutToAppear(): void {
    this.load();
    const mgr = DataProvider.getSyncManager();
    mgr.onProgress = (p: SyncProgress) => {
      this.syncing = p.running;
      this.syncProgressMsg = p.message;
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

  /** 当前设置项选中值（Builder 内部读 this.settings，随状态变化刷新选中态）。 */
  private settingCurrent(key: string): string {
    if (key === 'syncIntervalSec') { return `${this.settings.syncIntervalSec}`; }
    if (key === 'windowDays') { return this.settings.windowDays === null ? 'all' : `${this.settings.windowDays}`; }
    if (key === 'theme') { return this.settings.theme; }
    if (key === 'currency') { return this.settings.currency; }
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
    Stack({ alignContent: Alignment.Top }) {
      // 滚动内容：可滚到固定标题栏下方（标题栏模糊蒙版保证可读性）
      Scroll() {
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
              router.pushUrl({ url: 'pages/Login' });
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
              (v: string) => { this.settings.currency = v; SettingsStore.save(this.settings); })
          }
          SettingRow({ title: $r('app.string.language'), desc: $r('app.string.language_desc') }) {
            this.PillRow(
              'language',
              [{ value: 'zh', label: '中文' }, { value: 'en', label: 'English' }],
              (v: string) => { this.settings.language = v; SettingsStore.save(this.settings); setLanguage(v); promptAction.showToast({ message: '重启后生效' }); })
          }
        }

        // 数据
        SettingsCard({ title: $r('app.string.set_data') }) {
          SettingRow({ title: $r('app.string.data_dir'), desc: Constants.DB_NAME }) {}
          SettingRow({ title: $r('app.string.sync_info'), desc: this.syncInfoDesc() }) {}
        }

        // 更新
        SettingsCard({ title: $r('app.string.set_update') }) {
          SettingRow({ title: $r('app.string.current_version'), desc: '1.0.0' }) {}
          SettingRow({ title: $r('app.string.check_update'), desc: $r('app.string.check_update_desc') }) {
            Button($r('app.string.check_update_btn')).fontSize(12).height(30).onClick(() => {
              (getContext(this) as common.UIAbilityContext).openLink('https://github.com/yphyphyph/opencode-go-gauge/releases');
            })
          }
        }
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
        Text($r('app.string.settings_title')).fontSize(18).fontWeight(FontWeight.Bold)
        Blank()
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

  private async copyWorkspace(): Promise<void> {
    if (this.workspace === '') {
      return;
    }
    const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, this.workspace);
    try {
      await pasteboard.getSystemPasteboard().setData(data);
      promptAction.showToast({ message: '已复制' });
    } catch (e) {
      promptAction.showToast({ message: '复制失败' });
    }
  }

  private syncInfoDesc(): string {
    const last = this.syncState.lastSyncAt !== '' ? formatDateTime(parseIso(this.syncState.lastSyncAt)) : '从未';
    return `最近: ${last} · 总数: ${this.syncState.totalRecords}`;
  }

  private confirmLogout(): void {
    AlertDialog.show({
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
  }

  private applyTheme(mode: string): void {
    const ctx = getContext(this);
    const colorMode = mode === 'dark'
      ? ConfigurationConstant.ColorMode.COLOR_MODE_DARK
      : ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT;
    ctx.getApplicationContext().setColorMode(colorMode);
  }
}

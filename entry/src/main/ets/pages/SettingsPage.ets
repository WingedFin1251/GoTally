// entry/src/main/ets/pages/SettingsPage.ets
import { router, promptAction } from '@kit.ArkUI';
import { SettingsStore } from '../data/SettingsStore';
import type { AppSettings } from '../data/SettingsStore';
import { DataProvider } from '../data/DataProvider';
import type { SyncProgress } from '../network/SyncManager';
import type { SyncState } from '../model/UsageRecord';
import { SettingRow } from '../components/ui/SettingRow';
import { formatDateTime, parseIso } from '../common/utils/TimeUtil';
import { Constants } from '../common/constants/Constants';
import { ConfigurationConstant, common } from '@kit.AbilityKit';

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

  @Builder
  Card(title: Resource, children: () => void) {
    Column({ space: 2 }) {
      Text(title).fontSize(15).fontWeight(FontWeight.Bold).width('100%')
      children()
    }
    .width('100%')
    .padding(12)
    .borderRadius(12)
    .backgroundColor($r('app.color.bg_card'))
  }

  @Builder
  PillRow(options: PillOption[], current: string, onPick: (v: string) => void) {
    Row({ space: 6 }) {
      ForEach(options, (opt: PillOption) => {
        Text(opt.label)
          .fontSize(11)
          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
          .borderRadius(10)
          .backgroundColor(current === opt.value ? $r('app.color.accent') : $r('app.color.divider'))
          .fontColor(current === opt.value ? Color.White : $r('app.color.text_secondary'))
          .onClick(() => onPick(opt.value))
      }, (opt: PillOption) => opt.value)
    }
  }

  build() {
    Scroll() {
      Column({ space: 12 }) {
        Row() {
          Text($r('app.string.settings_title')).fontSize(18).fontWeight(FontWeight.Bold)
          Blank()
        }
        .width('100%')

        // 账户
        this.Card($r('app.string.set_account'), () => {
          SettingRow({ title: $r('app.string.set_login_state'), desc: this.loggedIn ? $r('app.string.logged_in') : $r('app.string.not_logged_in') }) {}
          SettingRow({ title: $r('app.string.set_workspace'), desc: this.workspace }) {}
          SettingRow({ title: $r('app.string.set_login_method'), desc: $r('app.string.login_method_desc') }) {
            Button($r('app.string.relogin')).fontSize(12).height(30).onClick(() => {
              router.pushUrl({ url: 'pages/Login' });
            })
          }
          SettingRow({ title: $r('app.string.logout'), desc: $r('app.string.logout_desc') }) {
            Button($r('app.string.logout')).fontSize(12).height(30).backgroundColor($r('app.color.danger'))
              .onClick(() => this.confirmLogout())
          }
        })

        // 自动同步
        this.Card($r('app.string.set_auto_sync'), () => {
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
              [
                { value: '60', label: $r('app.string.min_1') },
                { value: '300', label: $r('app.string.min_5') },
                { value: '900', label: $r('app.string.min_15') },
                { value: '1800', label: $r('app.string.min_30') },
              ],
              `${this.settings.syncIntervalSec}`,
              (v: string) => { this.settings.syncIntervalSec = Number(v); SettingsStore.save(this.settings); AppStorage.setOrCreate('autoSyncChanged', (AppStorage.get('autoSyncChanged') as number ?? 0) + 1); })
          }
          SettingRow({ title: $r('app.string.sync_range'), desc: $r('app.string.sync_range_desc') }) {
            this.PillRow(
              [
                { value: '30', label: $r('app.string.days_30short') },
                { value: '60', label: $r('app.string.days_60') },
                { value: '90', label: $r('app.string.days_90') },
                { value: '180', label: $r('app.string.days_180') },
                { value: 'all', label: $r('app.string.all') },
              ],
              this.settings.windowDays === null ? 'all' : `${this.settings.windowDays}`,
              (v: string) => { this.settings.windowDays = v === 'all' ? null : Number(v); SettingsStore.save(this.settings); AppStorage.setOrCreate('autoSyncChanged', (AppStorage.get('autoSyncChanged') as number ?? 0) + 1); })
          }
          SettingRow({ title: $r('app.string.full_sync'), desc: this.syncProgressMsg !== '' ? this.syncProgressMsg : $r('app.string.full_sync_desc') }) {
            Button(this.syncing ? $r('app.string.syncing') : $r('app.string.start_full_sync'))
              .fontSize(12).height(30)
              .enabled(!this.syncing)
              .onClick(() => { DataProvider.getSyncManager().sync('full'); })
          }
        })

        // 外观
        this.Card($r('app.string.set_appearance'), () => {
          SettingRow({ title: $r('app.string.theme'), desc: $r('app.string.theme_desc') }) {
            this.PillRow(
              [{ value: 'light', label: $r('app.string.light') }, { value: 'dark', label: $r('app.string.dark') }],
              this.settings.theme,
              (v: string) => { this.settings.theme = v; SettingsStore.save(this.settings); this.applyTheme(v); })
          }
          SettingRow({ title: $r('app.string.currency'), desc: $r('app.string.currency_desc') }) {
            this.PillRow(
              [{ value: 'CNY', label: '¥ CNY' }, { value: 'USD', label: '$ USD' }],
              this.settings.currency,
              (v: string) => { this.settings.currency = v; SettingsStore.save(this.settings); })
          }
          SettingRow({ title: $r('app.string.language'), desc: $r('app.string.language_desc') }) {
            this.PillRow(
              [{ value: 'zh', label: '中文' }, { value: 'en', label: 'English' }],
              this.settings.language,
              (v: string) => { this.settings.language = v; SettingsStore.save(this.settings); promptAction.showToast({ message: '重启后生效' }); })
          }
        })

        // 数据
        this.Card($r('app.string.set_data'), () => {
          SettingRow({ title: $r('app.string.data_dir'), desc: Constants.DB_NAME }) {}
          SettingRow({ title: $r('app.string.sync_info'), desc: this.syncInfoDesc() }) {}
        })

        // 更新
        this.Card($r('app.string.set_update'), () => {
          SettingRow({ title: $r('app.string.current_version'), desc: '1.0.0' }) {}
          SettingRow({ title: $r('app.string.check_update'), desc: $r('app.string.check_update_desc') }) {
            Button($r('app.string.check_update_btn')).fontSize(12).height(30).onClick(() => {
              (getContext(this) as common.UIAbilityContext).openLink('https://github.com/yphyphyph/opencode-go-gauge/releases');
            })
          }
        })
      }
      .padding(12)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.bg_page'))
    .scrollBar(BarState.Off)
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

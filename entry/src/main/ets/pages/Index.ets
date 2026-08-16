// entry/src/main/ets/pages/Index.ets
import { router } from '@kit.ArkUI';
import { display } from '@kit.ArkUI';
import { DataProvider } from '../data/DataProvider';
import { SettingsStore } from '../data/SettingsStore';
import { DashboardPage } from './DashboardPage';
import { StatsPage } from './StatsPage';
import { RecordsPage } from './RecordsPage';
import { SettingsPage } from './SettingsPage';
import { AboutPage } from './AboutPage';

@Entry
@Component
struct Index {
  @State currentTab: number = 0;
  @State loggedIn: boolean = false;
  @State wide: boolean = false;
  @Watch('applyAutoSync') @StorageLink('autoSyncChanged') autoSyncVersion: number = 0;
  @Watch('onLogout') @StorageLink('logoutVersion') logoutVersion: number = 0;

  aboutToAppear(): void {
    this.checkLogin();
    this.applyAutoSync();
    this.updateLayout();
  }

  onPageShow(): void {
    this.checkLogin();
    this.applyAutoSync();
    this.updateLayout();
  }

  private async checkLogin(): Promise<void> {
    const token = await DataProvider.getStore().getToken();
    this.loggedIn = token.trim() !== '';
  }

  /** 按 token 与自动同步开关，启动/停止同步循环。 */
  private async applyAutoSync(): Promise<void> {
    const token = await DataProvider.getStore().getToken();
    if (token.trim() !== '' && await SettingsStore.getAutoSync()) {
      DataProvider.getSyncManager().startAutoSyncLoop();
    } else {
      DataProvider.getSyncManager().stopAutoSync();
    }
  }

  /** 退出登录后：回到欢迎页并停止同步循环。 */
  private onLogout(): void {
    this.checkLogin();
    this.applyAutoSync();
  }

  private updateLayout(): void {
    const w = display.getDefaultDisplaySync().width;
    this.wide = w >= 840;
  }

  @Builder
  WelcomePage() {
    Column({ space: 16 }) {
      Text('GoGauge')
        .fontSize(40)
        .fontWeight(FontWeight.Bold)
      Text($r('app.string.welcome_desc'))
        .fontSize(14)
        .fontColor($r('app.color.text_secondary'))
        .textAlign(TextAlign.Center)
        .padding({ left: 32, right: 32 })
      Column({ space: 8 }) {
        Row() { Text('· ').fontSize(14); Text($r('app.string.welcome_feat_1')).fontSize(14) }
        Row() { Text('· ').fontSize(14); Text($r('app.string.welcome_feat_2')).fontSize(14) }
        Row() { Text('· ').fontSize(14); Text($r('app.string.welcome_feat_3')).fontSize(14) }
      }
      .alignItems(HorizontalAlign.Start)

      Button($r('app.string.login_btn'))
        .fontSize(16)
        .width(200)
        .height(44)
        .onClick(() => {
          router.pushUrl({ url: 'pages/Login' });
        })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  TabBar() {
    Row() {
      this.TabItem(0, $r('app.string.tab_home'))
      this.TabItem(1, $r('app.string.tab_stats'))
      this.TabItem(2, $r('app.string.tab_records'))
      this.TabItem(3, $r('app.string.tab_settings'))
      this.TabItem(4, $r('app.string.tab_about'))
    }
    .width('100%')
    .height(56)
    .backgroundColor($r('app.color.bg_card'))
  }

  @Builder
  TabItem(index: number, label: ResourceStr) {
    Column({ space: 2 }) {
      Text(index === 0 ? '◧' : index === 1 ? '◬' : index === 2 ? '▤' : index === 3 ? '⚙' : 'ⓘ')
        .fontSize(20)
        .fontColor(this.currentTab === index ? $r('app.color.accent') : $r('app.color.text_muted'))
      Text(label)
        .fontSize(11)
        .fontColor(this.currentTab === index ? $r('app.color.accent') : $r('app.color.text_muted'))
    }
    .layoutWeight(1)
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .onClick(() => {
      this.currentTab = index;
    })
  }

  build() {
    if (!this.loggedIn) {
      this.WelcomePage();
    } else {
      Row() {
        if (this.wide) {
          // 平板：左侧导航栏
          Column() {
            ForEach([$r('app.string.tab_home'), $r('app.string.tab_stats'), $r('app.string.tab_records'),
              $r('app.string.tab_settings'), $r('app.string.tab_about')], (item: Resource, i: number) => {
              Text(item)
                .fontSize(16)
                .fontColor(this.currentTab === i ? $r('app.color.accent') : $r('app.color.text_secondary'))
                .padding(12)
                .width('100%')
                .onClick(() => { this.currentTab = i; })
            }, (item: Resource, i: number) => `nav_${i}`)
          }
          .width(180)
          .height('100%')
          .backgroundColor($r('app.color.bg_card'))

          this.MainArea()
        } else {
          Column() {
            this.MainArea()
            this.TabBar()
          }
          .width('100%')
          .height('100%')
        }
      }
      .width('100%')
      .height('100%')
    }
  }

  @Builder
  MainArea() {
    Column() {
      if (this.currentTab === 0) {
        DashboardPage()
      } else if (this.currentTab === 1) {
        StatsPage()
      } else if (this.currentTab === 2) {
        RecordsPage()
      } else if (this.currentTab === 3) {
        SettingsPage()
      } else {
        AboutPage()
      }
    }
    .layoutWeight(1)
    .width('100%')
  }
}

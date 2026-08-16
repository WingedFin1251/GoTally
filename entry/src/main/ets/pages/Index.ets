// entry/src/main/ets/pages/Index.ets
import { router } from '@kit.ArkUI';
import { HdsTabs, HdsTabsController, HdsTabsFloatingStyle, hdsMaterial } from '@kit.UIDesignKit';
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
  @Watch('applyAutoSync') @StorageLink('autoSyncChanged') autoSyncVersion: number = 0;
  @Watch('onLogout') @StorageLink('logoutVersion') logoutVersion: number = 0;
  private tabsController: HdsTabsController = new HdsTabsController();

  aboutToAppear(): void {
    this.checkLogin();
    this.applyAutoSync();
  }

  onPageShow(): void {
    this.checkLogin();
    this.applyAutoSync();
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

  /** HdsTabs 悬浮样式：液态玻璃沉浸材质（参考 HDS 规范）。 */
  private buildFloatingStyle(): HdsTabsFloatingStyle {
    return {
      barSideMargin: 16,
      barBottomMargin: 16,
      systemMaterialEffect: {
        materialType: hdsMaterial.MaterialType.IMMERSIVE,
        materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
      }
    };
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

  /** HDS Tab 项：SymbolGlyph 图标 + 文字，选中 accent 色。 */
  @Builder
  tabBarContent(index: number, icon: Resource, label: ResourceStr) {
    Column() {
      SymbolGlyph(icon)
        .fontSize(24)
        .fontColor([this.currentTab === index ? $r('app.color.accent') : $r('app.color.text_muted')])
      Text(label)
        .fontSize(11)
        .fontWeight(this.currentTab === index ? FontWeight.Bold : FontWeight.Medium)
        .fontColor(this.currentTab === index ? $r('app.color.accent') : $r('app.color.text_muted'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .margin({ top: 2 })
    }
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .width('100%')
    .height('100%')
    .onClick(() => {
      this.tabsController.changeIndex(index);
    })
  }

  build() {
    if (!this.loggedIn) {
      this.WelcomePage();
    } else {
      HdsTabs({
        barPosition: BarPosition.End,
        index: this.currentTab,
        controller: this.tabsController
      }) {
        TabContent() {
          DashboardPage()
        }
        .tabBar(this.tabBarContent(0, $r('sys.symbol.house'), $r('app.string.tab_home')))

        TabContent() {
          StatsPage()
        }
        .tabBar(this.tabBarContent(1, $r('sys.symbol.square_grid_2x2'), $r('app.string.tab_stats')))

        TabContent() {
          RecordsPage()
        }
        .tabBar(this.tabBarContent(2, $r('sys.symbol.list_bullet'), $r('app.string.tab_records')))

        TabContent() {
          SettingsPage()
        }
        .tabBar(this.tabBarContent(3, $r('sys.symbol.gearshape'), $r('app.string.tab_settings')))

        TabContent() {
          AboutPage()
        }
        .tabBar(this.tabBarContent(4, $r('sys.symbol.info_circle'), $r('app.string.tab_about')))
      }
      .barHeight(62)
      .barOverlap(true)
      .barBackgroundColor(Color.Transparent)
      .barBackgroundBlurStyle(BlurStyle.COMPONENT_THIN)
      .barFloatingStyle(this.buildFloatingStyle())
      .backgroundColor($r('app.color.bg_page'))
      .scrollable(false)
      .animationDuration(0)
      .onChange((index: number) => {
        this.currentTab = index;
      })
      .width('100%')
      .height('100%')
    }
  }
}

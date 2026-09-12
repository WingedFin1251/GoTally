// entry/src/main/ets/pages/Index.ets
import { window } from '@kit.ArkUI';
import { HdsAnimationMode, HdsTabs, HdsTabsController, HdsTabsFloatingStyle, hdsMaterial } from '@kit.UIDesignKit';
import { DataProvider } from '../data/DataProvider';
import { SettingsStore } from '../data/SettingsStore';
import { setLanguage } from '../common/utils/Locale';
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
  @State navIndicatorHeight: number = 0;
  /** 沉浸光感档位（设置页可调）：0 弱 / 1 均衡 / 2 强，映射 HDS 系统材质等级。 */
  @StorageProp('glowLevel') glowLevel: number = 1;
  @Watch('applyAutoSync') @StorageLink('autoSyncChanged') autoSyncVersion: number = 0;
  @Watch('onLogout') @StorageLink('logoutVersion') logoutVersion: number = 0;
  private tabsController: HdsTabsController = new HdsTabsController();

  aboutToAppear(): void {
    this.initLocale();
    this.checkLogin();
    this.applyAutoSync();
    this.resolveSystemInsets();
  }

  onPageShow(): void {
    this.checkLogin();
    this.applyAutoSync();
  }

  /** 同步当前语言到 Locale 模块，驱动数字格式（万/亿 vs k/M）本地化。 */
  private async initLocale(): Promise<void> {
    setLanguage(await SettingsStore.getLanguage());
  }

  /**
   * 沉浸式布局下读取系统避让区：状态栏高度（顶部）与底部导航（含手势小白条）高度，
   * 供悬浮导航栏上移、各页面内容加安全区内边距使用。
   */
  private async resolveSystemInsets(): Promise<void> {
    try {
      const hostCtx = this.getUIContext().getHostContext();
      if (hostCtx === undefined) {
        throw new Error('host context unavailable');
      }
      const win = await window.getLastWindow(hostCtx);
      const sys = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
      const nav = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR);
      // getWindowAvoidArea 返回单位是 px，转成 vp 后再用于布局内边距
      const top = this.getUIContext().px2vp(sys.topRect.height);
      const bottom = this.getUIContext().px2vp(nav.bottomRect.height > 0 ? nav.bottomRect.height : sys.bottomRect.height);
      this.navIndicatorHeight = bottom;
      AppStorage.setOrCreate('statusBarHeight', top);
      AppStorage.setOrCreate('navIndicatorHeight', bottom);
    } catch (e) {
      this.navIndicatorHeight = 0;
      AppStorage.setOrCreate('statusBarHeight', 0);
      AppStorage.setOrCreate('navIndicatorHeight', 0);
    }
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

  /** HdsTabs 悬浮样式：与参考实现一致——动态底部避让 + 跟随左右手 + IMMERSIVE 三档材质。 */
  private buildFloatingStyle(): HdsTabsFloatingStyle {
    let level: hdsMaterial.MaterialLevel = hdsMaterial.MaterialLevel.ADAPTIVE;
    if (this.glowLevel === 0) {
      level = hdsMaterial.MaterialLevel.GENTLE;
    } else if (this.glowLevel === 2) {
      level = hdsMaterial.MaterialLevel.EXQUISITE;
    }
    return {
      barBottomMargin: this.navIndicatorHeight === 0 ? 12 : this.navIndicatorHeight + 1,
      adaptToHandedness: true,
      systemMaterialEffect: {
        materialType: hdsMaterial.MaterialType.IMMERSIVE,
        materialLevel: level
      }
    };
  }

  /** 页面滚动联动：向下滚隐藏悬浮导航栏，向上滚显示（HDS 滚动场景动画）。 */
  private playNavAnimation(hide: boolean): void {
    if (hide) {
      this.tabsController.applyHideAnimation(HdsAnimationMode.SCROLL_ANIMATION);
    } else {
      this.tabsController.applyShowAnimation(HdsAnimationMode.SCROLL_ANIMATION);
    }
  }

  @Builder
  WelcomePage() {
    Column({ space: 16 }) {
      Text('GoTally')
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
          this.getUIContext().getRouter().pushUrl({ url: 'pages/Login' });
        })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }

  /** HDS Tab 项：SymbolGlyph 图标 + 文字；规格对齐参考实现（22 图标 / 10.5 文字 / 选中加粗 accent / 200ms 缓动）。 */
  @Builder
  tabBarContent(index: number, icon: Resource, label: ResourceStr) {
    Column({ space: 3 }) {
      SymbolGlyph(icon)
        .fontSize(22)
        .fontColor([this.currentTab === index ? $r('app.color.accent') : $r('app.color.text_muted')])
        .animation({ duration: 200, curve: Curve.FastOutSlowIn })
      Text(label)
        .fontSize(10.5)
        .fontWeight(this.currentTab === index ? FontWeight.Bold : FontWeight.Normal)
        .fontColor(this.currentTab === index ? $r('app.color.accent') : $r('app.color.text_muted'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .animation({ duration: 200, curve: Curve.FastOutSlowIn })
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
          DashboardPage({ onNavChanged: (hide: boolean) => { this.playNavAnimation(hide); } })
        }
        .tabBar(this.tabBarContent(0, $r('sys.symbol.house'), $r('app.string.tab_home')))

        TabContent() {
          StatsPage({ onNavChanged: (hide: boolean) => { this.playNavAnimation(hide); } })
        }
        .tabBar(this.tabBarContent(1, $r('sys.symbol.square_grid_2x2'), $r('app.string.tab_stats')))

        TabContent() {
          RecordsPage({ onNavChanged: (hide: boolean) => { this.playNavAnimation(hide); } })
        }
        .tabBar(this.tabBarContent(2, $r('sys.symbol.list_bullet'), $r('app.string.tab_records')))

        TabContent() {
          SettingsPage({ onNavChanged: (hide: boolean) => { this.playNavAnimation(hide); } })
        }
        .tabBar(this.tabBarContent(3, $r('sys.symbol.gearshape'), $r('app.string.tab_settings')))

        TabContent() {
          AboutPage({ onNavChanged: (hide: boolean) => { this.playNavAnimation(hide); } })
        }
        .tabBar(this.tabBarContent(4, $r('sys.symbol.info_circle'), $r('app.string.tab_about')))
      }
      .barHeight(56)
      .barOverlap(true)
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

// entry/src/main/ets/pages/Index.ets
import { window } from '@kit.ArkUI';
import type { SyncResult } from '../network/SyncManager';
import { HdsAnimationMode, HdsTabs, HdsTabsController, HdsTabsFloatingStyle, hdsMaterial } from '@kit.UIDesignKit';
import { DataProvider } from '../data/DataProvider';
import { SettingsStore } from '../data/SettingsStore';
import { setLanguage } from '../common/utils/Locale';
import { DashboardPage } from './DashboardPage';
import { StatsPage } from './StatsPage';
import { RecordsPage } from './RecordsPage';
import { SettingsPage } from './SettingsPage';
import { AboutPage } from './AboutPage';

/** 免登录模式弹窗：输入 OpenCode Go API Key（仅配额可用）。 */
@CustomDialog
struct ApiKeyDialog {
  controller?: CustomDialogController;
  private keyDraft: string = '';
  onConfirm: (key: string) => void = () => {};

  build() {
    Column({ space: 12 }) {
      Text($r('app.string.guest_title')).fontSize(16).fontWeight(FontWeight.Bold)
      Text($r('app.string.guest_desc'))
        .fontSize(12)
        .fontColor($r('app.color.text_muted'))
      TextInput({ placeholder: $r('app.string.go_api_key_ph') })
        .type(InputType.Password)
        .fontSize(13)
        .height(40)
        .onChange((v: string) => { this.keyDraft = v; })
      Row({ space: 10 }) {
        Button($r('app.string.cancel'))
          .layoutWeight(1)
          .fontSize(14)
          .height(38)
          .backgroundColor($r('app.color.divider'))
          .fontColor($r('app.color.text_primary'))
          .onClick(() => { this.controller?.close(); })
        Button($r('app.string.ok'))
          .layoutWeight(1)
          .fontSize(14)
          .height(38)
          .onClick(() => {
            this.controller?.close();
            this.onConfirm(this.keyDraft);
          })
      }
      .width('100%')
    }
    .padding(20)
    .width('100%')
  }
}

@Entry
@Component
struct Index {
  @State currentTab: number = 0;
  @State loggedIn: boolean = false;
  /** 是否已配置 OpenCode Go API Key（免登录模式：仅凭 Key 也可进入主界面看配额）。 */
  @State hasApiKey: boolean = false;
  /** 登录态是否已判定：未判定前渲染中性占位（与系统闪屏一致），避免冷启动闪现欢迎页/登录页。 */
  @State authChecked: boolean = false;
  @State navIndicatorHeight: number = 0;
  /** 沉浸光感档位（设置页可调）：0 弱 / 1 均衡 / 2 强，映射 HDS 系统材质等级。 */
  @StorageProp('glowLevel') glowLevel: number = 1;
  @Watch('applyAutoSync') @StorageLink('autoSyncChanged') autoSyncVersion: number = 0;
  @Watch('onLogout') @StorageLink('logoutVersion') logoutVersion: number = 0;
  private tabsController: HdsTabsController = new HdsTabsController();
  /** 免登录模式：输入 API Key 的弹窗。 */
  private apiKeyDialog: CustomDialogController = new CustomDialogController({
    builder: ApiKeyDialog({
      onConfirm: (key: string) => { this.enterGuestMode(key); },
    }),
    autoCancel: true,
  });

  aboutToAppear(): void {
    // 外壳已在 loadContent 前预读登录态（启动闪屏期间完成）：首帧直接采用，
    // 不再先用 loggedIn=false 渲染欢迎页，从而消除「闪一下登录界面」。
    this.initAuthState();
    this.initLocale();
    this.checkLogin();
    this.applyAutoSync();
    this.resolveSystemInsets();
    this.bindSyncNotifier();
  }

  /**
   * 数据层同步终止 → 由外壳统一广播「数据已变更」（syncFinishedVersion）。
   * 之前该广播写在设置页的进度回调里，只有设置页在监听时才会发出，
   * 导致在首页/记录页时同步完成界面不刷新，必须手动切换周期筛选才更新。
   */
  private bindSyncNotifier(): void {
    DataProvider.getSyncManager().onFinished = (result: SyncResult) => {
      AppStorage.setOrCreate('syncFinishedVersion',
        (AppStorage.get('syncFinishedVersion') as number ?? 0) + 1);
    };
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

  /**
   * 进入主界面的条件：已登录（有 token）**或**已配置 API Key（免登录模式，仅配额可用）。
   * 两者都读完后才置 authChecked，避免冷启动先闪欢迎页再跳主界面。
   */
  private async initAuthState(): Promise<void> {
    if (AppStorage.get<boolean>('authPreloaded') === true) {
      this.loggedIn = AppStorage.get<boolean>('hasToken') ?? false;
    }
    try {
      this.hasApiKey = (await SettingsStore.getGoApiKey()).trim() !== '';
    } catch (e) {
      this.hasApiKey = false;
    }
    this.authChecked = true;
  }

  /** 免登录模式入口：保存 API Key 后直接进主界面（配额走官方接口，无需 cookie）。 */
  private async enterGuestMode(apiKey: string): Promise<void> {
    const key = apiKey.trim();
    if (key === '') {
      this.toastSafe(this.resText($r('app.string.guest_key_required')));
      return;
    }
    try {
      await SettingsStore.setGoApiKey(key);
      this.hasApiKey = true;
      this.authChecked = true;
    } catch (e) {
      console.error('enterGuestMode failed: ' + (e instanceof Error ? e.message : String(e)));
      this.toastSafe(this.resText($r('app.string.guest_save_failed')));
    }
  }

  private resText(res: Resource): string {
    try {
      const ctx = this.getUIContext().getHostContext();
      return ctx !== undefined ? ctx.resourceManager.getStringSync(res.id) : '';
    } catch (e) {
      return '';
    }
  }

  private toastSafe(msg: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: msg });
    } catch (e) {
      console.error('toast failed: ' + (e instanceof Error ? e.message : String(e)));
    }
  }

  private async checkLogin(): Promise<void> {
    try {
      const token = await DataProvider.getStore().getToken();
      this.loggedIn = token.trim() !== '';
      this.hasApiKey = (await SettingsStore.getGoApiKey()).trim() !== '';
      AppStorage.setOrCreate('hasToken', this.loggedIn);
    } catch (e) {
      console.error('checkLogin failed: ' + (e instanceof Error ? e.message : String(e)));
    } finally {
      this.authChecked = true;
    }
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

      // 免登录模式：只填 API Key 即可查看配额（记录/统计需登录后同步）
      Button($r('app.string.guest_btn'))
        .fontSize(14)
        .width(200)
        .height(40)
        .backgroundColor($r('app.color.divider'))
        .fontColor($r('app.color.text_primary'))
        .onClick(() => {
          this.apiKeyDialog.open();
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

  /** 冷启动占位：与系统启动闪屏同背景同图标，登录态判定完成后无缝切到首页或欢迎页。 */
  @Builder
  SplashPlaceholder() {
    Column() {
      Image($r('app.media.startIcon'))
        .width(96)
        .height(96)
        .objectFit(ImageFit.Contain)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor($r('app.color.start_window_background'))
  }

  build() {
    if (!this.authChecked) {
      this.SplashPlaceholder();
    } else if (!this.loggedIn && !this.hasApiKey) {
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

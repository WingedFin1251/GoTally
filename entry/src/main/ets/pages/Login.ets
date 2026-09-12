// entry/src/main/ets/pages/Login.ets
import { window } from '@kit.ArkUI';
import { webview } from '@kit.ArkWeb';
import { OpenCodeApi } from '../network/OpenCodeApi';
import { DataProvider } from '../data/DataProvider';
import { Constants } from '../common/constants/Constants';

const WORKSPACE_URL_RE: RegExp = /\/workspace\/(wrk_[A-Za-z0-9]+)/;

@Entry
@Component
struct Login {
  @State loginUrl: string = OpenCodeApi.buildLoginUrl();
  @State loading: boolean = true;
  @State done: boolean = false;
  /** 状态栏高度（vp）：沉浸式布局下用于标题栏顶部避让，避免与系统状态栏重叠。 */
  @State statusBarHeight: number = 0;
  private controller: webview.WebviewController = new webview.WebviewController();

  aboutToAppear(): void {
    this.resolveStatusBarHeight();
  }

  /**
   * 沉浸式布局（EntryAbility 已 setWindowLayoutFullScreen）下读取状态栏高度：
   * getWindowAvoidArea 返回 px，需 px2vp 转成 vp 后再用于内边距。
   */
  private async resolveStatusBarHeight(): Promise<void> {
    try {
      const hostCtx = this.getUIContext().getHostContext();
      if (hostCtx === undefined) {
        return;
      }
      const win = await window.getLastWindow(hostCtx);
      const sys = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
      this.statusBarHeight = this.getUIContext().px2vp(sys.topRect.height);
    } catch (e) {
      console.error('resolveStatusBarHeight failed: ' + (e instanceof Error ? e.message : String(e)));
    }
  }

  private async captureAndFinish(url: string): Promise<void> {
    if (this.done) {
      return;
    }
    let cookies: string = '';
    try {
      cookies = webview.WebCookieManager.fetchCookieSync(Constants.LOGIN_COOKIE_DOMAIN);
    } catch (e) {
      cookies = '';
    }
    if (cookies === null || cookies === '') {
      return;
    }
    let authValue = '';
    for (const part of cookies.split(';')) {
      const p = part.trim();
      if (p.startsWith(`${Constants.AUTH_COOKIE_NAME}=`)) {
        authValue = p.substring(Constants.AUTH_COOKIE_NAME.length + 1);
        break;
      }
    }
    if (authValue === '') {
      return;
    }
    const m = WORKSPACE_URL_RE.exec(url);
    const workspaceHint = m !== null ? m[1] : 'Default';
    this.done = true;
    await DataProvider.getStore().saveToken(`auth=${authValue}`, workspaceHint);
    // 触发首次全量同步（后台）
    DataProvider.getSyncManager().sync('full');
    this.getUIContext().getRouter().back();
  }

  build() {
    Column() {
      // 标题栏：顶部让出状态栏，避免与系统状态栏（时间/信号/电量）重叠
      Row() {
        Text('GoTally')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
        Blank()
        Button('取消')
          .fontSize(14)
          .height(30)
          .onClick(() => this.getUIContext().getRouter().back())
      }
      .width('100%')
      .padding({ left: 12, right: 12, top: this.statusBarHeight + 10, bottom: 10 })
      .backgroundColor($r('app.color.bg_page'))

      // 授权页 WebView 占满剩余空间；加载指示改为浮层，避免挤压 WebView 造成页面跳动
      Stack({ alignContent: Alignment.Center }) {
        Web({ src: this.loginUrl, controller: this.controller })
          .width('100%')
          .height('100%')
          .onPageBegin((event) => {
            this.loading = false;
          })
          .onLoadIntercept((event) => {
            const url: string = event.data.getRequestUrl();
            if (url.startsWith('https://opencode.ai')) {
              this.captureAndFinish(url);
            }
            return false;
          })
          .javaScriptAccess(true)
          .domStorageAccess(true)

        if (this.loading) {
          LoadingProgress().width(40).height(40)
        }
      }
      .width('100%')
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.bg_page'))
  }
}
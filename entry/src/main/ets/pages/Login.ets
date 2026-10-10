// entry/src/main/ets/pages/Login.ets
import { window } from '@kit.ArkUI';
import { webview } from '@kit.ArkWeb';
import { OpenCodeApi } from '../network/OpenCodeApi';
import { DataProvider } from '../data/DataProvider';
import { Constants } from '../common/constants/Constants';
import { WebCookies } from '../common/utils/WebCookies';
import { LoginCredential } from '../common/utils/LoginCredential';

const WORKSPACE_URL_RE: RegExp = /\/workspace\/(wrk_[A-Za-z0-9]+)/;

@Entry
@Component
struct Login {
  @State loginUrl: string = OpenCodeApi.buildLoginUrl();
  @State loading: boolean = true;
  @State done: boolean = false;
  @State hint: string = '';
  /** 状态栏高度（vp）：沉浸式布局下用于标题栏顶部避让，避免与系统状态栏重叠。 */
  @State statusBarHeight: number = 0;
  private controller: webview.WebviewController = new webview.WebviewController();
  /** 最近一次页面地址：cookie 轮询时用于提取工作区 ID。 */
  private lastUrl: string = OpenCodeApi.buildLoginUrl();
  private pollTimer: number = -1;
  private pollCount: number = 0;

  aboutToAppear(): void {
    this.resolveStatusBarHeight();
    this.startPolling();
  }

  aboutToDisappear(): void {
    this.stopPolling();
  }

  /**
   * 登录成功判定不能只依赖一次 URL 拦截：
   * 回调页的 `auth` cookie 由响应头 Set-Cookie 写入（而拦截发生在请求发起时，此刻还没有 cookie），
   * 之后页面又是 SPA 客户端路由跳转（不再触发导航拦截），单靠 onLoadIntercept 会一直抓不到凭据。
   * 因此改为「拦截时立即尝试 + 定时轮询 cookie」，并提供「我已登录」手动兜底。
   */
  private startPolling(): void {
    if (this.pollTimer !== -1) {
      return;
    }
    this.pollTimer = setInterval(() => {
      this.pollCount++;
      this.captureAndFinish(this.lastUrl);
      if (!this.done && this.pollCount === 6) {
        this.hint = '若网页已显示登录成功，请点右上角「我已登录」';
      }
      // 长时间停在 GitHub 授权页：明确提示要点绿色按钮（避免用户以为卡死）
      if (!this.done && this.pollCount === 20 && LoginCredential.isGithubAuthorizePage(this.lastUrl)) {
        this.hint = '请在 GitHub 页面点绿色 Authorize 按钮（本应用只认授权后回到 opencode 的登录态）';
      }
      // 每 ~6s 打印一次 cookie 名快照（不含值），便于定位凭据抓取失败的原因
      if (!this.done && this.pollCount % 10 === 0) {
        console.error('login poll cookie names: ' + this.cookieDiagnostics());
      }
      if (this.pollCount >= 150) {
        this.stopPolling();
      }
    }, 600);
  }

  private stopPolling(): void {
    if (this.pollTimer !== -1) {
      clearInterval(this.pollTimer);
      this.pollTimer = -1;
    }
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

  /**
   * 汇总 opencode 域下可见的 cookie，判定是否拿到可用登录凭据。
   *
   * 修复要点（真机 bug）：**绝不探测当前页面地址**。
   * 停在 `github.com/login/oauth/authorize` 时，当前页是 GitHub，
   * 之前把它纳入探测范围会读到 GitHub 的 `user_session` 并被宽松的
   * 「名字含 session」规则误判为已登录（还会把 GitHub cookie 存成凭据）。
   * 现在只查 opencode 两个域 + **精确匹配**控制台会话 / 旧版 auth cookie 名。
   */
  private readCredential(): string {
    // 同时带上「当前页面地址」：cookie 可能带 path 作用域（如 /auth、/workspace），
    // 但仅当当前页确属 opencode 域时才纳入（否则会读到 GitHub 的 cookie）。
    const urls: string[] = [Constants.OPENCODE_ORIGIN, Constants.AUTH_ORIGIN];
    if (LoginCredential.isOpencodeHost(this.lastUrl)) {
      urls.push(this.lastUrl);
    }
    return LoginCredential.pick(WebCookies.readAll(urls));
  }

  /** 诊断串：各候选地址下可见的 cookie 名（不含值），抓不到凭据时用于定位。 */
  private cookieDiagnostics(): string {
    const page = WebCookies.names(this.lastUrl);
    const a = WebCookies.names(Constants.OPENCODE_ORIGIN);
    const b = WebCookies.names(Constants.AUTH_ORIGIN);
    return `page=[${page}] opencode.ai=[${a}] auth=[${b}]`;
  }

  private async manualFinish(): Promise<void> {
    await this.captureAndFinish(this.lastUrl);
    if (!this.done) {
      const diag = this.cookieDiagnostics();
      console.error('login credential missing: ' + diag);
      this.hint = `未取到登录凭据（cookie: ${diag}）`;
    }
  }

  private async captureAndFinish(url: string): Promise<void> {
    if (this.done) {
      return;
    }
    // ① 必须已回到 opencode 域：GitHub 授权页（URL 里含 opencode.ai 字样）不算数
    if (!LoginCredential.isOpencodeHost(url)) {
      if (LoginCredential.isGithubAuthorizePage(url) && this.hint === '') {
        this.hint = '请在 GitHub 页面点绿色 Authorize 按钮完成授权';
      }
      return;
    }
    const credential = this.readCredential();
    if (credential === '') {
      return;
    }
    // ② 保存前探活：避免把无效凭据（如 GitHub cookie）当登录态存下来
    const valid = await OpenCodeApi.validateConsoleCredential(credential);
    if (this.done) {
      return;
    }
    if (!valid) {
      console.error('login credential rejected: ' + this.cookieDiagnostics());
      this.hint = '尚未取到有效的 OpenCode 登录态，请完成授权后重试（右上角可手动确认）';
      return;
    }
    const m = WORKSPACE_URL_RE.exec(url);
    const workspaceHint = m !== null ? m[1] : 'Default';
    this.done = true;
    this.stopPolling();
    console.error('login credential captured: ' + this.cookieDiagnostics());
    await DataProvider.getStore().saveToken(credential, workspaceHint);
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
        Blank()
        Button('我已登录')
          .fontSize(13)
          .height(30)
          .onClick(() => this.manualFinish())
        Button('取消')
          .fontSize(13)
          .height(30)
          .margin({ left: 8 })
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
          .onPageEnd((event) => {
            // 记录最新地址（用于提取 wrk_* 工作区），并立即尝试取凭据
            if (event.url !== '') {
              this.lastUrl = event.url;
            }
            this.captureAndFinish(this.lastUrl);
          })
          .onLoadIntercept((event) => {
            const url: string = event.data.getRequestUrl();
            if (url.startsWith('https://opencode.ai')) {
              this.lastUrl = url;
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

      if (this.hint !== '') {
        Text(this.hint)
          .fontSize(12)
          .fontColor($r('app.color.text_muted'))
          .width('100%')
          .textAlign(TextAlign.Center)
          .padding({ left: 16, right: 16, bottom: 10 })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.bg_page'))
  }
}

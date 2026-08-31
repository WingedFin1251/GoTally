// entry/src/main/ets/pages/Login.ets
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
  private controller: webview.WebviewController = new webview.WebviewController();

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
      Row() {
        Text('GoTally')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
        Blank()
        Button('取消')
          .fontSize(14)
          .onClick(() => this.getUIContext().getRouter().back())
      }
      .width('100%')
      .padding(12)

      if (this.loading) {
        LoadingProgress().width(40).height(40)
      }

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
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.bg_page'))
  }
}

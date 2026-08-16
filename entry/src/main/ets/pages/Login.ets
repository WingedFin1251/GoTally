// entry/src/main/ets/pages/Login.ets
import { router } from '@kit.ArkUI';
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
    const cookies = webview.WebCookieManager.getCookieSync(Constants.LOGIN_COOKIE_DOMAIN);
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
    router.back();
  }

  build() {
    Column() {
      Row() {
        Text('GoGauge')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
        Blank()
        Button('取消')
          .fontSize(14)
          .onClick(() => router.back())
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
        .onUrlLoadIntercept((event) => {
          const url = event.data.url;
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

// entry/src/main/ets/common/utils/WebCookies.ets
import { webview } from '@kit.ArkWeb';

/** 从 WebView cookie 存储读取登录态 cookie（控制台 JSON 接口鉴权用）。 */
export class WebCookies {
  /**
   * 读取指定 cookie 的值。
   *
   * URL 传站点地址（如 https://opencode.ai），WebView 返回该站点当前可见的 cookie 串。
   * 之所以现读而不落库：控制台会话 cookie 为 HttpOnly 且会自行过期，
   * 现读可覆盖「已登录用户无需重新登录」的场景。
   *
   * @param name cookie 名
   * @param url 站点地址
   * @returns cookie 值；不存在或读取失败时为空串
   */
  static read(name: string, url: string): string {
    try {
      const all = webview.WebCookieManager.fetchCookieSync(url);
      if (all === null || all === '') {
        return '';
      }
      for (const part of all.split(';')) {
        const p = part.trim();
        if (p.startsWith(`${name}=`)) {
          return p.substring(name.length + 1);
        }
      }
    } catch (e) {
      // Web 组件未初始化 / cookie 存储不可用：静默降级到其他数据源
      console.error('WebCookies.read failed: ' + (e instanceof Error ? e.message : String(e)));
    }
    return '';
  }
}
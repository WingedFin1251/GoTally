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
    const all = WebCookies.raw(url);
    if (all === '') {
      return '';
    }
    for (const part of all.split(';')) {
      const p = part.trim();
      if (p.startsWith(`${name}=`)) {
        return p.substring(name.length + 1);
      }
    }
    return '';
  }

  /** 读取某地址下可见的原始 cookie 串（失败返回空串）。 */
  static raw(url: string): string {
    try {
      const all = webview.WebCookieManager.fetchCookieSync(url);
      return all !== null && all !== undefined ? all : '';
    } catch (e) {
      // Web 组件未初始化 / cookie 存储不可用：静默降级到其他数据源
      console.error('WebCookies.raw failed: ' + (e instanceof Error ? e.message : String(e)));
      return '';
    }
  }

  /**
   * 汇总多个地址下可见的 cookie（去重后以 `name=value; name2=value2` 返回）。
   * 登录凭据的域名可能从 opencode.ai 变为 auth.opencode.ai，故多地址汇总。
   */
  static readAll(urls: string[]): string {
    const seen = new Set<string>();
    const parts: string[] = [];
    for (const url of urls) {
      const all = WebCookies.raw(url);
      if (all === '') {
        continue;
      }
      for (const part of all.split(';')) {
        const p = part.trim();
        if (p === '' || seen.has(p)) {
          continue;
        }
        seen.add(p);
        parts.push(p);
      }
    }
    return parts.join('; ');
  }

  /**
   * 清空 WebView 的 cookie 存储。
   *
   * 退出登录时调用：opencode 的会话 cookie 属于 HttpOnly 且保存在 WebView 里，
   * 只清应用库里的 token 的话，下次「重新登录」会直接复用旧会话
   * （表现为没点授权就"登录成功"），也就**无法切换账号**。
   * 因此退出登录时一并清掉网页登录态，保证下次真的重走一遍授权。
   */
  static clearAll(): void {
    try {
      webview.WebCookieManager.clearAllCookiesSync();
    } catch (e) {
      console.error('WebCookies.clearAll failed: ' + (e instanceof Error ? e.message : String(e)));
    }
  }

  /** 清空 WebView 的站点数据（localStorage / IndexedDB 等），与 clearAll 一起用于退出登录。 */
  static clearWebStorage(): void {
    try {
      webview.WebStorage.deleteAllData();
    } catch (e) {
      console.error('WebCookies.clearWebStorage failed: ' + (e instanceof Error ? e.message : String(e)));
    }
  }

  /** 诊断用：返回某地址下可见的 cookie **名**列表（不含值，避免泄露凭据）。 */
  static names(url: string): string {
    const all = WebCookies.raw(url);
    if (all === '') {
      return '(空)';
    }
    const names: string[] = [];
    for (const part of all.split(';')) {
      const p = part.trim();
      const eq = p.indexOf('=');
      if (eq > 0) {
        names.push(p.substring(0, eq));
      }
    }
    return names.length > 0 ? names.join(',') : '(空)';
  }
}
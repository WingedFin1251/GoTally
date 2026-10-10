// entry/src/main/ets/common/utils/LoginCredential.ets
import { Constants } from '../constants/Constants';

/**
 * 登录凭据判定（纯逻辑，便于回归测试）。
 *
 * 背景（真机 bug）：GitHub 授权流程中会先停在
 * `https://github.com/login/oauth/authorize?...redirect_uri=https%3A%2F%2Fopencode.ai...`，
 * 该 URL 里**含有** opencode.ai 字样，且 GitHub 自己会写入名为 `user_session` 的 cookie。
 * 早期实现用「cookie 名包含 session」这种宽松判断 + 把当前页面地址也纳入 cookie 探测范围，
 * 结果在授权页就误判为「已登录」，并把 GitHub 的 cookie 当成 OpenCode 凭据保存。
 *
 * 现在的规则：
 *  ① 只接受**精确匹配**的控制台会话 cookie 名或旧版 `auth` cookie；
 *  ② 当前页面**必须已回到 opencode 域**（github.com 上的任何 cookie 都不算数）。
 */
export class LoginCredential {
  /**
   * 从汇总 cookie 串中判定是否含有可用登录凭据。
   *
   * @param cookieString `name=value; name2=value2` 形式
   * @returns 命中时返回**整串**（发送全部 cookie 更稳），否则空串
   */
  static pick(cookieString: string): string {
    if (cookieString === '') {
      return '';
    }
    for (const part of cookieString.split(';')) {
      const p = part.trim();
      const eq = p.indexOf('=');
      if (eq <= 0) {
        continue;
      }
      const name = p.substring(0, eq).trim();
      const value = p.substring(eq + 1).trim();
      if (value === '') {
        continue;
      }
      if (name === Constants.CONSOLE_COOKIE_NAME || name === Constants.AUTH_COOKIE_NAME) {
        return cookieString;
      }
    }
    return '';
  }

  /**
   * 当前页面地址是否已回到 opencode 域。
   *
   * 注意 `github.com/login/oauth/authorize?...redirect_uri=...opencode.ai...` 属于 GitHub，
   * 必须返回 false——这是本 bug 的核心判据。
   */
  static isOpencodeHost(url: string): boolean {
    const host = LoginCredential.hostOf(url);
    return host === 'opencode.ai' || host.endsWith('.opencode.ai');
  }

  /** 取 URL 的 host（小写）；解析失败返回空串。 */
  static hostOf(url: string): string {
    const s = url.trim().toLowerCase();
    const i = s.indexOf('://');
    if (i < 0) {
      return '';
    }
    let rest = s.substring(i + 3);
    const cut = rest.search(/[/?#]/);
    if (cut >= 0) {
      rest = rest.substring(0, cut);
    }
    const at = rest.lastIndexOf('@');
    if (at >= 0) {
      rest = rest.substring(at + 1);
    }
    const colon = rest.indexOf(':');
    if (colon >= 0) {
      rest = rest.substring(0, colon);
    }
    return rest;
  }

  /** 是否停在 GitHub（授权确认/登录）页面：用于给出「请点绿色 Authorize」提示。 */
  static isGithubHost(url: string): boolean {
    const host = LoginCredential.hostOf(url);
    return host === 'github.com' || host.endsWith('.github.com');
  }

  /** 是否 GitHub 的 OAuth 授权确认页（需要用户点绿色按钮那一步）。 */
  static isGithubAuthorizePage(url: string): boolean {
    if (!LoginCredential.isGithubHost(url)) {
      return false;
    }
    const s = url.toLowerCase();
    return s.includes('/login/oauth/authorize') || s.includes('/login/oauth/device');
  }
}

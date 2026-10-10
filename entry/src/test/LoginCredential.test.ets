import { describe, it, expect } from '@ohos/hypium';
import { LoginCredential } from '../main/ets/common/utils/LoginCredential';

/**
 * 登录凭据判定（回归测试）。
 *
 * 对应真机 bug：GitHub 授权页被误判为「已登录」——
 * 该页 URL 里含 opencode.ai 字样，且 GitHub 会写 `user_session` cookie，
 * 早期「名字含 session 就算命中」的规则会把它当成 OpenCode 凭据保存。
 */
export default function loginCredentialTest() {
  describe('LoginCredentialTest', () => {
    it('accepts_exact_console_session_cookie', 0, () => {
      expect(LoginCredential.pick('__Host-console_session=abc123')).assertEqual('__Host-console_session=abc123');
      expect(LoginCredential.pick('foo=1; __Host-console_session=abc123; bar=2'))
        .assertEqual('foo=1; __Host-console_session=abc123; bar=2');
    });

    it('accepts_legacy_auth_cookie', 0, () => {
      expect(LoginCredential.pick('auth=Fe26.2**deadbeef')).assertEqual('auth=Fe26.2**deadbeef');
      expect(LoginCredential.pick('provider=p; auth=tok')).assertEqual('provider=p; auth=tok');
    });

    it('rejects_github_cookies', 0, () => {
      // GitHub 的会话 cookie 名字含 session，但绝不能被当作凭据
      expect(LoginCredential.pick('user_session=abcdef')).assertEqual('');
      expect(LoginCredential.pick('_gh_sess=abc; logged_in=yes')).assertEqual('');
      expect(LoginCredential.pick('session=abc')).assertEqual('');
      expect(LoginCredential.pick('')).assertEqual('');
      // 名字对但值为空同样不算
      expect(LoginCredential.pick('__Host-console_session=')).assertEqual('');
    });

    it('opencode_host_detection_ignores_github_authorize_url', 0, () => {
      // 关键用例：授权页 URL 里含 opencode.ai，但 host 是 github.com
      const authorize = 'https://github.com/login/oauth/authorize?client_id=x&redirect_uri=https%3A%2F%2Fopencode.ai%2Fauth%2Fcallback';
      expect(LoginCredential.isOpencodeHost(authorize)).assertFalse();
      expect(LoginCredential.isGithubHost(authorize)).assertTrue();
      expect(LoginCredential.isGithubAuthorizePage(authorize)).assertTrue();
    });

    it('opencode_host_detection_accepts_callback', 0, () => {
      expect(LoginCredential.isOpencodeHost('https://opencode.ai/auth/callback?code=x')).assertTrue();
      expect(LoginCredential.isOpencodeHost('https://auth.opencode.ai/authorize')).assertTrue();
      expect(LoginCredential.isOpencodeHost('https://opencode.ai')).assertTrue();
      // 近似域名不算（避免被 opencode.ai.evil.com 之类骗过）
      expect(LoginCredential.isOpencodeHost('https://opencode.ai.evil.com/')).assertFalse();
      expect(LoginCredential.isOpencodeHost('https://notopencode.ai/')).assertFalse();
      expect(LoginCredential.isOpencodeHost('')).assertFalse();
    });

    it('host_parsing_handles_ports_and_no_scheme', 0, () => {
      expect(LoginCredential.hostOf('https://Opencode.AI:443/auth')).assertEqual('opencode.ai');
      expect(LoginCredential.hostOf('opencode.ai/auth')).assertEqual('');
      expect(LoginCredential.hostOf('https://user:pw@opencode.ai/x')).assertEqual('opencode.ai');
    });
  });
}

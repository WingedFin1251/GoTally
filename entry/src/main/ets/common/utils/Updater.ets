// entry/src/main/ets/common/utils/Updater.ets
import { http } from '@kit.NetworkKit';
import { AppInfo } from './AppInfo';

/** 更新检查结果。 */
export interface UpdateCheckResult {
  /** 检查流程是否成功（false 表示网络/解析失败，error 有原因）。 */
  ok: boolean;
  /** 是否存在更新版本。 */
  hasUpdate: boolean;
  /** 本地版本（如 1.2.0）。 */
  current: string;
  /** 远端最新版本（如 2.1.0）；ok=false 时为空。 */
  latest: string;
  /** 发布页地址（打开浏览器下载用）。 */
  releaseUrl: string;
  /** 更新说明（纯文本，已截断）。 */
  notes: string;
  /** 失败原因（面向用户的中文提示）。 */
  error: string;
}

/** GitHub Releases 接口返回体（只取用到的字段）。 */
interface GhRelease {
  tag_name?: string;
  html_url?: string;
  body?: string;
}

/**
 * 检查更新（对齐上游 v1.0.2 的健壮性做法）：
 * 1. 优先请求 GitHub API `releases/latest`，网络抖动/限流自动重试；
 * 2. 仍失败则降级到 Releases Atom 订阅流（不受 API 限流影响）；
 * 3. 解析 tag 与本地版本比较，返回结构化结果交由 UI 展示。
 */
export class Updater {
  private static readonly REPO: string = 'WingedFin1251/GoTally';
  private static readonly RELEASES_PAGE: string = 'https://github.com/WingedFin1251/GoTally/releases';
  private static readonly TIMEOUT_MS: number = 8000;
  private static readonly MAX_ATTEMPTS: number = 3;
  private static readonly RETRY_DELAY_MS: number = 800;
  private static readonly TAG_RE: RegExp = /^v?(\d+)\.(\d+)\.(\d+)/;

  /** 检查更新主流程；任何异常都收敛为 ok=false 的结果，不向调用方抛出。 */
  static async check(): Promise<UpdateCheckResult> {
    const current = await AppInfo.versionName();
    const base: UpdateCheckResult = {
      ok: false, hasUpdate: false, current: current, latest: '',
      releaseUrl: `${Updater.RELEASES_PAGE}/latest`, notes: '', error: '',
    };
    if (current === '') {
      base.error = '无法读取本地版本号';
      return base;
    }
    // 1) GitHub API
    const apiUrl = `https://api.github.com/repos/${Updater.REPO}/releases/latest`;
    try {
      const text = await Updater.fetchTextWithRetry(apiUrl, 'application/vnd.github+json');
      const rel = JSON.parse(text) as GhRelease;
      const tag = rel.tag_name !== undefined ? rel.tag_name : '';
      if (tag !== '') {
        return Updater.buildResult(current, tag, rel.html_url, rel.body);
      }
    } catch (e) {
      console.error('update check via API failed: ' + (e instanceof Error ? e.message : String(e)));
    }
    // 2) 降级：Releases Atom 流
    try {
      const atom = await Updater.fetchTextWithRetry(`https://github.com/${Updater.REPO}/releases.atom`, 'application/atom+xml');
      const parsed = Updater.parseAtomLatest(atom);
      if (parsed.tag !== '') {
        return Updater.buildResult(current, parsed.tag, parsed.url, parsed.notes);
      }
      base.error = '该仓库暂无发布版本';
      return base;
    } catch (e) {
      base.error = '网络请求失败，请检查网络或稍后重试';
      return base;
    }
  }

  /** 组装结果：比较版本号并裁剪说明文本。 */
  private static buildResult(current: string, tag: string, url: string | undefined, body: string | undefined): UpdateCheckResult {
    const latest = Updater.normalizeVersion(tag);
    const notes = Updater.stripHtml(body !== undefined ? body : '').slice(0, 300);
    return {
      ok: true,
      hasUpdate: latest !== '' && Updater.compare(latest, current) > 0,
      current: current,
      latest: latest !== '' ? latest : tag,
      releaseUrl: url !== undefined && url !== '' ? url : `${Updater.RELEASES_PAGE}/latest`,
      notes: notes,
      error: '',
    };
  }

  /** 带重试的文本抓取：最多 3 次，间隔 800ms（境内直连 GitHub 常见间歇性 502/超时）。 */
  private static async fetchTextWithRetry(url: string, accept: string): Promise<string> {
    let lastMsg: string = '未知错误';
    for (let attempt = 0; attempt < Updater.MAX_ATTEMPTS; attempt++) {
      const req = http.createHttp();
      try {
        const resp = await req.request(url, {
          method: http.RequestMethod.GET,
          header: {
            'User-Agent': `GoTally/${await AppInfo.versionName()}`,
            'Accept': accept,
          },
          connectTimeout: Updater.TIMEOUT_MS,
          readTimeout: Updater.TIMEOUT_MS,
        });
        req.destroy();
        if (resp.responseCode !== 200) {
          lastMsg = `HTTP ${resp.responseCode}`;
        } else {
          return resp.result as string;
        }
      } catch (e) {
        req.destroy();
        lastMsg = e instanceof Error ? e.message : String(e);
      }
      if (attempt < Updater.MAX_ATTEMPTS - 1) {
        await Updater.sleep(Updater.RETRY_DELAY_MS);
      }
    }
    throw new Error(lastMsg);
  }

  /** 解析 Releases Atom 流中的首条 entry（最新版本）。 */
  private static parseAtomLatest(xml: string): AtomEntry {
    const entryMatch = /<entry>([\s\S]*?)<\/entry>/.exec(xml);
    if (entryMatch === null) {
      return { tag: '', url: '', notes: '' };
    }
    const entry = entryMatch[1];
    let tag = '';
    const idMatch = /<id>([^<]*)<\/id>/.exec(entry);
    if (idMatch !== null) {
      const parts = idMatch[1].split('/');
      tag = parts[parts.length - 1].trim();
    }
    let url = `${Updater.RELEASES_PAGE}/latest`;
    const linkMatch = /<link[^>]*rel="alternate"[^>]*href="([^"]+)"/.exec(entry);
    if (linkMatch !== null && linkMatch[1] !== '') {
      url = linkMatch[1];
    }
    let notes = '';
    const contentMatch = /<content[^>]*>([\s\S]*?)<\/content>/.exec(entry);
    if (contentMatch !== null) {
      notes = Updater.stripHtml(contentMatch[1]).slice(0, 300);
    }
    return { tag: tag, url: url, notes: notes };
  }

  /** 去 HTML 标签 + 还原实体 + 压缩空白。 */
  private static stripHtml(text: string): string {
    if (text === '') {
      return '';
    }
    const noTags = text.replace(/<[^>]*>/g, '');
    const unescaped = noTags
      .split('&lt;').join('<')
      .split('&gt;').join('>')
      .split('&quot;').join('"')
      .split('&#39;').join("'")
      .split('&amp;').join('&');
    return unescaped.replace(/\s+/g, ' ').trim();
  }

  /** 归一化版本号：`v2.1.0` → `2.1.0`；无法识别时返回空串。 */
  private static normalizeVersion(tag: string): string {
    const m = Updater.TAG_RE.exec(tag.trim());
    return m !== null ? `${m[1]}.${m[2]}.${m[3]}` : '';
  }

  /** 版本比较：a > b 返回正数，相等 0，小于负数。 */
  private static compare(a: string, b: string): number {
    const pa = a.split('.').map((x: string): number => Number(x));
    const pb = b.split('.').map((x: string): number => Number(x));
    for (let i = 0; i < 3; i++) {
      const va = i < pa.length && !Number.isNaN(pa[i]) ? pa[i] : 0;
      const vb = i < pb.length && !Number.isNaN(pb[i]) ? pb[i] : 0;
      if (va !== vb) {
        return va - vb;
      }
    }
    return 0;
  }

  private static sleep(ms: number): Promise<void> {
    return new Promise<void>((resolve: () => void) => {
      setTimeout(resolve, ms);
    });
  }
}

/** Atom 首条 entry 的解析结果。 */
interface AtomEntry {
  tag: string;
  url: string;
  notes: string;
}
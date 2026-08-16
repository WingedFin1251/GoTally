// entry/src/main/ets/network/OpenCodeApi.ets
import { http } from '@kit.NetworkKit';
import { Constants } from '../common/constants/Constants';
import type { QuotaWindow, QuotaResult, UsageRecord, WorkspaceRef } from '../model/UsageRecord';

const QUOTA_PATTERNS: Array<{ label: string; pctFirst: RegExp; resetFirst: RegExp }> = [
  {
    label: '5h',
    pctFirst: /rollingUsage:\s*\$R\[\d+\]\s*=\s*\{[^}]*usagePercent\s*:\s*(-?\d+(?:\.\d+)?)[^}]*resetInSec\s*:\s*(-?\d+(?:\.\d+)?)[^}]*\}/,
    resetFirst: /rollingUsage:\s*\$R\[\d+\]\s*=\s*\{[^}]*resetInSec\s*:\s*(-?\d+(?:\.\d+)?)[^}]*usagePercent\s*:\s*(-?\d+(?:\.\d+)?)[^}]*\}/,
  },
  {
    label: 'weekly',
    pctFirst: /weeklyUsage:\s*\$R\[\d+\]\s*=\s*\{[^}]*usagePercent\s*:\s*(-?\d+(?:\.\d+)?)[^}]*resetInSec\s*:\s*(-?\d+(?:\.\d+)?)[^}]*\}/,
    resetFirst: /weeklyUsage:\s*\$R\[\d+\]\s*=\s*\{[^}]*resetInSec\s*:\s*(-?\d+(?:\.\d+)?)[^}]*usagePercent\s*:\s*(-?\d+(?:\.\d+)?)[^}]*\}/,
  },
  {
    label: 'monthly',
    pctFirst: /monthlyUsage:\s*\$R\[\d+\]\s*=\s*\{[^}]*usagePercent\s*:\s*(-?\d+(?:\.\d+)?)[^}]*resetInSec\s*:\s*(-?\d+(?:\.\d+)?)[^}]*\}/,
    resetFirst: /monthlyUsage:\s*\$R\[\d+\]\s*=\s*\{[^}]*resetInSec\s*:\s*(-?\d+(?:\.\d+)?)[^}]*usagePercent\s*:\s*(-?\d+(?:\.\d+)?)[^}]*\}/,
  },
];

const WORKSPACE_ID_RE: RegExp = /wrk_[A-Za-z0-9]+/;
const WORKSPACE_ENTRY_RE: RegExp = /id\s*:\s*"(wrk_[^"]+)"[^{}]*?name\s*:\s*"([^"]*)"/g;
const RECORD_ANCHOR_RE: RegExp = /id:\s*"(usg_[^"]+)"/g;
const PLAN_RE: RegExp = /id:\s*"(usg_[^"]+)"[^}]*?enrichment:\$R\[\d+\]=\{plan:"([^"]+)"\}/g;
const CREATED_RE: RegExp = /timeCreated:\s*\$R\[\d+\]\s*=\s*new Date\("([^"]+)"\)/;

function clampPercent(v: number): number {
  return Math.max(0, Math.min(100, v));
}

function parseNumField(body: string, name: string): number {
  const re = new RegExp(`${name}:\\s*(\\d+|null)`);
  const m = re.exec(body);
  if (m === null) {
    return 0;
  }
  if (m[1] === 'null') {
    return 0;
  }
  const n = Number(m[1]);
  return Number.isNaN(n) ? 0 : n;
}

function parseStrField(body: string, name: string): string {
  const re = new RegExp(`${name}:\\s*"([^"]*)"`);
  const m = re.exec(body);
  return m !== null ? m[1] : '';
}

/** OpenCode Go API 客户端：配额/用量/工作区，含网络与纯解析。 */
export class OpenCodeApi {

  // ---------- 纯解析（可单测） ----------

  static buildCookieHeader(token: string): string {
    let cookie = token.trim();
    if (cookie.toLowerCase().startsWith('cookie:')) {
      cookie = cookie.substring(7).trim();
    }
    if (cookie === '') {
      return '';
    }
    const parts = cookie.split(';');
    for (const part of parts) {
      const p = part.trim();
      if (p.startsWith('auth=')) {
        return p;
      }
    }
    return `auth=${cookie}`;
  }

  static buildLoginUrl(): string {
    const state = Date.now().toString(36) + Math.floor(Math.random() * 1e9).toString(36);
    return `${Constants.LOGIN_BASE}?client_id=${Constants.LOGIN_CLIENT_ID}` +
      `&redirect_uri=${encodeURIComponent(Constants.LOGIN_REDIRECT_URI)}` +
      `&response_type=code&state=${state}`;
  }

  static extractWorkspaceId(hint: string): string {
    const value = hint.trim();
    if (value.startsWith('wrk_') && value.length > 4) {
      return value;
    }
    const m = WORKSPACE_ID_RE.exec(value);
    return m !== null ? m[0] : '';
  }

  static parseQuotaHtml(html: string, nowIso: string): QuotaWindow[] {
    const nowMs = Date.parse(nowIso);
    const windows: QuotaWindow[] = [];
    for (const pattern of QUOTA_PATTERNS) {
      let match = pattern.pctFirst.exec(html);
      let used: number;
      let resetIn: number;
      if (match !== null) {
        used = Number(match[1]);
        resetIn = Number(match[2]);
      } else {
        match = pattern.resetFirst.exec(html);
        if (match === null) {
          continue;
        }
        used = Number(match[2]);
        resetIn = Number(match[1]);
      }
      used = clampPercent(used);
      resetIn = Math.max(0, Math.floor(resetIn));
      const resetAt = new Date(nowMs + resetIn * 1000).toISOString();
      windows.push({
        label: pattern.label,
        used: used,
        remaining: Number((100 - used).toFixed(1)),
        total: 100,
        unit: '%',
        resetAt: resetAt,
        resetInSec: resetIn,
      });
    }
    return windows;
  }

  static parseWorkspaceRefs(text: string): WorkspaceRef[] {
    const refs: WorkspaceRef[] = [];
    const seen = new Set<string>();
    let m = WORKSPACE_ENTRY_RE.exec(text);
    while (m !== null) {
      const id = m[1];
      const name = m[2].trim();
      if (!seen.has(id)) {
        seen.add(id);
        refs.push({ id: id, name: name });
      }
      m = WORKSPACE_ENTRY_RE.exec(text);
    }
    return refs;
  }

  static parseUsageResponse(text: string): UsageRecord[] {
    const plans = new Map<string, string>();
    let pm = PLAN_RE.exec(text);
    while (pm !== null) {
      plans.set(pm[1], pm[2]);
      pm = PLAN_RE.exec(text);
    }
    const anchors: Array<{ id: string; start: number }> = [];
    let am = RECORD_ANCHOR_RE.exec(text);
    while (am !== null) {
      anchors.push({ id: am[1], start: am.index });
      am = RECORD_ANCHOR_RE.exec(text);
    }
    const records: UsageRecord[] = [];
    for (let i = 0; i < anchors.length; i++) {
      const anchor = anchors[i];
      const end = i + 1 < anchors.length ? anchors[i + 1].start : text.length;
      const body = text.substring(anchor.start, end);
      const created = CREATED_RE.exec(body);
      if (created === null) {
        continue;
      }
      records.push({
        usgId: anchor.id,
        createdAt: created[1],
        model: parseStrField(body, 'model'),
        provider: parseStrField(body, 'provider'),
        inputTokens: parseNumField(body, 'inputTokens'),
        outputTokens: parseNumField(body, 'outputTokens'),
        reasoningTokens: parseNumField(body, 'reasoningTokens'),
        cacheReadTokens: parseNumField(body, 'cacheReadTokens'),
        cacheWrite5mTokens: parseNumField(body, 'cacheWrite5mTokens'),
        cacheWrite1hTokens: parseNumField(body, 'cacheWrite1hTokens'),
        costRaw: parseNumField(body, 'cost'),
        costUsd: parseNumField(body, 'cost') / 100000000,
        keyId: parseStrField(body, 'keyID'),
        sessionId: parseStrField(body, 'sessionID'),
        plan: plans.get(anchor.id) ?? '',
        syncedAt: '',
      });
    }
    return records;
  }

  // ---------- 网络 ----------

  static async fetchWorkspaceRefs(token: string): Promise<WorkspaceRef[]> {
    const cookie = OpenCodeApi.buildCookieHeader(token);
    if (cookie === '') {
      throw new Error('token 为空');
    }
    const url = `https://opencode.ai/_server?id=${encodeURIComponent(Constants.WORKSPACE_SERVER_ID)}`;
    const text = await OpenCodeApi.fetchText(url, cookie, Constants.WORKSPACE_SERVER_ID, 'https://opencode.ai');
    const refs = OpenCodeApi.parseWorkspaceRefs(text);
    if (refs.length === 0) {
      throw new Error('无法从账号数据解析工作区 ID');
    }
    return refs;
  }

  static async resolveWorkspaceId(hint: string, token: string): Promise<string> {
    const direct = OpenCodeApi.extractWorkspaceId(hint);
    if (direct !== '') {
      return direct;
    }
    const refs = await OpenCodeApi.fetchWorkspaceRefs(token);
    const hintL = hint.trim().toLowerCase();
    for (const ref of refs) {
      if (ref.id.toLowerCase() === hintL || ref.name.toLowerCase() === hintL) {
        return ref.id;
      }
    }
    return refs[0].id;
  }

  static async fetchQuota(token: string, workspaceHint: string): Promise<QuotaResult> {
    const updatedAt = new Date().toISOString();
    const hint = (workspaceHint.trim() === '' ? 'Default' : workspaceHint.trim());
    if (token.trim() === '') {
      return { name: 'Default', workspaceId: hint, success: false, updatedAt: updatedAt, windows: [], error: '未配置 token' };
    }
    try {
      const workspaceId = await OpenCodeApi.resolveWorkspaceId(hint, token);
      const cookie = OpenCodeApi.buildCookieHeader(token);
      const url = `${Constants.DASHBOARD_BASE}/${encodeURIComponent(workspaceId)}/go`;
      const html = await OpenCodeApi.fetchText(url, cookie, '', 'https://opencode.ai');
      const windows = OpenCodeApi.parseQuotaHtml(html, new Date().toISOString());
      if (windows.length === 0) {
        throw new Error('无法从 Dashboard HTML 解析额度数据');
      }
      return { name: 'Default', workspaceId: workspaceId, success: true, updatedAt: updatedAt, windows: windows, error: '' };
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      return { name: 'Default', workspaceId: hint, success: false, updatedAt: updatedAt, windows: [], error: msg };
    }
  }

  static async fetchUsagePage(token: string, workspaceId: string, page: number = 0, keyId: string = ''): Promise<UsageRecord[]> {
    const args: string[] = [workspaceId];
    if (keyId !== '') {
      if (page > 0) {
        args.push(`${page}`, keyId);
      } else {
        args.push(keyId);
      }
    } else if (page > 0) {
      args.push(`${page}`);
    }
    const url = `https://opencode.ai/_server?id=${encodeURIComponent(Constants.DEFAULT_USAGE_SERVER_ID)}` +
      `&args=${encodeURIComponent(JSON.stringify(args))}`;
    const cookie = OpenCodeApi.buildCookieHeader(token);
    const text = await OpenCodeApi.fetchText(
      url, cookie, Constants.DEFAULT_USAGE_SERVER_ID, `/workspace/${workspaceId}/usage`);
    return OpenCodeApi.parseUsageResponse(text);
  }

  static async fetchUsdCny(): Promise<number> {
    try {
      const req = http.createHttp();
      const resp = await req.request(Constants.EXCHANGE_URL, {
        method: http.RequestMethod.GET,
        header: { 'Accept': 'application/json' },
        connectTimeout: 10000,
        readTimeout: 10000,
      });
      req.destroy();
      if (resp.responseCode !== 200) {
        return Constants.DEFAULT_USD_CNY;
      }
      const data = JSON.parse(resp.result as string) as Record<string, Object>;
      const rates = data['rates'] as Record<string, Object>;
      const cny = Number(rates['CNY'] ?? 0);
      return cny > 0 ? cny : Constants.DEFAULT_USD_CNY;
    } catch (e) {
      return Constants.DEFAULT_USD_CNY;
    }
  }

  private static async fetchText(url: string, cookie: string, serverId: string, referer: string): Promise<string> {
    if (cookie === '') {
      throw new Error('token 为空');
    }
    let lastErr: Error = new Error('未知错误');
    for (let attempt = 0; attempt < Constants.RETRY_BACKOFF_MS.length; attempt++) {
      try {
        const req = http.createHttp();
        const header: Record<string, string> = {
          'Cookie': cookie,
          'X-Server-Instance': `server-fn:${Date.now()}`,
          'User-Agent': Constants.USER_AGENT,
          'Origin': 'https://opencode.ai',
          'Accept': 'text/javascript, application/json;q=0.9, */*;q=0.8',
        };
        if (serverId !== '') {
          header['X-Server-Id'] = serverId;
        }
        if (referer !== '') {
          header['Referer'] = referer.startsWith('http') ? referer : `https://opencode.ai${referer}`;
        }
        const resp = await req.request(url, {
          method: http.RequestMethod.GET,
          header: header,
          connectTimeout: Constants.REQUEST_TIMEOUT_MS,
          readTimeout: Constants.REQUEST_TIMEOUT_MS,
        });
        req.destroy();
        const code = resp.responseCode;
        if (code === 401 || code === 403) {
          throw new Error(`认证失败 (HTTP ${code})，请重新登录`);
        }
        if (code === 404) {
          throw new Error('工作区不存在 (HTTP 404)');
        }
        if (code < 200 || code >= 300) {
          throw new Error(`请求返回 HTTP ${code}`);
        }
        return resp.result as string;
      } catch (e) {
        lastErr = e instanceof Error ? e : new Error(String(e));
        if (lastErr.message.includes('认证失败') || lastErr.message.includes('HTTP 404')) {
          throw lastErr;
        }
        if (attempt < Constants.RETRY_BACKOFF_MS.length - 1) {
          await OpenCodeApi.sleep(Constants.RETRY_BACKOFF_MS[attempt]);
        }
      }
    }
    throw lastErr;
  }

  private static sleep(ms: number): Promise<void> {
    return new Promise<void>((resolve) => {
      setTimeout(resolve, ms);
    });
  }
}

// entry/src/main/ets/network/OpenCodeApi.ets
import { http } from '@kit.NetworkKit';
import { Constants } from '../common/constants/Constants';
import { WebCookies } from '../common/utils/WebCookies';
import { ExchangeRate } from '../common/utils/ExchangeRate';
import { ConsoleSnapshotStore } from '../data/ConsoleSnapshotStore';
import type { QuotaWindow, QuotaResult, UsageRecord, WorkspaceRef } from '../model/UsageRecord';
import type { KeyNamePair } from '../model/Stats';

/** 官方 /zen/go/v1/usage 单个窗口（percent = 已用百分比）。 */
interface GoUsageWindow {
  status?: string;
  percent?: number;
  resetsAt?: string;
}

/** /console/api/request-logs 的单条请求（只取所需字段；数字可能与字符串混用）。 */
interface ConsoleLogItem {
  id?: string;
  startedAt?: number | string;
  category?: string;
  model?: string | null;
  provider?: string | null;
  sessionID?: string | null;
  serviceAPIKeyID?: string | null;
  product?: string | null;
  inputTokens?: number | string;
  outputTokens?: number | string;
  reasoningTokens?: number | string;
  cacheReadTokens?: number | string;
  cacheWriteTokens?: number | string;
  cost?: number | string;
}

interface ConsoleLogsResponse {
  items?: ConsoleLogItem[];
  nextCursor?: string;
  retentionDays?: number | string;
}

/** /console/api/request-logs 的一页结果。 */
export interface ConsoleUsagePage {
  records: UsageRecord[];
  nextCursor: string;
  /** 服务端明细保留天数（实测 30）。 */
  retentionDays: number;
}

/** /console/api/service-accounts 的 Key 条目。 */
interface ServiceAccountEntry {
  keys?: ServiceAccountKey[];
}

interface ServiceAccountKey {
  id?: string;
  name?: string;
}

interface ServiceAccountsResponse {
  items?: ServiceAccountEntry[];
}

interface GoUsageBlock {
  rolling?: GoUsageWindow;
  weekly?: GoUsageWindow;
  monthly?: GoUsageWindow;
}

interface GoUsageResponse {
  usage?: GoUsageBlock;
}

/** 控制台 /console/api/go/status 单个 meter（金额单位：微分，1e-8 美元）。 */
interface ConsoleMeter {
  resetsAt?: string;
  limitMicroCents?: number;
  usedMicroCents?: number;
}

interface ConsoleMeters {
  fiveHour?: ConsoleMeter;
  week?: ConsoleMeter;
  month?: ConsoleMeter;
}

interface ConsoleAccess {
  meters?: ConsoleMeters;
}

interface ConsoleStatusResponse {
  access?: ConsoleAccess;
}

/** 控制台 /console/api/orgs 返回项。 */
interface ConsoleOrg {
  id?: string;
  name?: string;
}

interface QuotaPattern {
  label: string;
  pctFirst: RegExp;
  resetFirst: RegExp;
}

interface AnchorPoint {
  id: string;
  start: number;
}

const QUOTA_PATTERNS: QuotaPattern[] = [
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
/** keys 页面内嵌数据形如 {id:"key_xxx",name:"gongsi",...}（对齐上游 v1.0.2）。 */
const KEY_ENTRY_RE: RegExp = /\{id:"(key_[A-Za-z0-9]+)",name:"([^"]*)"/;
/** 合法 cookie 名字符集（用于判断传入凭据是否已是完整的 name=value 串）。 */
const COOKIE_NAME_RE: RegExp = /^[A-Za-z0-9_.-]+$/;

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

/** 归一化 ISO 时间：缺时区标记时按 UTC 处理（补 Z），保证展示与统计统一换算为设备本地时区。 */
export function normalizeIso(iso: string): string {
  const t = iso.trim();
  if (t === '') {
    return t;
  }
  return /(?:Z|[+-]\d{2}:\d{2})$/.test(t) ? t : `${t}Z`;
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
    // 已含 cookie 名（name=value）→ 原样发送全部 cookie。
    // 兼容凭据命名变化（历史上是 auth=，现在可能是控制台会话 cookie 等）。
    for (const part of cookie.split(';')) {
      const p = part.trim();
      const eq = p.indexOf('=');
      if (eq > 0 && COOKIE_NAME_RE.test(p.substring(0, eq))) {
        return cookie;
      }
    }
    // 仅有裸值：`Fe26...` 是旧版 auth cookie，其余按新版控制台会话 cookie 处理
    if (cookie.startsWith('Fe26')) {
      return `auth=${cookie}`;
    }
    return `${Constants.CONSOLE_COOKIE_NAME}=${cookie}`;
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
    const anchors: AnchorPoint[] = [];
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
      const costRaw = parseNumField(body, 'cost');
      records.push({
        usgId: anchor.id,
        createdAt: normalizeIso(created[1]),
        model: parseStrField(body, 'model'),
        provider: parseStrField(body, 'provider'),
        inputTokens: parseNumField(body, 'inputTokens'),
        outputTokens: parseNumField(body, 'outputTokens'),
        reasoningTokens: parseNumField(body, 'reasoningTokens'),
        cacheReadTokens: parseNumField(body, 'cacheReadTokens'),
        cacheWrite5mTokens: parseNumField(body, 'cacheWrite5mTokens'),
        cacheWrite1hTokens: parseNumField(body, 'cacheWrite1hTokens'),
        costRaw: costRaw,
        costUsd: costRaw / 100000000,
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
    // 新登录方式（控制台会话）优先：cookie 里已没有 auth，旧 server-fn 会 302 跳登录
    try {
      const cookie = OpenCodeApi.consoleCookie(token);
      const orgs = await OpenCodeApi.fetchConsoleOrgs(cookie);
      if (orgs.length > 0) {
        const hintL = hint.trim().toLowerCase();
        for (const o of orgs) {
          if (o.id.toLowerCase() === hintL || o.name.toLowerCase() === hintL) {
            return o.id;
          }
        }
        return orgs[0].id;
      }
    } catch (e) {
      console.error('resolveWorkspaceId via console orgs failed: ' + (e instanceof Error ? e.message : String(e)));
    }
    // 旧登录方式（auth cookie）兜底：工作区列表 server-fn
    const refs = await OpenCodeApi.fetchWorkspaceRefs(token);
    const hintL = hint.trim().toLowerCase();
    for (const ref of refs) {
      if (ref.id.toLowerCase() === hintL || ref.name.toLowerCase() === hintL) {
        return ref.id;
      }
    }
    return refs[0].id;
  }

  /**
   * 控制台工作区列表：`GET /console/api/orgs`（会话 cookie 鉴权）。
   * 新登录方式下这是获取工作区 ID 的唯一可靠来源。
   */
  static async fetchConsoleOrgs(cookie: string): Promise<WorkspaceRef[]> {
    if (cookie === '') {
      return [];
    }
    const header: Record<string, string> = {
      'Cookie': cookie,
      'Accept': 'application/json',
      'User-Agent': Constants.USER_AGENT,
      'Origin': Constants.OPENCODE_ORIGIN,
      'Referer': `${Constants.OPENCODE_ORIGIN}/console`,
    };
    const text = await OpenCodeApi.fetchJson(`${Constants.OPENCODE_ORIGIN}/console/api/orgs`, header);
    const arr = JSON.parse(text) as ConsoleOrg[];
    const out: WorkspaceRef[] = [];
    for (const o of arr) {
      const id = o.id !== undefined ? o.id : '';
      if (id !== '') {
        out.push({ id: id, name: o.name !== undefined ? o.name : '' });
      }
    }
    return out;
  }

  /**
   * 拉取配额（三级数据源，逐级降级）：
   * ① 官方 API Key 接口 `GET /zen/go/v1/usage`（最稳，无需 cookie，仅百分比+重置时间）
   * ② 控制台 JSON 接口 `GET /console/api/go/status`（cookie 鉴权，**额外提供真实金额**）
   * ③ Dashboard HTML 解析（兜底，原有实现）
   *
   * @param token 登录 cookie 串（auth=…）
   * @param workspaceHint 工作区提示（Default/wrk_…）
   * @param goApiKey 可选的 OpenCode Go API Key；填写后优先走官方接口
   */
  static async fetchQuota(token: string, workspaceHint: string, goApiKey: string = ''): Promise<QuotaResult> {
    const updatedAt = new Date().toISOString();
    const hint = (workspaceHint.trim() === '' ? 'Default' : workspaceHint.trim());
    const errors: string[] = [];

    // ① 官方 API Key 接口
    if (goApiKey.trim() !== '') {
      try {
        const windows = await OpenCodeApi.fetchQuotaOfficial(goApiKey);
        if (windows.length > 0) {
          await ConsoleSnapshotStore.saveQuota(windows);
          return {
            name: 'Default', workspaceId: hint, success: true, updatedAt: updatedAt,
            windows: windows, error: '', source: 'official',
          };
        }
        errors.push('官方接口: 未返回额度数据');
      } catch (e) {
        errors.push('官方接口: ' + (e instanceof Error ? e.message : String(e)));
      }
    }

    if (token.trim() === '') {
      return {
        name: 'Default', workspaceId: hint, success: false, updatedAt: updatedAt, windows: [],
        error: errors.length > 0 ? errors.join('；') : '未配置 token', source: '',
      };
    }

    let workspaceId = hint;
    try {
      workspaceId = await OpenCodeApi.resolveWorkspaceId(hint, token);
    } catch (e) {
      errors.push('工作区解析: ' + (e instanceof Error ? e.message : String(e)));
    }

    // ② 控制台 JSON 接口（cookie 鉴权，含金额）
    try {
      const consoleCookie = OpenCodeApi.consoleCookie(token);
      const windows = await OpenCodeApi.fetchQuotaConsole(consoleCookie, workspaceId);
      if (windows.length > 0) {
        await ConsoleSnapshotStore.saveQuota(windows);
        return {
          name: 'Default', workspaceId: workspaceId, success: true, updatedAt: updatedAt,
          windows: windows, error: '', source: 'console',
        };
      }
      errors.push('控制台接口: 未返回额度数据');
    } catch (e) {
      errors.push('控制台接口: ' + (e instanceof Error ? e.message : String(e)));
    }

    // ③ Dashboard HTML 解析兜底
    try {
      const cookie = OpenCodeApi.buildCookieHeader(token);
      const url = `${Constants.DASHBOARD_BASE}/${encodeURIComponent(workspaceId)}/go`;
      const html = await OpenCodeApi.fetchText(url, cookie, '', Constants.OPENCODE_ORIGIN);
      const windows = OpenCodeApi.parseQuotaHtml(html, new Date().toISOString());
      if (windows.length === 0) {
        throw new Error('无法从 Dashboard HTML 解析额度数据');
      }
      await ConsoleSnapshotStore.saveQuota(windows);
      return {
        name: 'Default', workspaceId: workspaceId, success: true, updatedAt: updatedAt,
        windows: windows, error: '', source: 'html',
      };
    } catch (e) {
      errors.push('页面解析: ' + (e instanceof Error ? e.message : String(e)));
    }

    // ④ 全部数据源失败：回退本地快照（离线也能看到上次的配额与金额）
    const cached = await ConsoleSnapshotStore.loadQuota();
    if (cached.length > 0) {
      return {
        name: 'Default', workspaceId: workspaceId, success: true, updatedAt: updatedAt,
        windows: cached, error: errors.join('；'), source: 'snapshot',
      };
    }
    return {
      name: 'Default', workspaceId: workspaceId, success: false, updatedAt: updatedAt, windows: [],
      error: errors.join('；'), source: '',
    };
  }

  /** 官方用量接口：`GET /zen/go/v1/usage` + `Authorization: Bearer <API Key>`。 */
  static async fetchQuotaOfficial(apiKey: string): Promise<QuotaWindow[]> {
    const key = apiKey.trim();
    if (key === '') {
      return [];
    }
    const header: Record<string, string> = {
      'Authorization': `Bearer ${key}`,
      'Accept': 'application/json',
      'User-Agent': Constants.USER_AGENT,
    };
    const text = await OpenCodeApi.fetchJson(Constants.GO_USAGE_URL, header);
    return OpenCodeApi.parseOfficialUsage(text, new Date().toISOString());
  }

  /**
   * 解析官方 `/zen/go/v1/usage` 响应：`{ usage: { rolling, weekly, monthly } }`，
   * 每窗口 `percent`（已用百分比）+ `resetsAt`（ISO）。纯函数，便于单测锁定字段契约。
   */
  static parseOfficialUsage(text: string, nowIso: string): QuotaWindow[] {
    const nowMs = Date.parse(nowIso);
    const data = JSON.parse(text) as GoUsageResponse;
    const block = data.usage;
    if (block === undefined) {
      return [];
    }
    const out: QuotaWindow[] = [];
    const rolling = OpenCodeApi.windowFromPercent('5h', block.rolling, nowMs);
    if (rolling !== null) {
      out.push(rolling);
    }
    const weekly = OpenCodeApi.windowFromPercent('weekly', block.weekly, nowMs);
    if (weekly !== null) {
      out.push(weekly);
    }
    const monthly = OpenCodeApi.windowFromPercent('monthly', block.monthly, nowMs);
    if (monthly !== null) {
      out.push(monthly);
    }
    return out;
  }

  /**
   * 控制台 JSON 接口：`GET /console/api/go/status` + cookie + `x-org-id: wrk_…`。
   * 金额字段单位为微分（1e-8 美元），据此换算百分比与美元金额。
   */
  static async fetchQuotaConsole(cookie: string, workspaceId: string): Promise<QuotaWindow[]> {
    const ws = workspaceId.trim();
    if (cookie === '' || ws === '') {
      return [];
    }
    const header: Record<string, string> = {
      'Cookie': cookie,
      'x-org-id': ws,
      'Accept': 'application/json',
      'User-Agent': Constants.USER_AGENT,
      'Origin': Constants.OPENCODE_ORIGIN,
      'Referer': `${Constants.OPENCODE_ORIGIN}/console/${ws}/go`,
    };
    const text = await OpenCodeApi.fetchJson(Constants.CONSOLE_GO_STATUS_URL, header);
    return OpenCodeApi.parseConsoleStatus(text, new Date().toISOString());
  }

  /**
   * 解析控制台 `/console/api/go/status` 响应：
   * `{ access: { meters: { fiveHour, week, month } } }`，每 meter 含 resetsAt/limitMicroCents/usedMicroCents。
   */
  static parseConsoleStatus(text: string, nowIso: string): QuotaWindow[] {
    const nowMs = Date.parse(nowIso);
    const data = JSON.parse(text) as ConsoleStatusResponse;
    const access = data.access;
    const meters = access !== undefined ? access.meters : undefined;
    if (meters === undefined) {
      return [];
    }
    const out: QuotaWindow[] = [];
    const fiveHour = OpenCodeApi.windowFromMeter('5h', meters.fiveHour, nowMs);
    if (fiveHour !== null) {
      out.push(fiveHour);
    }
    const week = OpenCodeApi.windowFromMeter('weekly', meters.week, nowMs);
    if (week !== null) {
      out.push(week);
    }
    const month = OpenCodeApi.windowFromMeter('monthly', meters.month, nowMs);
    if (month !== null) {
      out.push(month);
    }
    return out;
  }

  /** 控制台接口所需 cookie：优先取 WebView 中的控制台会话 cookie，退回登录 token。 */
  private static consoleCookie(token: string): string {
    const session = WebCookies.read(Constants.CONSOLE_COOKIE_NAME, Constants.OPENCODE_ORIGIN);
    if (session !== '') {
      return `${Constants.CONSOLE_COOKIE_NAME}=${session}`;
    }
    return OpenCodeApi.buildCookieHeader(token);
  }

  /** 官方接口窗口 → QuotaWindow（仅百分比与重置时间）。 */
  private static windowFromPercent(label: string, w: GoUsageWindow | undefined, nowMs: number): QuotaWindow | null {
    if (w === undefined || w.percent === undefined) {
      return null;
    }
    const pct = clampPercent(Number(w.percent));
    const iso = w.resetsAt !== undefined ? w.resetsAt : '';
    return {
      label: label,
      used: pct,
      remaining: Number((100 - pct).toFixed(1)),
      total: 100,
      unit: '%',
      resetAt: iso,
      resetInSec: iso !== '' ? OpenCodeApi.secondsUntil(iso, nowMs) : 0,
    };
  }

  /** 控制台 meter → QuotaWindow（已用/限额，单位微分 → 美元），限额缺失时返回 null。 */
  private static windowFromMeter(label: string, meter: ConsoleMeter | undefined, nowMs: number): QuotaWindow | null {
    if (meter === undefined) {
      return null;
    }
    const limit = meter.limitMicroCents !== undefined ? meter.limitMicroCents : 0;
    if (limit <= 0) {
      return null;
    }
    const usedRaw = meter.usedMicroCents !== undefined ? meter.usedMicroCents : 0;
    // 保留一位小数，保证「已用 + 剩余 = 100」且展示稳定
    const pct = Number(clampPercent((usedRaw / limit) * 100).toFixed(1));
    const iso = meter.resetsAt !== undefined ? meter.resetsAt : '';
    return {
      label: label,
      used: pct,
      remaining: Number((100 - pct).toFixed(1)),
      total: 100,
      unit: '%',
      resetAt: iso,
      resetInSec: iso !== '' ? OpenCodeApi.secondsUntil(iso, nowMs) : 0,
      usedUsd: Number((usedRaw / 1e8).toFixed(4)),
      limitUsd: Number((limit / 1e8).toFixed(2)),
    };
  }

  /** ISO 时间 → 距参考时刻的秒数（无效或已过期归零）。 */
  private static secondsUntil(iso: string, nowMs: number): number {
    const t = Date.parse(iso);
    if (Number.isNaN(t)) {
      return 0;
    }
    return Math.max(0, Math.floor((t - nowMs) / 1000));
  }

  /**
   * 拉取工作区 API Key 名称映射（对齐上游 v1.0.2 fetch_key_names）。
   * keys 页面内嵌响应数据形如 {id:"key_xxx",name:"gongsi",...}，正则提取 id 与 name 即可获得显示名。
   * 页面结构变化或网络失败时返回空数组，不影响主流程（既有缓存保持不变）。
   */
  static async fetchKeyNames(token: string, workspaceId: string): Promise<KeyNamePair[]> {
    const cookie = OpenCodeApi.buildCookieHeader(token);
    const ws = workspaceId.trim();
    if (cookie === '' || ws === '') {
      return [];
    }
    // 控制台会话（工作区为 wrk_xxx）：优先 JSON 接口，失败再退回 HTML 抓取
    if (ws.startsWith('wrk_')) {
      const fromJson = await OpenCodeApi.fetchKeyNamesConsole(token, ws);
      if (fromJson.length > 0) {
        return fromJson;
      }
    }
    const url = `https://opencode.ai/workspace/${encodeURIComponent(ws)}/keys`;
    try {
      const html = await OpenCodeApi.fetchText(url, cookie, '', `/workspace/${ws}/keys`);
      const out: KeyNamePair[] = [];
      const seen = new Set<string>();
      const re = new RegExp(KEY_ENTRY_RE.source, 'g');
      let m = re.exec(html);
      while (m !== null) {
        const id = m[1];
        const name = m[2].trim();
        if (id !== '' && name !== '' && !seen.has(id)) {
          seen.add(id);
          out.push({ keyId: id, name: name });
        }
        m = re.exec(html);
      }
      return out;
    } catch (e) {
      console.error('fetchKeyNames failed: ' + (e instanceof Error ? e.message : String(e)));
      return [];
    }
  }

  /**
   * 控制台逐条明细：`GET /console/api/request-logs`（游标分页，服务端保留 30 天）。
   *
   * 背景：2026-09 控制台改版后旧的 `/_server` 明细 server-fn 失效，但该接口可用，
   * 且给出每条请求的 model / provider / sessionID / Key / tokens（含推理）/ cost，
   * 因此记录页明细、会话数、逐小时趋势、Key 归属都能恢复正常。
   */
  static async fetchConsoleUsagePage(token: string, orgId: string, cursor: string,
    limit: number, sinceMs: number): Promise<ConsoleUsagePage> {
    const size = Math.max(1, Math.min(limit, Constants.CONSOLE_LOGS_MAX_LIMIT));
    let url = `${Constants.OPENCODE_ORIGIN}/console/api/request-logs?limit=${size}`;
    if (cursor !== '') {
      url += `&cursor=${encodeURIComponent(cursor)}`;
    }
    if (sinceMs > 0) {
      url += `&since=${Math.floor(sinceMs)}`;
    }
    const text = await OpenCodeApi.fetchJson(url, OpenCodeApi.consoleHeaders(token, orgId));
    return OpenCodeApi.parseConsoleRequestLogs(text);
  }

  /** 控制台接口请求头：会话 cookie + `x-org-id`（工作区）。 */
  private static consoleHeaders(token: string, orgId: string): Record<string, string> {
    const headers: Record<string, string> = {
      'Cookie': OpenCodeApi.buildCookieHeader(token),
      'Accept': 'application/json',
      'User-Agent': Constants.DESKTOP_USER_AGENT,
      'Origin': Constants.OPENCODE_ORIGIN,
      'Referer': `${Constants.OPENCODE_ORIGIN}/console/`,
    };
    if (orgId.trim() !== '') {
      headers['x-org-id'] = orgId.trim();
    }
    return headers;
  }

  /**
   * 解析 `/console/api/request-logs` 响应（纯函数，便于回归测试）。
   *
   * 只保留 `category === "inference"` 的推理请求 —— 另一类 `"api"` 是控制台
   * 自身的接口调用，不计入用量（若混入会虚增请求数与成本）。
   */
  static parseConsoleRequestLogs(body: string): ConsoleUsagePage {
    const records: UsageRecord[] = [];
    let nextCursor = '';
    let retentionDays = 0;
    try {
      const data = JSON.parse(body) as ConsoleLogsResponse;
      const items = data.items;
      if (items !== undefined) {
        const now = new Date().toISOString();
        for (const it of items) {
          const category = it.category !== undefined ? it.category : '';
          if (category !== 'inference') {
            continue;
          }
          const id = it.id !== undefined ? it.id : '';
          const startedAt = OpenCodeApi.numOr0(it.startedAt);
          if (id === '' || startedAt <= 0) {
            continue;
          }
          const costUsd = OpenCodeApi.numOf(it.cost);
          records.push({
            usgId: id,
            createdAt: new Date(startedAt).toISOString(),
            model: OpenCodeApi.strOf(it.model),
            provider: OpenCodeApi.strOf(it.provider),
            inputTokens: OpenCodeApi.numOr0(it.inputTokens),
            outputTokens: OpenCodeApi.numOr0(it.outputTokens),
            reasoningTokens: OpenCodeApi.numOr0(it.reasoningTokens),
            cacheReadTokens: OpenCodeApi.numOr0(it.cacheReadTokens),
            // 新接口不再区分 5m/1h 缓存写入，合计口径不变
            cacheWrite5mTokens: OpenCodeApi.numOr0(it.cacheWriteTokens),
            cacheWrite1hTokens: 0,
            costRaw: Math.round(costUsd * 1e8),
            costUsd: costUsd,
            keyId: OpenCodeApi.strOf(it.serviceAPIKeyID),
            sessionId: OpenCodeApi.strOf(it.sessionID),
            plan: OpenCodeApi.strOf(it.product),
            syncedAt: now,
          });
        }
      }
      if (data.nextCursor !== undefined && data.nextCursor !== null) {
        nextCursor = data.nextCursor;
      }
      retentionDays = OpenCodeApi.numOr0(data.retentionDays);
    } catch (e) {
      console.error('parseConsoleRequestLogs failed: ' + (e instanceof Error ? e.message : String(e)));
    }
    return { records: records, nextCursor: nextCursor, retentionDays: retentionDays };
  }

  /** 控制台 Key 名称：`GET /console/api/service-accounts`（JSON，优于 HTML 抓取）。 */
  static async fetchKeyNamesConsole(token: string, orgId: string): Promise<KeyNamePair[]> {
    const out: KeyNamePair[] = [];
    if (orgId.trim() === '') {
      return out;
    }
    try {
      const url = `${Constants.OPENCODE_ORIGIN}/console/api/service-accounts`;
      const text = await OpenCodeApi.fetchJson(url, OpenCodeApi.consoleHeaders(token, orgId));
      const data = JSON.parse(text) as ServiceAccountsResponse;
      const items = data.items;
      if (items === undefined) {
        return out;
      }
      const seen = new Set<string>();
      for (const entry of items) {
        const keys = entry.keys;
        if (keys === undefined) {
          continue;
        }
        for (const k of keys) {
          const id = k.id !== undefined ? k.id : '';
          const name = k.name !== undefined ? k.name.trim() : '';
          if (id !== '' && name !== '' && !seen.has(id)) {
            seen.add(id);
            out.push({ keyId: id, name: name });
          }
        }
      }
    } catch (e) {
      console.error('fetchKeyNamesConsole failed: ' + (e instanceof Error ? e.message : String(e)));
    }
    return out;
  }

  /** 字符串兜底：接口可能返回 null，统一成空串（DB 里 model 等列是 NOT NULL）。 */
  private static strOf(v: string | null | undefined): string {
    return v === undefined || v === null ? '' : v;
  }

  /** 数值兜底：接口可能返回数字或数字字符串，统一转成 number。 */
  private static numOf(v: number | string | undefined): number {
    if (v === undefined || v === null) {
      return 0;
    }
    const n = typeof v === 'number' ? v : Number(v);
    return Number.isFinite(n) ? n : 0;
  }

  private static numOr0(v: number | string | undefined): number {
    return OpenCodeApi.numOf(v);
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
    // 新登录方式（控制台会话）下官方已更换鉴权，旧明细接口会重定向到登录页或返回未授权错误。
    // 这里给出明确原因，避免「同步成功但 0 条」的误导。
    const head = text.substring(0, 200);
    if (head.includes('/auth/authorize') || text.includes('not associated with an account') ||
      head.startsWith('<!DOCTYPE') || head.startsWith('<html')) {
      throw new Error('当前登录方式无法读取明细（OpenCode 已更换接口），配额仍可正常显示');
    }
    return OpenCodeApi.parseUsageResponse(text);
  }

  /**
   * USD→CNY 汇率（带 6 小时 TTL 缓存）。
   *
   * 命中缓存直接返回（各页面进入时不再各拉一次）；未命中才请求，
   * 请求失败时优先复用旧缓存，最后才回退 `DEFAULT_USD_CNY`。
   */
  static async fetchUsdCny(): Promise<number> {
    const now = Date.now();
    const cached = ExchangeRate.cached();
    if (!ExchangeRate.shouldFetch(now)) {
      return cached;
    }
    let fetched = 0;
    const req = http.createHttp();
    try {
      const resp = await req.request(Constants.EXCHANGE_URL, {
        method: http.RequestMethod.GET,
        header: { 'Accept': 'application/json' },
        connectTimeout: 10000,
        readTimeout: 10000,
      });
      req.destroy();
      if (resp.responseCode === 200) {
        const data = JSON.parse(resp.result as string) as Record<string, Object>;
        const rates = data['rates'] as Record<string, Object>;
        fetched = Number(rates['CNY'] ?? 0);
      }
    } catch (e) {
      req.destroy();
    }
    if (fetched > 0) {
      ExchangeRate.store(fetched, now);
    }
    return ExchangeRate.pick(fetched, cached, Constants.DEFAULT_USD_CNY);
  }

  private static async fetchText(url: string, cookie: string, serverId: string, referer: string): Promise<string> {
    if (cookie === '') {
      throw new Error('token 为空');
    }
    let lastErr: Error = new Error('未知错误');
    for (let attempt = 0; attempt < Constants.RETRY_BACKOFF_MS.length; attempt++) {
      const req = http.createHttp();
      try {
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
        req.destroy();
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

  /**
   * 通用 JSON 请求（自定义请求头，带退避重试）。
   * 401/403（凭据问题）与 404（接口不存在）立即失败，交由上层降级到其他数据源。
   */
  private static async fetchJson(url: string, headers: Record<string, string>): Promise<string> {
    let lastErr: Error = new Error('未知错误');
    for (let attempt = 0; attempt < Constants.RETRY_BACKOFF_MS.length; attempt++) {
      const req = http.createHttp();
      try {
        const resp = await req.request(url, {
          method: http.RequestMethod.GET,
          header: headers,
          connectTimeout: Constants.REQUEST_TIMEOUT_MS,
          readTimeout: Constants.REQUEST_TIMEOUT_MS,
        });
        req.destroy();
        const code = resp.responseCode;
        if (code === 401 || code === 403) {
          throw new Error(`认证失败 (HTTP ${code})`);
        }
        if (code === 404) {
          throw new Error('接口不存在 (HTTP 404)');
        }
        if (code < 200 || code >= 300) {
          throw new Error(`请求返回 HTTP ${code}`);
        }
        return resp.result as string;
      } catch (e) {
        req.destroy();
        lastErr = e instanceof Error ? e : new Error(String(e));
        if (lastErr.message.includes('认证失败') || lastErr.message.includes('接口不存在')) {
          throw lastErr;
        }
        if (attempt < Constants.RETRY_BACKOFF_MS.length - 1) {
          await OpenCodeApi.sleep(Constants.RETRY_BACKOFF_MS[attempt]);
        }
      }
    }
    throw lastErr;
  }
}

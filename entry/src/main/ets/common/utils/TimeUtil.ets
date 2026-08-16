// entry/src/main/ets/common/utils/TimeUtil.ets

/** 解析 ISO 字符串（含 Z 结尾）为毫秒时间戳。 */
export function parseIso(iso: string): number {
  const ts = Date.parse(iso);
  return Number.isNaN(ts) ? 0 : ts;
}

/**
 * 规范化时间字符串为 UTC ISO（'YYYY-MM-DDTHH:MM:SS.SSSZ'）。
 * 服务器可能返回 JS `new Date(...)` 可解析但 SQLite `datetime()` 无法解析的格式
 * （如 'Sat Aug 16 2026 05:02:00 GMT+0000'、'...+0000'），会导致「今天/近7天」等 SQL 过滤查不到数据。
 * 规则：缺时区标记按 UTC 处理；显式偏移（±HH:MM 或 ±HHMM）原样交给 Date.parse；无法解析则原样返回。
 */
export function toCanonicalIso(iso: string): string {
  const t = iso.trim();
  if (t === '') {
    return t;
  }
  // 兼容偏移的各种写法：先去掉秒级偏移（+08:00:00 → +08:00），再把 ±HHMM 转成 ±HH:MM
  let candidate = t.replace(/([+-]\d{2}):\d{2}:\d{2}$/, '$1:00');
  candidate = candidate.replace(/([+-]\d{2})(\d{2})$/, '$1:$2');
  const hasTz = /(?:Z|[+-]\d{2}:\d{2}|GMT[+-]\d{4})$/.test(candidate);
  if (!hasTz) {
    candidate = `${candidate}Z`;
  }
  const ms = Date.parse(candidate);
  if (Number.isNaN(ms)) {
    return iso;
  }
  return new Date(ms).toISOString();
}

/** 'YYYY-MM-DD HH:mm'（本地时区）。 */
export function formatDateTime(ms: number): string {
  if (ms <= 0) {
    return '--';
  }
  const d = new Date(ms);
  const p = (v: number): string => (v < 10 ? `0${v}` : `${v}`);
  return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())} ${p(d.getHours())}:${p(d.getMinutes())}`;
}

/** 'MM-DD'（本地时区）。 */
export function formatDate(ms: number): string {
  if (ms <= 0) {
    return '--';
  }
  const d = new Date(ms);
  const p = (v: number): string => (v < 10 ? `0${v}` : `${v}`);
  return `${p(d.getMonth() + 1)}-${p(d.getDate())}`;
}

/** 'MM-DD HH:mm'（本地时区，记录列表用短格式，节省列宽）。 */
export function formatDateTimeShort(ms: number): string {
  if (ms <= 0) {
    return '--';
  }
  const d = new Date(ms);
  const p = (v: number): string => (v < 10 ? `0${v}` : `${v}`);
  return `${p(d.getMonth() + 1)}-${p(d.getDate())} ${p(d.getHours())}:${p(d.getMinutes())}`;
}

/** 相对时间：刚刚 / n分钟前 / n小时前 / n天前。 */
export function formatRelative(ms: number, nowMs: number = Date.now()): string {
  if (ms <= 0) {
    return '--';
  }
  const diffSec = Math.max(0, Math.floor((nowMs - ms) / 1000));
  if (diffSec < 60) {
    return '刚刚';
  }
  if (diffSec < 3600) {
    return `${Math.floor(diffSec / 60)}分钟前`;
  }
  if (diffSec < 86400) {
    return `${Math.floor(diffSec / 3600)}小时前`;
  }
  return `${Math.floor(diffSec / 86400)}天前`;
}

/** 倒计时格式化：'1小时2分' / '1分30秒' / '0秒'。 */
export function formatDuration(totalSec: number): string {
  if (totalSec <= 0) {
    return '0秒';
  }
  const h = Math.floor(totalSec / 3600);
  const m = Math.floor((totalSec % 3600) / 60);
  const s = totalSec % 60;
  if (h > 0) {
    return `${h}小时${m}分`;
  }
  if (m > 0) {
    return `${m}分${s}秒`;
  }
  return `${s}秒`;
}

/** 倒计时格式（英文/短）：'1h 2m'。 */
export function formatDurationShort(totalSec: number): string {
  if (totalSec <= 0) {
    return '0s';
  }
  const h = Math.floor(totalSec / 3600);
  const m = Math.floor((totalSec % 3600) / 60);
  const s = totalSec % 60;
  if (h > 0) {
    return `${h}h ${m}m`;
  }
  if (m > 0) {
    return `${m}m ${s}s`;
  }
  return `${s}s`;
}

/** 配额重置倒计时：超过 48h 显示「约 N 天」（zh）/「~N d」（en），否则用短格式。 */
export function formatReset(totalSec: number, zh: boolean): string {
  if (totalSec >= 48 * 3600) {
    return zh ? `约 ${Math.round(totalSec / 86400)} 天` : `~${Math.round(totalSec / 86400)}d`;
  }
  return formatDurationShort(totalSec);
}

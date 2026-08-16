// entry/src/main/ets/common/utils/TimeUtil.ets

/** 解析 ISO 字符串（含 Z 结尾）为毫秒时间戳。 */
export function parseIso(iso: string): number {
  const ts = Date.parse(iso);
  return Number.isNaN(ts) ? 0 : ts;
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

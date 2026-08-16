// entry/src/main/ets/common/utils/Formatter.ets
import { isZh } from './Locale';
/** 数值/费用/百分比格式化（移植前端 app.js 的格式函数）。 */

/** 千分位缩写：999 / 1.5k / 2.5M。 */
export function formatTokens(n: number): string {
  if (n >= 1000000) {
    return `${parseFloat((n / 1000000).toFixed(2))}M`;
  }
  if (n >= 1000) {
    return `${(n / 1000).toFixed(1)}k`;
  }
  return `${n}`;
}

/** 本地化紧凑数值：中文用 万/亿，英文用 k/M。 */
export function formatTokensUi(n: number): string {
  if (isZh()) {
    if (n >= 100000000) {
      return `${(n / 100000000).toFixed(2)}亿`;
    }
    if (n >= 10000) {
      return `${(n / 10000).toFixed(1)}万`;
    }
    return `${n}`;
  }
  return formatTokens(n);
}

/** 紧凑数值（按 zh 参数决定单位），供图表轴标签使用。 */
export function formatCompact(n: number, zh: boolean): string {
  if (zh) {
    if (n >= 100000000) {
      return `${(n / 100000000).toFixed(1)}亿`;
    }
    if (n >= 10000) {
      return `${(n / 10000).toFixed(1)}万`;
    }
    return `${n}`;
  }
  return formatTokens(n);
}

/** 成本格式化：CNY 换算并保留两位，USD 保留四位。 */
export function formatCost(usd: number, currency: string, usdCny: number): string {
  if (currency === 'CNY') {
    const cny = usd * usdCny;
    return `¥${cny.toFixed(2)}`;
  }
  return `$${usd.toFixed(4)}`;
}

/** 百分比：保留 1 位小数。 */
export function formatPercent(p: number): string {
  return `${p.toFixed(1)}%`;
}

/** 一般整数（带千分位）。 */
export function formatCount(n: number): string {
  return n.toLocaleString('en-US');
}

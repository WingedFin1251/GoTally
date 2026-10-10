// entry/src/main/ets/common/utils/ExchangeRate.ets

/**
 * USD→CNY 汇率缓存（TTL 6 小时，与上游 GoGauge 的 `_EXCHANGE_TTL` 一致）。
 *
 * 之前每次进入页面都会请求 `open.er-api.com`（4 个页面各一次），既慢又浪费；
 * 现在进程内缓存 6 小时，拉取失败时优先复用旧缓存，最后才回退默认值。
 */
export class ExchangeRate {
  /** 缓存有效期。 */
  static readonly TTL_MS: number = 6 * 60 * 60 * 1000;

  private static rate: number = 0;
  private static fetchedAt: number = 0;

  /** 是否已过期需要重新拉取（纯函数，便于回归测试）。 */
  static isStale(now: number, fetchedAt: number, ttl: number): boolean {
    if (fetchedAt <= 0) {
      return true;
    }
    return now - fetchedAt >= ttl;
  }

  /** 取用哪个汇率（纯函数）：新值有效 → 旧缓存 → 兜底默认。 */
  static pick(fetched: number, cached: number, fallback: number): number {
    if (fetched > 0) {
      return fetched;
    }
    if (cached > 0) {
      return cached;
    }
    return fallback;
  }

  /** 当前是否需要发起网络请求。 */
  static shouldFetch(now: number): boolean {
    return ExchangeRate.isStale(now, ExchangeRate.fetchedAt, ExchangeRate.TTL_MS);
  }

  /** 已缓存的汇率（0 表示还没有成功拉取过）。 */
  static cached(): number {
    return ExchangeRate.rate;
  }

  /** 缓存年龄（毫秒）；未缓存返回 -1。 */
  static ageMs(now: number): number {
    return ExchangeRate.fetchedAt <= 0 ? -1 : now - ExchangeRate.fetchedAt;
  }

  /** 写入新汇率（仅接受有效正数）。 */
  static store(rate: number, now: number): void {
    if (rate > 0) {
      ExchangeRate.rate = rate;
      ExchangeRate.fetchedAt = now;
    }
  }

  /** 清空缓存（供测试与手动刷新使用）。 */
  static reset(): void {
    ExchangeRate.rate = 0;
    ExchangeRate.fetchedAt = 0;
  }
}

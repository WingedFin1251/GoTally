// entry/src/test/ExchangeRate.test.ets
import { describe, it, expect } from '@ohos/hypium';
import { ExchangeRate } from '../main/ets/common/utils/ExchangeRate';

/**
 * 汇率 TTL 缓存（回归测试）。
 *
 * 行为约定：6 小时内直接用缓存（避免每次进页面都请求汇率接口）；
 * 过期后重新拉取，拉取失败时优先复用旧缓存，最后才回退默认值。
 */
export default function exchangeRateTest() {
  describe('ExchangeRateTest', () => {
    it('is_stale_with_ttl', 0, () => {
      const ttl = ExchangeRate.TTL_MS;
      expect(ExchangeRate.isStale(0, 0, ttl)).assertTrue();          // 从未拉取
      expect(ExchangeRate.isStale(1000, 1000, ttl)).assertFalse();   // 刚拉到
      expect(ExchangeRate.isStale(1000 + ttl - 1, 1000, ttl)).assertFalse(); // 未过期
      expect(ExchangeRate.isStale(1000 + ttl, 1000, ttl)).assertTrue();      // 恰好到期
      expect(ExchangeRate.isStale(1000 + ttl + 1, 1000, ttl)).assertTrue();
    });

    it('ttl_is_six_hours', 0, () => {
      expect(ExchangeRate.TTL_MS).assertEqual(6 * 60 * 60 * 1000);
    });

    it('pick_prefers_fetched_then_cache_then_fallback', 0, () => {
      expect(ExchangeRate.pick(7.1, 7.0, 7.2)).assertEqual(7.1);
      expect(ExchangeRate.pick(0, 7.0, 7.2)).assertEqual(7.0);   // 拉取失败用旧缓存
      expect(ExchangeRate.pick(-1, 0, 7.2)).assertEqual(7.2);    // 都没有才回退默认
      expect(ExchangeRate.pick(0, 0, 7.2)).assertEqual(7.2);
    });

    it('store_and_should_fetch_lifecycle', 0, () => {
      ExchangeRate.reset();
      const t0 = 1_000_000;
      expect(ExchangeRate.cached()).assertEqual(0);
      expect(ExchangeRate.ageMs(t0)).assertEqual(-1);
      expect(ExchangeRate.shouldFetch(t0)).assertTrue();
      ExchangeRate.store(7.15, t0);
      expect(ExchangeRate.cached()).assertEqual(7.15);
      expect(ExchangeRate.ageMs(t0)).assertEqual(0);
      expect(ExchangeRate.shouldFetch(t0 + 1000)).assertFalse();
      expect(ExchangeRate.shouldFetch(t0 + ExchangeRate.TTL_MS)).assertTrue();
      // 非法值不写入缓存
      ExchangeRate.store(0, t0 + 10);
      ExchangeRate.store(-3, t0 + 20);
      expect(ExchangeRate.cached()).assertEqual(7.15);
      ExchangeRate.reset();
      expect(ExchangeRate.cached()).assertEqual(0);
    });
  });
}

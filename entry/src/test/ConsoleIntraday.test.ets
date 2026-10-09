// entry/src/test/ConsoleIntraday.test.ets
import { describe, it, expect } from '@ohos/hypium';
import { ConsoleIntraday } from '../main/ets/data/ConsoleIntraday';
import type { IntradaySample } from '../main/ets/data/ConsoleIntraday';
import type { TrendPoint } from '../main/ets/model/Stats';

/**
 * 今日趋势的本地采样重建（回归测试）。
 *
 * 官方控制台没有小时级接口，所以「今日趋势」由每次刷新记录的**当日累计值**反推：
 * 同一小时只取最后一个采样点，按小时对累计值求增量。这里锁定该算法，
 * 避免出现「重复计数」或「丢首段用量」。
 */
function mk(tsMin: number, input: number, output: number): IntradaySample {
  return { tsMin: tsMin, input: input, output: output, requests: 0, costUsd: 0 };
}

/** 构造某个本地小时的采样时刻（epoch 分钟）。 */
function atLocal(hour: number, minute: number): number {
  const d = new Date();
  d.setHours(hour, minute, 0, 0);
  return ConsoleIntraday.toTsMin(d.getTime());
}

export default function consoleIntradayTest() {
  describe('ConsoleIntradayTest', () => {
    it('empty_samples_give_empty_trend', 0, () => {
      expect(ConsoleIntraday.buildTrend([]).length).assertEqual(0);
    });

    it('first_hour_takes_cumulative_then_deltas', 0, () => {
      // 10:05 累计 1000/200；11:10 累计 1500/260；12:20 累计 1800/300
      const s: IntradaySample[] = [
        mk(atLocal(10, 5), 1000, 200),
        mk(atLocal(11, 10), 1500, 260),
        mk(atLocal(12, 20), 1800, 300),
      ];
      const t: TrendPoint[] = ConsoleIntraday.buildTrend(s);
      expect(t.length).assertEqual(3);
      // 首个小时取累计（把开始采样前的用量也算进来，不丢数据）
      expect(t[0].hour).assertEqual('10:00');
      expect(t[0].input).assertEqual(1000);
      expect(t[0].output).assertEqual(200);
      // 后续小时取增量
      expect(t[1].hour).assertEqual('11:00');
      expect(t[1].input).assertEqual(500);
      expect(t[1].output).assertEqual(60);
      expect(t[2].hour).assertEqual('12:00');
      expect(t[2].input).assertEqual(300);
      expect(t[2].output).assertEqual(40);
      // 官方不提供推理 Token
      expect(t[0].reasoning).assertEqual(0);
    });

    it('same_hour_keeps_last_sample_only', 0, () => {
      // 同一小时多次刷新（10:05、10:20、10:50）只算一次，不重复计数
      const s: IntradaySample[] = [
        mk(atLocal(10, 5), 100, 10),
        mk(atLocal(10, 20), 250, 30),
        mk(atLocal(10, 50), 400, 50),
      ];
      const t = ConsoleIntraday.buildTrend(s);
      expect(t.length).assertEqual(1);
      expect(t[0].input).assertEqual(400);
      expect(t[0].output).assertEqual(50);
    });

    it('unordered_input_is_sorted', 0, () => {
      const s: IntradaySample[] = [
        mk(atLocal(12, 20), 1800, 300),
        mk(atLocal(10, 5), 1000, 200),
        mk(atLocal(11, 10), 1500, 260),
      ];
      const t = ConsoleIntraday.buildTrend(s);
      expect(t[0].hour).assertEqual('10:00');
      expect(t[2].hour).assertEqual('12:00');
    });

    it('counter_regression_clamps_to_zero', 0, () => {
      // 接口口径回退（累计值变小）时增量按 0 处理，避免出现负柱
      const s: IntradaySample[] = [
        mk(atLocal(10, 5), 1000, 200),
        mk(atLocal(11, 10), 400, 50),
      ];
      const t = ConsoleIntraday.buildTrend(s);
      expect(t[1].input).assertEqual(0);
      expect(t[1].output).assertEqual(0);
    });

    it('localDay_and_toTsMin', 0, () => {
      const d = new Date(2026, 2, 14, 9, 30, 0);
      expect(ConsoleIntraday.localDay(d)).assertEqual('2026-03-14');
      expect(ConsoleIntraday.toTsMin(d.getTime())).assertEqual(Math.floor(d.getTime() / 60000));
      expect(ConsoleIntraday.hourOf(ConsoleIntraday.toTsMin(d.getTime()))).assertEqual(9);
    });
  });
}

// entry/src/test/ConsoleSnapshot.test.ets
import { describe, it, expect } from '@ohos/hypium';
import { ConsoleSnapshotStore } from '../main/ets/data/ConsoleSnapshotStore';
import type { ModelStat, DailyStat } from '../main/ets/model/Stats';
import type { QuotaWindow } from '../main/ets/model/UsageRecord';

/**
 * 本地快照去重（回归测试）。
 *
 * 背景：官方聚合数据要落本地供离线查看，但接口重复返回同一 model/日期时，
 * 若不去重会出现「同一份数据存多份」。这里锁定批内去重逻辑（写库前的第一道闸）。
 */
function mkModel(model: string, requests: number): ModelStat {
  return {
    model: model, requestCount: requests, sessionCount: 0, totalInputTokens: 0, uncachedInputTokens: 0,
    totalReasoningTokens: 0, cacheHitTokens: 0, cacheWriteTokens: 0, totalOutputTokens: 0,
    totalCostUsd: 0, hitRate: 0,
  };
}

function mkDay(date: string, requests: number): DailyStat {
  return {
    date: date, totalInputTokens: 0, uncachedInputTokens: 0, totalReasoningTokens: 0, cacheHitTokens: 0,
    cacheWriteTokens: 0, totalOutputTokens: 0, totalCostUsd: 0, requestCount: requests, hitRate: 0,
  };
}

export default function consoleSnapshotTest() {
  describe('ConsoleSnapshotTest', () => {
    it('dedupeModels_keeps_single_row_per_model', 0, () => {
      const out = ConsoleSnapshotStore.dedupeModels([
        mkModel('gpt-5.6', 10), mkModel('deepseek-v4.1-flash', 20), mkModel('gpt-5.6', 11),
      ]);
      expect(out.length).assertEqual(2);
      // 同一 model 保留最后一条
      let gpt = 0;
      for (const m of out) {
        if (m.model === 'gpt-5.6') {
          gpt = m.requestCount;
        }
      }
      expect(gpt).assertEqual(11);
    });

    it('dedupeModels_skips_empty_model', 0, () => {
      const out = ConsoleSnapshotStore.dedupeModels([mkModel('', 1), mkModel('glm-5.3', 2)]);
      expect(out.length).assertEqual(1);
      expect(out[0].model).assertEqual('glm-5.3');
    });

    it('dedupeDays_keeps_single_row_per_date', 0, () => {
      const out = ConsoleSnapshotStore.dedupeDays([
        mkDay('2026-09-26', 5), mkDay('2026-09-26', 7), mkDay('2026-09-27', 9),
      ]);
      expect(out.length).assertEqual(2);
      expect(out[0].requestCount).assertEqual(7);
    });

    it('dedupeQuota_keeps_single_row_per_label', 0, () => {
      const w = (label: string, used: number): QuotaWindow => ({
        label: label, used: used, remaining: 100 - used, total: 100, unit: '%', resetAt: '', resetInSec: 0,
      });
      const out = ConsoleSnapshotStore.dedupeQuota([w('5h', 1), w('weekly', 2), w('5h', 3)]);
      expect(out.length).assertEqual(2);
      expect(out[0].used).assertEqual(3);
    });
  });
}
// entry/src/ohosTest/ets/test/Repository.test.ets
import { describe, beforeAll, it, expect } from '@ohos/hypium';
import { common } from '@kit.AbilityKit';
import { AppContext } from '../../../main/ets/common/AppContext';
import { RdbHelper } from '../../../main/ets/data/RdbHelper';
import { UsageRepository } from '../../../main/ets/data/UsageRepository';
import type { UsageRecord } from '../../../main/ets/model/UsageRecord';

export default function repositoryTest() {
  describe('UsageRepositoryTest', () => {
    beforeAll(() => {
      // 设备测试环境注入 UIAbilityContext，供 RDB/Preferences 初始化使用
      AppContext.context = getContext(this) as common.UIAbilityContext;
    });
    it('insertAndTotals', 0, async () => {
      const store = await RdbHelper.getStore();
      expect(store).not().assertNull();
      const repo = new UsageRepository();
      // 清空历史数据，保证测试可重复执行（RDB 文件在设备上持久化）
      await repo.clearAccount();
      const now = '2026-08-16T10:00:00.000Z';
      const rec: UsageRecord = {
        usgId: 'usg_test_1', createdAt: now, model: 'gpt-4o', provider: 'openai',
        inputTokens: 100, outputTokens: 50, reasoningTokens: 10,
        cacheReadTokens: 200, cacheWrite5mTokens: 0, cacheWrite1hTokens: 0,
        costRaw: 1000000, costUsd: 0.01, keyId: 'k1', sessionId: 's1', plan: 'pro', syncedAt: now,
      };
      const inserted = await repo.insertUsageRecords([rec]);
      expect(inserted).assertEqual(1);
      const totals = await repo.totals('today');
      expect(totals.requestCount).assertEqual(1);
      expect(totals.cacheHitTokens).assertEqual(200);
      expect(totals.totalOutputTokens).assertEqual(50);
      // 幂等：再次插入去重
      const again = await repo.insertUsageRecords([rec]);
      expect(again).assertEqual(0);
    });
  });
}

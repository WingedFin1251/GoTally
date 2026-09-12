// entry/src/test/RecordsFilter.test.ets
import { describe, it, expect } from '@ohos/hypium';
import { UsageRepository } from '../main/ets/data/UsageRepository';

/**
 * 使用记录筛选条件构造（回归测试）。
 *
 * 背景：`usageRecordsPage` 曾出现参数顺序错位——SQL 里 `model = ?` 在前、周期条件在后，
 * 但参数数组把周期参数（如 '-7 days'）排在最前，导致「近7天/近30天 + 指定模型」恒查不到数据，
 * 而「今天/全部」（无周期参数）正常。这里锁定参数与占位符的顺序一致。
 */
export default function recordsFilterTest() {
  describe('RecordsFilterTest', () => {
    it('model_with_today_has_single_param', 0, () => {
      const f = UsageRepository.recordsFilter('deepseek-v3', 'today');
      expect(f.params.length).assertEqual(1);
      expect(f.params[0] as string).assertEqual('deepseek-v3');
      expect(f.clause.indexOf('model = ?') >= 0).assertTrue();
    });

    it('model_with_7d_keeps_param_order', 0, () => {
      const f = UsageRepository.recordsFilter('deepseek-v3', '7d');
      expect(f.params.length).assertEqual(2);
      // 关键：model 参数必须在周期参数之前，且与占位符出现顺序一致
      expect(f.params[0] as string).assertEqual('deepseek-v3');
      expect(f.params[1] as string).assertEqual('-7 days');
      expect(f.clause.indexOf('model = ?') < f.clause.indexOf('datetime(created_at)')).assertTrue();
    });

    it('model_with_30d_keeps_param_order', 0, () => {
      const f = UsageRepository.recordsFilter('glm-4.6', '30d');
      expect(f.params.length).assertEqual(2);
      expect(f.params[0] as string).assertEqual('glm-4.6');
      expect(f.params[1] as string).assertEqual('-30 days');
    });

    it('model_with_all_has_no_period_param', 0, () => {
      const f = UsageRepository.recordsFilter('glm-4.6', 'all');
      expect(f.params.length).assertEqual(1);
      expect(f.params[0] as string).assertEqual('glm-4.6');
      expect(f.clause.indexOf('datetime(created_at)') < 0).assertTrue();
    });

    it('no_model_with_30d_has_only_period_param', 0, () => {
      const f = UsageRepository.recordsFilter('', '30d');
      expect(f.params.length).assertEqual(1);
      expect(f.params[0] as string).assertEqual('-30 days');
    });

    it('no_filter_returns_empty_clause', 0, () => {
      const f = UsageRepository.recordsFilter(null, 'all');
      expect(f.params.length).assertEqual(0);
      expect(f.clause).assertEqual('');
    });
  });
}
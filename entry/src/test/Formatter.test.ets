import { describe, it, expect } from '@ohos/hypium';
import { formatTokens, formatCost, formatCostFine, formatPercent } from '../main/ets/common/utils/Formatter';

export default function formatterTest() {
  describe('FormatterTest', () => {
    it('formatTokens_kilo', 0, () => {
      expect(formatTokens(1500)).assertEqual('1.5k');
    });
    it('formatTokens_mega', 0, () => {
      expect(formatTokens(2500000)).assertEqual('2.5M');
    });
    it('formatTokens_plain', 0, () => {
      expect(formatTokens(999)).assertEqual('999');
    });
    it('formatCost_usd', 0, () => {
      expect(formatCost(0.0123, 'USD', 7.2)).assertEqual('$0.0123');
    });
    it('formatCost_cny', 0, () => {
      expect(formatCost(0.5, 'CNY', 7.2)).assertEqual('¥3.60');
    });
    it('formatCost_zero', 0, () => {
      expect(formatCost(0, 'CNY', 7.2)).assertEqual('¥0.00');
    });
    it('formatCost_cny_rate', 0, () => {
      expect(formatCost(1, 'CNY', 7.25)).assertEqual('¥7.25');
    });
    it('formatPercent', 0, () => {
      expect(formatPercent(45.678)).assertEqual('45.7%');
    });
    it('formatCostFine_keeps_small_amounts_precise', 0, () => {
      // 每请求均费：¥0.0154 不能被四舍五入成 ¥0.02
      expect(formatCostFine(0.00214, 'CNY', 7.2)).assertEqual('¥0.0154');
      expect(formatCostFine(0.00214, 'USD', 7.2)).assertEqual('$0.0021');
      // ≥ 1 时回到 2 位小数
      expect(formatCostFine(2, 'CNY', 7.2)).assertEqual('¥14.40');
      expect(formatCostFine(1.5, 'USD', 7.2)).assertEqual('$1.50');
    });
  });
}

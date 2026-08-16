import { describe, it, expect } from '@ohos/hypium';
import { formatTokens, formatCost, formatPercent } from '../main/ets/common/utils/Formatter';

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
    it('formatPercent', 0, () => {
      expect(formatPercent(45.678)).assertEqual('45.7%');
    });
  });
}

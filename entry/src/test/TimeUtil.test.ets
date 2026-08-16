import { describe, it, expect } from '@ohos/hypium';
import { parseIso, formatDuration } from '../main/ets/common/utils/TimeUtil';

export default function timeUtilTest() {
  describe('TimeUtilTest', () => {
    it('parseIso_utc', 0, () => {
      expect(parseIso('2026-08-16T10:00:00Z')).assertEqual(Date.UTC(2026, 7, 16, 10, 0, 0));
    });
    it('formatDuration_hours', 0, () => {
      expect(formatDuration(3720)).assertEqual('1小时2分');
    });
    it('formatDuration_minutes', 0, () => {
      expect(formatDuration(90)).assertEqual('1分30秒');
    });
    it('formatDuration_zero', 0, () => {
      expect(formatDuration(0)).assertEqual('0秒');
    });
  });
}

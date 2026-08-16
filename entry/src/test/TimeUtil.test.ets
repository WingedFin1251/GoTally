import { describe, it, expect } from '@ohos/hypium';
import { parseIso, toCanonicalIso, formatDuration } from '../main/ets/common/utils/TimeUtil';

export default function timeUtilTest() {
  describe('TimeUtilTest', () => {
    it('parseIso_utc', 0, () => {
      expect(parseIso('2026-08-16T10:00:00Z')).assertEqual(Date.UTC(2026, 7, 16, 10, 0, 0));
    });
    it('toCanonicalIso_variants', 0, () => {
      expect(toCanonicalIso('2026-08-16T05:02:00Z')).assertEqual('2026-08-16T05:02:00.000Z');
      expect(toCanonicalIso('2026-08-16T05:02:00')).assertEqual('2026-08-16T05:02:00.000Z');
      expect(toCanonicalIso('2026-08-16T05:02:00+08:00')).assertEqual('2026-08-15T21:02:00.000Z');
      expect(toCanonicalIso('2026-08-16T05:02:00+0800')).assertEqual('2026-08-15T21:02:00.000Z');
      expect(toCanonicalIso('2026-08-16T05:02:00.000+08:00:00')).assertEqual('2026-08-15T21:02:00.000Z');
      expect(toCanonicalIso('2026-08-16T05:02:00.000+0000')).assertEqual('2026-08-16T05:02:00.000Z');
      expect(toCanonicalIso('Sat Aug 16 2026 05:02:00 GMT+0000')).assertEqual('2026-08-16T05:02:00.000Z');
      expect(toCanonicalIso('garbage')).assertEqual('garbage');
      expect(toCanonicalIso('')).assertEqual('');
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

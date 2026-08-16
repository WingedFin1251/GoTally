// entry/src/test/OpenCodeApi.test.ets
import { describe, it, expect } from '@ohos/hypium';
import { OpenCodeApi, normalizeIso } from '../main/ets/network/OpenCodeApi';

const QUOTA_HTML: string = `
  rollingUsage: $R[3] = { resetInSec: 12345, usagePercent: 42.5 }
  weeklyUsage: $R[4] = { usagePercent: 60.2, resetInSec: 86400 }
  monthlyUsage: $R[5] = { usagePercent: 7.8, resetInSec: 2592000 }
`;

const USAGE_TEXT: string = `
  $R[1] = { id: "usg_a1", enrichment:$R[2]={plan:"pro"} }
  timeCreated: $R[2] = new Date("2026-08-16T09:00:00Z")
  model: "gpt-4o" provider: "openai" inputTokens: 100 outputTokens: 50
  reasoningTokens: 10 cacheReadTokens: 200 cacheWrite5mTokens: 0 cacheWrite1hTokens: 0
  cost: 5000000 keyID: "k1" sessionID: "s1"
  $R[6] = { id: "usg_b2", enrichment:$R[7]={plan:"free"} }
  timeCreated: $R[7] = new Date("2026-08-16T08:00:00Z")
  model: "deepseek-chat" provider: "deepseek" inputTokens: 10 outputTokens: 5
  reasoningTokens: 0 cacheReadTokens: 0 cacheWrite5mTokens: 0 cacheWrite1hTokens: 0
  cost: 100 keyID: "k2" sessionID: ""
`;

export default function openCodeApiTest() {
  describe('OpenCodeApiTest', () => {
    it('parseQuotaHtml', 0, () => {
      const windows = OpenCodeApi.parseQuotaHtml(QUOTA_HTML, '2026-08-16T10:00:00Z');
      expect(windows.length).assertEqual(3);
      expect(windows[0].used).assertEqual(42.5);
      expect(windows[0].resetInSec).assertEqual(12345);
      expect(windows[1].used).assertEqual(60.2);
      expect(windows[1].resetInSec).assertEqual(86400);
      expect(windows[2].used).assertEqual(7.8);
    });
    it('parseUsageResponse', 0, () => {
      const records = OpenCodeApi.parseUsageResponse(USAGE_TEXT);
      expect(records.length).assertEqual(2);
      expect(records[0].usgId).assertEqual('usg_a1');
      expect(records[0].model).assertEqual('gpt-4o');
      expect(records[0].inputTokens).assertEqual(100);
      expect(records[0].costRaw).assertEqual(5000000);
      expect(records[0].plan).assertEqual('pro');
      expect(records[1].plan).assertEqual('free');
      expect(records[1].sessionId).assertEqual('');
    });
    it('buildCookieHeader', 0, () => {
      expect(OpenCodeApi.buildCookieHeader('abc123')).assertEqual('auth=abc123');
      expect(OpenCodeApi.buildCookieHeader('Cookie: foo=1; auth=xyz')).assertEqual('auth=xyz');
    });
    it('normalizeIso', 0, () => {
      expect(normalizeIso('2026-08-16T09:00:00')).assertEqual('2026-08-16T09:00:00Z');
      expect(normalizeIso('2026-08-16T09:00:00Z')).assertEqual('2026-08-16T09:00:00Z');
      expect(normalizeIso('2026-08-16T09:00:00+08:00')).assertEqual('2026-08-16T09:00:00+08:00');
      expect(normalizeIso('')).assertEqual('');
    });
    it('extractWorkspaceId', 0, () => {
      expect(OpenCodeApi.extractWorkspaceId('wrk_abc123')).assertEqual('wrk_abc123');
      expect(OpenCodeApi.extractWorkspaceId('https://opencode.ai/workspace/wrk_abc123/go')).assertEqual('wrk_abc123');
      expect(OpenCodeApi.extractWorkspaceId('default')).assertEqual('');
    });
  });
}

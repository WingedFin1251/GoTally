// entry/src/test/ConsoleLogs.test.ets
import { describe, it, expect } from '@ohos/hypium';
import { OpenCodeApi } from '../main/ets/network/OpenCodeApi';
import type { ConsoleUsagePage } from '../main/ets/network/OpenCodeApi';

/**
 * 控制台逐条明细接口（`/console/api/request-logs`）解析（回归测试）。
 *
 * 实测契约（2026-09 控制台改版后）：
 *   { items:[{ id, startedAt(epoch ms), category:"inference"|"api", model, provider,
 *              sessionID, serviceAPIKeyID, product, inputTokens, outputTokens,
 *              reasoningTokens, cacheReadTokens, cacheWriteTokens, cost }],
 *     nextCursor, retentionDays:30 }
 * 要点：只保留 category === "inference"（"api" 是控制台自身调用），
 * 数字可能以字符串给出，cost 为美元浮点（写入 cost_raw 时换算成 1e-8 USD）。
 */
const BODY: string = '{' +
  '"items":[' +
  '{"id":"req-1","startedAt":1791553019514,"category":"inference","model":"model-alpha",' +
  '"provider":"opencode","sessionID":"sess-1","serviceAPIKeyID":"key_1","product":"go",' +
  '"inputTokens":536,"outputTokens":167,"reasoningTokens":42,"cacheReadTokens":242944,' +
  '"cacheWriteTokens":0,"cost":0.00090943},' +
  '{"id":"req-2","startedAt":1791552828044,"category":"api","model":null,' +
  '"inputTokens":0,"outputTokens":0,"cost":0},' +
  '{"id":"req-3","startedAt":1791552700000,"category":"inference","model":"model-beta",' +
  '"provider":"opencode","sessionID":"","serviceAPIKeyID":"key_2","product":"go",' +
  '"inputTokens":"100","outputTokens":"20","reasoningTokens":0,"cacheReadTokens":0,' +
  '"cacheWriteTokens":4096,"cost":"0.0000387"},' +
  '{"id":"","startedAt":1791552600000,"category":"inference","model":"bad","cost":1}' +
  '],' +
  '"nextCursor":"{\\"v\\":2,\\"kind\\":\\"list\\",\\"until\\":1790427382939}",' +
  '"retentionDays":30}';

export default function consoleLogsTest() {
  describe('ConsoleLogsTest', () => {
    it('parses_inference_records_only', 0, () => {
      const page: ConsoleUsagePage = OpenCodeApi.parseConsoleRequestLogs(BODY);
      // req-2 是控制台自身调用（category=api），req-4 无 id，均被剔除
      expect(page.records.length).assertEqual(2);
      expect(page.nextCursor.length > 0).assertTrue();
      expect(page.retentionDays).assertEqual(30);
    });

    it('maps_fields_to_usage_record', 0, () => {
      const r = OpenCodeApi.parseConsoleRequestLogs(BODY).records[0];
      expect(r.usgId).assertEqual('req-1');
      expect(r.model).assertEqual('model-alpha');
      expect(r.provider).assertEqual('opencode');
      expect(r.sessionId).assertEqual('sess-1');
      expect(r.keyId).assertEqual('key_1');
      expect(r.plan).assertEqual('go');
      expect(r.inputTokens).assertEqual(536);
      expect(r.outputTokens).assertEqual(167);
      expect(r.reasoningTokens).assertEqual(42);
      expect(r.cacheReadTokens).assertEqual(242944);
      // 新接口只有单一 cacheWrite 字段 → 记入 5m 列，1h 列为 0（合计口径不变）
      expect(r.cacheWrite5mTokens).assertEqual(0);
      expect(r.cacheWrite1hTokens).assertEqual(0);
      expect(r.costUsd).assertEqual(0.00090943);
      expect(r.costRaw).assertEqual(90943);
      // startedAt(ms) → ISO 字符串（用服务器时间戳，不受设备时钟影响）
      expect(r.createdAt.endsWith('Z')).assertTrue();
      expect(r.createdAt.length > 10).assertTrue();
    });

    it('accepts_string_numbers', 0, () => {
      const r = OpenCodeApi.parseConsoleRequestLogs(BODY).records[1];
      expect(r.inputTokens).assertEqual(100);
      expect(r.outputTokens).assertEqual(20);
      expect(r.cacheWrite5mTokens).assertEqual(4096);
      expect(r.costRaw).assertEqual(3870);
    });

    it('tolerates_garbage', 0, () => {
      const page = OpenCodeApi.parseConsoleRequestLogs('not json');
      expect(page.records.length).assertEqual(0);
      expect(page.nextCursor).assertEqual('');
      expect(page.retentionDays).assertEqual(0);
    });

    it('empty_items', 0, () => {
      const page = OpenCodeApi.parseConsoleRequestLogs('{"items":[],"retentionDays":30}');
      expect(page.records.length).assertEqual(0);
      expect(page.retentionDays).assertEqual(30);
    });
  });
}

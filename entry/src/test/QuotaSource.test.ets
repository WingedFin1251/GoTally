// entry/src/test/QuotaSource.test.ets
import { describe, it, expect } from '@ohos/hypium';
import { OpenCodeApi } from '../main/ets/network/OpenCodeApi';
import type { QuotaWindow } from '../main/ets/model/UsageRecord';

/**
 * 配额数据源解析（回归测试）。
 *
 * 背景：配额改为「官方 API Key 接口 → 控制台 JSON 接口 → 页面解析」三级降级，
 * 其中前两级的字段结构来自社区实测（非公开文档），此处用真实响应样例锁定契约，
 * 一旦上游改结构可立刻从单测发现。
 */
const NOW: string = '2026-09-01T00:00:00.000Z';

const OFFICIAL_JSON: string = `{
  "usage": {
    "rolling": { "status": "ok", "percent": 62, "resetsAt": "2026-09-01T03:00:00.000Z" },
    "weekly":  { "status": "ok", "percent": 31, "resetsAt": "2026-09-05T00:00:00.000Z" },
    "monthly": { "status": "ok", "percent": 44, "resetsAt": "2026-09-20T00:00:00.000Z" }
  }
}`;

/** 控制台接口金额单位为微分（1e-8 美元）：12e8 = $12，3.2e8 = $3.20。 */
const CONSOLE_JSON: string = `{
  "access": {
    "meters": {
      "fiveHour": { "resetsAt": "2026-09-01T03:00:00.000Z", "limitMicroCents": 1200000000, "usedMicroCents": 320000000 },
      "week":     { "resetsAt": "2026-09-05T00:00:00.000Z", "limitMicroCents": 3000000000, "usedMicroCents": 600000000 },
      "month":    { "resetsAt": "2026-09-20T00:00:00.000Z", "limitMicroCents": 6000000000, "usedMicroCents": 3000000000 }
    }
  }
}`;

export default function quotaSourceTest() {
  describe('QuotaSourceTest', () => {
    it('official_parses_three_windows', 0, () => {
      const w: QuotaWindow[] = OpenCodeApi.parseOfficialUsage(OFFICIAL_JSON, NOW);
      expect(w.length).assertEqual(3);
      expect(w[0].label).assertEqual('5h');
      expect(w[1].label).assertEqual('weekly');
      expect(w[2].label).assertEqual('monthly');
      expect(w[0].used).assertEqual(62);
      expect(w[0].remaining).assertEqual(38);
      // 重置倒计时由 resetsAt 推算：3 小时
      expect(w[0].resetInSec).assertEqual(10800);
    });

    it('official_skips_missing_window', 0, () => {
      const text = '{"usage":{"rolling":{"percent":10}}}';
      const w: QuotaWindow[] = OpenCodeApi.parseOfficialUsage(text, NOW);
      expect(w.length).assertEqual(1);
      expect(w[0].label).assertEqual('5h');
    });

    it('official_returns_empty_without_usage', 0, () => {
      const w: QuotaWindow[] = OpenCodeApi.parseOfficialUsage('{"ok":true}', NOW);
      expect(w.length).assertEqual(0);
    });

    it('console_parses_percent_and_amount', 0, () => {
      const w: QuotaWindow[] = OpenCodeApi.parseConsoleStatus(CONSOLE_JSON, NOW);
      expect(w.length).assertEqual(3);
      // 3.2e8 / 12e8 = 26.67%
      expect(w[0].used).assertEqual(26.7);
      expect(w[0].usedUsd).assertEqual(3.2);
      expect(w[0].limitUsd).assertEqual(12);
      // 60e8 / 300e8 = 20%
      expect(w[1].used).assertEqual(20);
      expect(w[1].limitUsd).assertEqual(30);
      // 300e8 / 600e8 = 50%
      expect(w[2].used).assertEqual(50);
      expect(w[2].limitUsd).assertEqual(60);
      expect(w[0].resetInSec).assertEqual(10800);
    });

    it('console_skips_zero_limit', 0, () => {
      const text = '{"access":{"meters":{"fiveHour":{"limitMicroCents":0,"usedMicroCents":0},"week":{"limitMicroCents":3000000000,"usedMicroCents":0}}}}';
      const w: QuotaWindow[] = OpenCodeApi.parseConsoleStatus(text, NOW);
      expect(w.length).assertEqual(1);
      expect(w[0].label).assertEqual('weekly');
    });

    it('console_returns_empty_without_access', 0, () => {
      const w: QuotaWindow[] = OpenCodeApi.parseConsoleStatus('{"access":{}}', NOW);
      expect(w.length).assertEqual(0);
    });

    it('expired_reset_clamps_to_zero', 0, () => {
      const text = '{"usage":{"rolling":{"percent":1,"resetsAt":"2020-01-01T00:00:00.000Z"}}}';
      const w: QuotaWindow[] = OpenCodeApi.parseOfficialUsage(text, NOW);
      expect(w.length).assertEqual(1);
      expect(w[0].resetInSec).assertEqual(0);
    });
  });
}
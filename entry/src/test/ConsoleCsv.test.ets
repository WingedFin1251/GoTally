// entry/src/test/ConsoleCsv.test.ets
import { describe, it, expect } from '@ohos/hypium';
import { ConsoleCsv } from '../main/ets/data/ConsoleCsv';
import type { CsvUsageRow } from '../main/ets/data/ConsoleCsv';
import type { DailyStat } from '../main/ets/model/Stats';

/**
 * 官方 CSV 导出解析（回归测试）。
 *
 * 真实表头：
 *   day,user_type,user_id,user_name,provider,model,requests,input_tokens,output_tokens,
 *   cache_read_tokens,cache_write_5m_tokens,cache_write_1h_tokens,cost_micro_cents,last_active_at
 * 该 CSV 支持 90d 窗口，是本地历史回填的主要来源，务必锁定解析契约。
 *
 * 注意：以下数据全部为**合成示例**（无任何真实账号/用量信息）。
 */
const CSV: string = 'day,user_type,user_id,user_name,provider,model,requests,input_tokens,output_tokens,cache_read_tokens,cache_write_5m_tokens,cache_write_1h_tokens,cost_micro_cents,last_active_at\n' +
  '2026-03-14,service_account,svcacct_test,"Legacy: a,b@example.com",opencode-go,model-alpha,300,10000,500,40000,0,0,250000000,2026-03-14T10:00:00.000Z\n' +
  '2026-03-14,service_account,svcacct_test,"Legacy: a,b@example.com",opencode-go,model-beta,3,100,50,0,0,0,5000000,2026-03-14T09:00:00.000Z\n' +
  '2026-03-13,service_account,svcacct_test,"Legacy: a,b@example.com",opencode-go,model-alpha,10,200,100,300,0,0,20000000,2026-03-13T10:00:00.000Z\n';

export default function consoleCsvTest() {
  describe('ConsoleCsvTest', () => {
    it('parses_rows_with_quoted_field', 0, () => {
      const rows: CsvUsageRow[] = ConsoleCsv.parse(CSV);
      expect(rows.length).assertEqual(3);
      expect(rows[0].day).assertEqual('2026-03-14');
      expect(rows[0].provider).assertEqual('opencode-go');
      expect(rows[0].model).assertEqual('model-alpha');
      expect(rows[0].requests).assertEqual(300);
      expect(rows[0].inputTokens).assertEqual(10000);
      expect(rows[0].outputTokens).assertEqual(500);
      expect(rows[0].cacheRead).assertEqual(40000);
      // cost_micro_cents → 美元
      expect(rows[0].costUsd).assertEqual(2.5);
    });

    it('aggregates_by_day', 0, () => {
      const days: DailyStat[] = ConsoleCsv.aggregateByDay(ConsoleCsv.parse(CSV));
      expect(days.length).assertEqual(2);
      expect(days[0].date).assertEqual('2026-03-13');
      expect(days[1].date).assertEqual('2026-03-14');
      // 03-14 = 300 + 3 次请求
      expect(days[1].requestCount).assertEqual(303);
      // 总输入 = 未命中输入 + 缓存读 + 缓存写
      expect(days[1].uncachedInputTokens).assertEqual(10100);
      expect(days[1].cacheHitTokens).assertEqual(40000);
      expect(days[1].totalInputTokens).assertEqual(50100);
      expect(days[1].totalOutputTokens).assertEqual(550);
      // 命中率 = 40000 /(40000 + 10100) ≈ 79.8%
      expect(days[1].hitRate > 79 && days[1].hitRate < 81).assertTrue();
    });

    it('tolerates_missing_columns', 0, () => {
      const csv = 'day,model,requests\n2026-03-14,model-alpha,7\n';
      const rows = ConsoleCsv.parse(csv);
      expect(rows.length).assertEqual(1);
      expect(rows[0].requests).assertEqual(7);
      expect(rows[0].inputTokens).assertEqual(0);
      expect(rows[0].costUsd).assertEqual(0);
      expect(rows[0].provider).assertEqual('');
    });

    it('returns_empty_for_garbage', 0, () => {
      expect(ConsoleCsv.parse('').length).assertEqual(0);
      expect(ConsoleCsv.parse('not,a,csv\n1,2,3\n').length).assertEqual(0);
    });

    it('skips_rows_without_day_or_model', 0, () => {
      const csv = 'day,model,requests\n,model-alpha,7\n2026-03-14,,8\n2026-03-14,model-alpha,9\n';
      const rows = ConsoleCsv.parse(csv);
      expect(rows.length).assertEqual(1);
      expect(rows[0].requests).assertEqual(9);
    });
  });
}

// entry/src/main/ets/data/ConsoleCsv.ets
import type { DailyStat } from '../model/Stats';

/** 控制台 v2 CSV 导出的一行（按「天 × 模型」）。 */
export interface CsvUsageRow {
  day: string;
  provider: string;
  model: string;
  requests: number;
  inputTokens: number;
  outputTokens: number;
  cacheRead: number;
  cacheWrite: number;
  costUsd: number;
}

/**
 * 官方控制台用量 CSV 解析（`GET /console/api/v2/usage/export?range=90d`）。
 *
 * 为什么用它：JSON 接口只支持 24h/7d/30d，而 CSV 导出支持 **90d**，且给出
 * 「天 × 模型」粒度的 requests / input / output / cache 明细 —— 用它回填可把
 * 本地历史一次性铺满官方最长窗口，并支持更长期限的模型排行。
 *
 * 实测列名（顺序不依赖，按列名取值）：
 *   day,user_type,user_id,user_name,provider,model,requests,input_tokens,
 *   output_tokens,cache_read_tokens,cache_write_5m_tokens,cache_write_1h_tokens,
 *   cost_micro_cents,last_active_at
 */
export class ConsoleCsv {
  /** 解析 CSV 文本；表头缺失或空文本返回空数组。 */
  static parse(text: string): CsvUsageRow[] {
    const lines = text.split('\n');
    let header: string[] | null = null;
    let idx: Map<string, number> = new Map<string, number>();
    const out: CsvUsageRow[] = [];
    for (const raw of lines) {
      const line = raw.trim();
      if (line === '') {
        continue;
      }
      const cells = ConsoleCsv.splitLine(line);
      if (header === null) {
        // 表头识别：同时含 day 与 model 列
        let hasDay = false;
        let hasModel = false;
        for (const c of cells) {
          if (c.trim() === 'day') {
            hasDay = true;
          }
          if (c.trim() === 'model') {
            hasModel = true;
          }
        }
        if (!hasDay || !hasModel) {
          continue;
        }
        header = cells;
        for (let i = 0; i < cells.length; i++) {
          idx.set(cells[i].trim(), i);
        }
        continue;
      }
      const day = ConsoleCsv.cell(cells, idx, 'day');
      const model = ConsoleCsv.cell(cells, idx, 'model');
      if (day === '' || model === '') {
        continue;
      }
      out.push({
        day: day,
        provider: ConsoleCsv.cell(cells, idx, 'provider'),
        model: model,
        requests: ConsoleCsv.num(ConsoleCsv.cell(cells, idx, 'requests')),
        inputTokens: ConsoleCsv.num(ConsoleCsv.cell(cells, idx, 'input_tokens')),
        outputTokens: ConsoleCsv.num(ConsoleCsv.cell(cells, idx, 'output_tokens')),
        cacheRead: ConsoleCsv.num(ConsoleCsv.cell(cells, idx, 'cache_read_tokens')),
        cacheWrite: ConsoleCsv.num(ConsoleCsv.cell(cells, idx, 'cache_write_5m_tokens')) +
          ConsoleCsv.num(ConsoleCsv.cell(cells, idx, 'cache_write_1h_tokens')),
        // 与其他接口一致：cost 为微美分（1e-8 美元）
        costUsd: ConsoleCsv.num(ConsoleCsv.cell(cells, idx, 'cost_micro_cents')) / 1e8,
      });
    }
    return out;
  }

  /** 按天汇总（用于日粒度历史表 `console_history`）。 */
  static aggregateByDay(rows: CsvUsageRow[]): DailyStat[] {
    const map = new Map<string, DailyStat>();
    for (const r of rows) {
      let d = map.get(r.day);
      if (d === undefined) {
        d = {
          date: r.day, totalInputTokens: 0, uncachedInputTokens: 0, totalReasoningTokens: 0,
          cacheHitTokens: 0, cacheWriteTokens: 0, totalOutputTokens: 0, totalCostUsd: 0,
          requestCount: 0, hitRate: 0,
        };
        map.set(r.day, d);
      }
      // 与本地口径一致：总输入 = 未命中输入 + 缓存读 + 缓存写
      d.uncachedInputTokens += r.inputTokens;
      d.cacheHitTokens += r.cacheRead;
      d.cacheWriteTokens += r.cacheWrite;
      d.totalInputTokens += r.inputTokens + r.cacheRead + r.cacheWrite;
      d.totalOutputTokens += r.outputTokens;
      d.totalCostUsd += r.costUsd;
      d.requestCount += r.requests;
    }
    const out: DailyStat[] = [];
    for (const d of map.values()) {
      const denom = d.cacheHitTokens + d.uncachedInputTokens;
      d.hitRate = denom > 0 ? Number(((d.cacheHitTokens / denom) * 100).toFixed(2)) : 0;
      d.totalCostUsd = Number(d.totalCostUsd.toFixed(6));
      out.push(d);
    }
    out.sort((a, b) => a.date.localeCompare(b.date));
    return out;
  }

  /** 取某列（缺失返回空串）。 */
  private static cell(cells: string[], idx: Map<string, number>, name: string): string {
    const i = idx.get(name);
    if (i === undefined || i >= cells.length) {
      return '';
    }
    return cells[i].trim();
  }

  private static num(v: string): number {
    const n = Number(v);
    return Number.isNaN(n) ? 0 : n;
  }

  /** 极简 CSV 行拆分：支持双引号包裹字段（内部逗号/双引号转义）。 */
  private static splitLine(line: string): string[] {
    const out: string[] = [];
    let cur = '';
    let inQuote = false;
    for (let i = 0; i < line.length; i++) {
      const ch = line.charAt(i);
      if (inQuote) {
        if (ch === '"') {
          if (i + 1 < line.length && line.charAt(i + 1) === '"') {
            cur += '"';
            i++;
          } else {
            inQuote = false;
          }
        } else {
          cur += ch;
        }
      } else if (ch === '"') {
        inQuote = true;
      } else if (ch === ',') {
        out.push(cur);
        cur = '';
      } else {
        cur += ch;
      }
    }
    out.push(cur);
    return out;
  }
}
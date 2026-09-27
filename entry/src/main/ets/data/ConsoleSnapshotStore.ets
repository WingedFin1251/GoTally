// entry/src/main/ets/data/ConsoleSnapshotStore.ets
import { relationalStore } from '@kit.ArkData';
import { RdbHelper } from './RdbHelper';
import type { Totals, ModelStat, DailyStat } from '../model/Stats';
import type { QuotaWindow } from '../model/UsageRecord';

/**
 * 官方聚合数据本地快照（离线可看）。
 *
 * 去重设计（防止同一份数据存多份）：
 *  1. **主键去重**：总量按 `range_key`、模型按 `(range_key, model)`、逐日按 `(range_key, date)`、
 *     配额按 `label` 做 INSERT OR REPLACE —— 同一维度只保留一份。
 *  2. **批内去重**：接口若重复返回同一 model/date，先按主键合并（见 dedupeXxx）。
 *  3. **集合级裁剪**：每次写入后删除「本次不在集合中」的旧行，避免历史行残留堆积。
 */
export class ConsoleSnapshotStore {
  // ---- 批内去重（纯函数，便于单测）----

  /** 同一 model 只保留最后一条。 */
  static dedupeModels(models: ModelStat[]): ModelStat[] {
    const map = new Map<string, ModelStat>();
    for (const m of models) {
      if (m.model !== '') {
        map.set(m.model, m);
      }
    }
    return Array.from(map.values());
  }

  /** 同一天只保留最后一条。 */
  static dedupeDays(days: DailyStat[]): DailyStat[] {
    const map = new Map<string, DailyStat>();
    for (const d of days) {
      if (d.date !== '') {
        map.set(d.date, d);
      }
    }
    return Array.from(map.values());
  }

  /** 同一窗口标签只保留最后一条。 */
  static dedupeQuota(windows: QuotaWindow[]): QuotaWindow[] {
    const map = new Map<string, QuotaWindow>();
    for (const w of windows) {
      if (w.label !== '') {
        map.set(w.label, w);
      }
    }
    return Array.from(map.values());
  }

  // ---- 写入 ----

  static async saveTotals(rangeKey: string, t: Totals): Promise<void> {
    try {
      const store = await RdbHelper.getStore();
      await store.executeSql(
        `INSERT OR REPLACE INTO console_totals
         (range_key, request_count, uncached_input, output_tokens, cache_read, cache_write, reasoning, cost_usd, hit_rate, updated_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        [rangeKey, t.requestCount, t.uncachedInputTokens, t.totalOutputTokens, t.cacheHitTokens,
          t.cacheWriteTokens, t.totalReasoningTokens, t.totalCostUsd, t.hitRate, RdbHelper.nowIso()]);
    } catch (e) {
      console.error('saveTotals failed: ' + (e instanceof Error ? e.message : String(e)));
    }
  }

  static async saveModels(rangeKey: string, models: ModelStat[]): Promise<void> {
    try {
      const store = await RdbHelper.getStore();
      const rows = ConsoleSnapshotStore.dedupeModels(models);
      const keep: string[] = [];
      for (const m of rows) {
        keep.push(m.model);
      }
      // 集合级裁剪：本次没返回的模型行删掉，避免旧行残留
      if (keep.length > 0) {
        const ph = keep.map((x: string): string => '?').join(',');
        const args: relationalStore.ValueType[] = [rangeKey];
        for (const k of keep) {
          args.push(k);
        }
        await store.executeSql(`DELETE FROM console_models WHERE range_key = ? AND model NOT IN (${ph})`, args);
      } else {
        await store.executeSql('DELETE FROM console_models WHERE range_key = ?', [rangeKey]);
      }
      const now = RdbHelper.nowIso();
      for (const m of rows) {
        await store.executeSql(
          `INSERT OR REPLACE INTO console_models
           (range_key, model, request_count, total_input, uncached_input, output_tokens, cache_read, cache_write, reasoning, cost_usd, hit_rate, updated_at)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
          [rangeKey, m.model, m.requestCount, m.totalInputTokens, m.uncachedInputTokens, m.totalOutputTokens,
            m.cacheHitTokens, m.cacheWriteTokens, m.totalReasoningTokens, m.totalCostUsd, m.hitRate, now]);
      }
    } catch (e) {
      console.error('saveModels failed: ' + (e instanceof Error ? e.message : String(e)));
    }
  }

  static async saveDaily(rangeKey: string, days: DailyStat[]): Promise<void> {
    try {
      const store = await RdbHelper.getStore();
      const rows = ConsoleSnapshotStore.dedupeDays(days);
      const keep: string[] = [];
      for (const d of rows) {
        keep.push(d.date);
      }
      if (keep.length > 0) {
        const ph = keep.map((x: string): string => '?').join(',');
        const args: relationalStore.ValueType[] = [rangeKey];
        for (const k of keep) {
          args.push(k);
        }
        await store.executeSql(`DELETE FROM console_daily WHERE range_key = ? AND date NOT IN (${ph})`, args);
      } else {
        await store.executeSql('DELETE FROM console_daily WHERE range_key = ?', [rangeKey]);
      }
      const now = RdbHelper.nowIso();
      for (const d of rows) {
        await store.executeSql(
          `INSERT OR REPLACE INTO console_daily (range_key, date, tokens, cost_usd, request_count, updated_at)
           VALUES (?, ?, ?, ?, ?, ?)`,
          [rangeKey, d.date, d.totalInputTokens, d.totalCostUsd, d.requestCount, now]);
      }
    } catch (e) {
      console.error('saveDaily failed: ' + (e instanceof Error ? e.message : String(e)));
    }
  }

  static async saveQuota(windows: QuotaWindow[]): Promise<void> {
    try {
      const store = await RdbHelper.getStore();
      const rows = ConsoleSnapshotStore.dedupeQuota(windows);
      const now = RdbHelper.nowIso();
      for (const w of rows) {
        const usedUsd = w.usedUsd !== undefined ? w.usedUsd : -1;
        const limitUsd = w.limitUsd !== undefined ? w.limitUsd : -1;
        await store.executeSql(
          `INSERT OR REPLACE INTO console_quota
           (label, used, remaining, reset_at, reset_in_sec, used_usd, limit_usd, updated_at)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
          [w.label, w.used, w.remaining, w.resetAt, w.resetInSec, usedUsd, limitUsd, now]);
      }
    } catch (e) {
      console.error('saveQuota failed: ' + (e instanceof Error ? e.message : String(e)));
    }
  }

  // ---- 读取（离线兜底）----

  static async loadTotals(rangeKey: string): Promise<Totals | null> {
    try {
      const store = await RdbHelper.getStore();
      const rs = await store.querySql(
        `SELECT request_count, uncached_input, output_tokens, cache_read, cache_write, reasoning, cost_usd, hit_rate
         FROM console_totals WHERE range_key = ?`, [rangeKey]);
      let out: Totals | null = null;
      if (rs.goToFirstRow()) {
        const l = (n: string): number => rs.getLong(rs.getColumnIndex(n));
        const d = (n: string): number => rs.getDouble(rs.getColumnIndex(n));
        const uncached = l('uncached_input');
        const cacheRead = l('cache_read');
        const cacheWrite = l('cache_write');
        out = {
          requestCount: l('request_count'),
          sessionCount: 0,
          totalInputTokens: uncached + cacheRead + cacheWrite,
          uncachedInputTokens: uncached,
          totalReasoningTokens: l('reasoning'),
          cacheHitTokens: cacheRead,
          cacheWriteTokens: cacheWrite,
          totalOutputTokens: l('output_tokens'),
          totalCostUsd: d('cost_usd'),
          hitRate: d('hit_rate'),
        };
      }
      rs.close();
      return out;
    } catch (e) {
      console.error('loadTotals failed: ' + (e instanceof Error ? e.message : String(e)));
      return null;
    }
  }

  static async loadModels(rangeKey: string): Promise<ModelStat[]> {
    const out: ModelStat[] = [];
    try {
      const store = await RdbHelper.getStore();
      const rs = await store.querySql(
        `SELECT model, request_count, total_input, uncached_input, output_tokens, cache_read, cache_write, reasoning, cost_usd, hit_rate
         FROM console_models WHERE range_key = ?
         ORDER BY (total_input + output_tokens) DESC`, [rangeKey]);
      while (rs.goToNextRow()) {
        const l = (n: string): number => rs.getLong(rs.getColumnIndex(n));
        const d = (n: string): number => rs.getDouble(rs.getColumnIndex(n));
        out.push({
          model: rs.getString(rs.getColumnIndex('model')),
          requestCount: l('request_count'),
          sessionCount: 0,
          totalInputTokens: l('total_input'),
          uncachedInputTokens: l('uncached_input'),
          totalReasoningTokens: l('reasoning'),
          cacheHitTokens: l('cache_read'),
          cacheWriteTokens: l('cache_write'),
          totalOutputTokens: l('output_tokens'),
          totalCostUsd: d('cost_usd'),
          hitRate: d('hit_rate'),
        });
      }
      rs.close();
    } catch (e) {
      console.error('loadModels failed: ' + (e instanceof Error ? e.message : String(e)));
    }
    return out;
  }

  static async loadDaily(rangeKey: string): Promise<DailyStat[]> {
    const out: DailyStat[] = [];
    try {
      const store = await RdbHelper.getStore();
      const rs = await store.querySql(
        `SELECT date, tokens, cost_usd, request_count FROM console_daily
         WHERE range_key = ? ORDER BY date ASC`, [rangeKey]);
      while (rs.goToNextRow()) {
        out.push({
          date: rs.getString(rs.getColumnIndex('date')),
          totalInputTokens: rs.getLong(rs.getColumnIndex('tokens')),
          uncachedInputTokens: 0,
          totalReasoningTokens: 0,
          cacheHitTokens: 0,
          cacheWriteTokens: 0,
          totalOutputTokens: 0,
          totalCostUsd: rs.getDouble(rs.getColumnIndex('cost_usd')),
          requestCount: rs.getLong(rs.getColumnIndex('request_count')),
          hitRate: 0,
        });
      }
      rs.close();
    } catch (e) {
      console.error('loadDaily failed: ' + (e instanceof Error ? e.message : String(e)));
    }
    return out;
  }

  static async loadQuota(): Promise<QuotaWindow[]> {
    const out: QuotaWindow[] = [];
    try {
      const store = await RdbHelper.getStore();
      const rs = await store.querySql(
        `SELECT label, used, remaining, reset_at, reset_in_sec, used_usd, limit_usd FROM console_quota`);
      while (rs.goToNextRow()) {
        const usedUsd = rs.getDouble(rs.getColumnIndex('used_usd'));
        const limitUsd = rs.getDouble(rs.getColumnIndex('limit_usd'));
        const w: QuotaWindow = {
          label: rs.getString(rs.getColumnIndex('label')),
          used: rs.getDouble(rs.getColumnIndex('used')),
          remaining: rs.getDouble(rs.getColumnIndex('remaining')),
          total: 100,
          unit: '%',
          resetAt: rs.getString(rs.getColumnIndex('reset_at')),
          resetInSec: rs.getLong(rs.getColumnIndex('reset_in_sec')),
        };
        if (usedUsd >= 0 && limitUsd > 0) {
          w.usedUsd = usedUsd;
          w.limitUsd = limitUsd;
        }
        out.push(w);
      }
      rs.close();
    } catch (e) {
      console.error('loadQuota failed: ' + (e instanceof Error ? e.message : String(e)));
    }
    return out;
  }
}
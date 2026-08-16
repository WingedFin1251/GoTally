// entry/src/main/ets/data/UsageRepository.ets
import { relationalStore } from '@kit.ArkData';
import { RdbHelper } from './RdbHelper';
import { SettingsStore } from './SettingsStore';
import type { UsageStore, UsageDataStore } from './UsageStore';
import type { UsageRecord, SyncState } from '../model/UsageRecord';
import type { Totals, ModelStat, DailyStat, TrendPoint, SessionStat, RecordRow } from '../model/Stats';
import { Constants } from '../common/constants/Constants';

interface PeriodFilter {
  where: string;
  params: relationalStore.ValueType[];
}

interface HourBucket {
  input: number;
  output: number;
  reasoning: number;
}

const rowAsUsageRecord = (rs: relationalStore.ResultSet): UsageRecord => {
  const i = (name: string): number => rs.getColumnIndex(name);
  return {
    usgId: rs.getString(i('usg_id')),
    createdAt: rs.getString(i('created_at')),
    model: rs.getString(i('model')),
    provider: rs.getString(i('provider')),
    inputTokens: rs.getLong(i('input_tokens')),
    outputTokens: rs.getLong(i('output_tokens')),
    reasoningTokens: rs.getLong(i('reasoning_tokens')),
    cacheReadTokens: rs.getLong(i('cache_read_tokens')),
    cacheWrite5mTokens: rs.getLong(i('cache_write_5m_tokens')),
    cacheWrite1hTokens: rs.getLong(i('cache_write_1h_tokens')),
    costRaw: rs.getLong(i('cost_raw')),
    costUsd: rs.getDouble(i('cost_usd')),
    keyId: rs.getString(i('key_id')),
    sessionId: rs.getString(i('session_id')),
    plan: rs.getString(i('plan')),
    syncedAt: rs.getString(i('synced_at')),
  };
};

/** 账户 + 用量记录 + 同步状态的 RDB 实现，并承载全部聚合查询。 */
export class UsageRepository implements UsageDataStore {
  // ---- 周期过滤（对齐 db.py _period_where） ----
  private static periodWhere(period: string): PeriodFilter {
    let clause = '';
    const params: relationalStore.ValueType[] = [];
    if (period === Constants.PERIOD_TODAY) {
      clause = `substr(datetime(created_at, 'localtime'), 1, 10) = date('now', 'localtime')`;
    } else if (period === Constants.PERIOD_ALL) {
      clause = '';
    } else {
      const m = /^(\d+)d$/.exec(period);
      const days = m !== null ? Math.max(1, Number(m[1])) : 30;
      clause = `datetime(created_at) >= datetime('now', ?)`;
      params.push(`-${days} days`);
    }
    return { where: clause === '' ? '' : `WHERE ${clause}`, params: params };
  }

  private static hitRate(hit: number, miss: number): number {
    if (hit + miss <= 0) {
      return 0;
    }
    return Number(((hit / (hit + miss)) * 100).toFixed(2));
  }

  // ---- 账户 ----
  async getToken(): Promise<string> {
    const store = await RdbHelper.getStore();
    const rs = await store.querySql('SELECT token FROM account WHERE id = 1');
    let token = '';
    if (rs.goToFirstRow()) {
      token = rs.getString(rs.getColumnIndex('token'));
    }
    rs.close();
    return token;
  }

  async getWorkspaceHint(): Promise<string> {
    const store = await RdbHelper.getStore();
    const rs = await store.querySql('SELECT workspace_id, resolved_workspace_id FROM account WHERE id = 1');
    let hint = 'Default';
    if (rs.goToFirstRow()) {
      const resolved = rs.getString(rs.getColumnIndex('resolved_workspace_id'));
      const ws = rs.getString(rs.getColumnIndex('workspace_id'));
      hint = resolved !== '' ? resolved : (ws !== '' ? ws : 'Default');
    }
    rs.close();
    return hint;
  }

  async saveResolvedWorkspace(workspaceId: string): Promise<void> {
    const store = await RdbHelper.getStore();
    const values: relationalStore.ValuesBucket = {
      'resolved_workspace_id': workspaceId,
      'updated_at': RdbHelper.nowIso(),
    };
    const predicates = new relationalStore.RdbPredicates('account');
    predicates.equalTo('id', 1);
    await store.update(values, predicates);
  }

  async saveToken(token: string, workspaceId: string): Promise<void> {
    const store = await RdbHelper.getStore();
    const now = RdbHelper.nowIso();
    const values: relationalStore.ValuesBucket = {
      'token': token,
      'workspace_id': workspaceId,
      'resolved_workspace_id': null,
      'updated_at': now,
    };
    const predicates = new relationalStore.RdbPredicates('account');
    predicates.equalTo('id', 1);
    await store.update(values, predicates);
    await store.executeSql('UPDATE usage_sync_state SET deepest_page_fetched = -1 WHERE id = 1');
  }

  async clearAccount(): Promise<void> {
    const store = await RdbHelper.getStore();
    await store.executeSql('DELETE FROM usage_records');
    await store.executeSql(
      `UPDATE account SET token = '', resolved_workspace_id = NULL, updated_at = ? WHERE id = 1`,
      [RdbHelper.nowIso()]);
    await store.executeSql(
      `UPDATE usage_sync_state SET last_sync_status = NULL, last_sync_error = NULL,
         last_inserted_count = 0, deepest_page_fetched = -1, total_records = 0,
         oldest_record_at = NULL, newest_record_at = NULL WHERE id = 1`);
  }

  // ---- 记录写入 ----
  async insertUsageRecords(records: UsageRecord[]): Promise<number> {
    if (records.length === 0) {
      return 0;
    }
    const store = await RdbHelper.getStore();
    const syncedAt = RdbHelper.nowIso();
    let inserted = 0;
    for (const rec of records) {
      const existing = await store.querySql('SELECT 1 FROM usage_records WHERE usg_id = ?', [rec.usgId]);
      const existed = existing.goToFirstRow();
      existing.close();
      const values: relationalStore.ValuesBucket = {
        'usg_id': rec.usgId,
        'created_at': rec.createdAt,
        'model': rec.model,
        'provider': rec.provider,
        'input_tokens': rec.inputTokens,
        'output_tokens': rec.outputTokens,
        'reasoning_tokens': rec.reasoningTokens,
        'cache_read_tokens': rec.cacheReadTokens,
        'cache_write_5m_tokens': rec.cacheWrite5mTokens,
        'cache_write_1h_tokens': rec.cacheWrite1hTokens,
        'cost_raw': rec.costRaw,
        'cost_usd': rec.costUsd,
        'key_id': rec.keyId,
        'session_id': rec.sessionId,
        'plan': rec.plan,
        'synced_at': syncedAt,
      };
      if (existed) {
        const predicates = new relationalStore.RdbPredicates('usage_records');
        predicates.equalTo('usg_id', rec.usgId);
        const upd: relationalStore.ValuesBucket = {
          'input_tokens': rec.inputTokens,
          'output_tokens': rec.outputTokens,
          'reasoning_tokens': rec.reasoningTokens,
          'cache_read_tokens': rec.cacheReadTokens,
          'cache_write_5m_tokens': rec.cacheWrite5mTokens,
          'cache_write_1h_tokens': rec.cacheWrite1hTokens,
          'cost_raw': rec.costRaw,
          'cost_usd': rec.costUsd,
          'synced_at': syncedAt,
        };
        await store.update(upd, predicates);
      } else {
        await store.insert('usage_records', values);
        inserted += 1;
      }
    }
    await this.refreshSyncTotals();
    return inserted;
  }

  async pruneOldRecords(windowDays: number): Promise<number> {
    if (windowDays <= 0) {
      return 0;
    }
    const store = await RdbHelper.getStore();
    await store.executeSql(
      `DELETE FROM usage_records WHERE datetime(created_at) < datetime('now', ?)`,
      [`-${windowDays} days`]);
    await this.refreshSyncTotals();
    return 0; // RDB 不直接暴露删除行数，返回 0 即可（调用方不依赖精确值）
  }

  async refreshSyncTotals(): Promise<void> {
    const store = await RdbHelper.getStore();
    const rs = await store.querySql(
      `SELECT COUNT(*) AS total, MIN(created_at) AS oldest, MAX(created_at) AS newest FROM usage_records`);
    let total = 0;
    let oldest = '';
    let newest = '';
    if (rs.goToFirstRow()) {
      total = rs.getLong(rs.getColumnIndex('total'));
      oldest = rs.getString(rs.getColumnIndex('oldest'));
      newest = rs.getString(rs.getColumnIndex('newest'));
    }
    rs.close();
    await store.executeSql(
      `UPDATE usage_sync_state SET total_records = ?, oldest_record_at = ?, newest_record_at = ? WHERE id = 1`,
      [total, oldest, newest]);
  }

  async getWindowDays(): Promise<number | null> {
    return SettingsStore.getWindowDays();
  }

  async updateSyncState(status: string, error: string, inserted: number): Promise<void> {
    const store = await RdbHelper.getStore();
    await store.executeSql(
      `UPDATE usage_sync_state
         SET last_sync_at = ?, last_sync_status = ?, last_sync_error = ?,
             last_inserted_count = last_inserted_count + ?
       WHERE id = 1`,
      [RdbHelper.nowIso(), status, error, inserted]);
    await this.refreshSyncTotals();
  }

  async getSyncState(): Promise<SyncState> {
    const store = await RdbHelper.getStore();
    const rs = await store.querySql('SELECT * FROM usage_sync_state WHERE id = 1');
    const state: SyncState = {
      lastSyncAt: '', lastSyncStatus: '', lastSyncError: '', lastInsertedCount: 0,
      deepestPageFetched: -1, totalRecords: 0, oldestRecordAt: '', newestRecordAt: '',
    };
    if (rs.goToFirstRow()) {
      const s = (n: string): string => rs.getString(rs.getColumnIndex(n));
      const l = (n: string): number => rs.getLong(rs.getColumnIndex(n));
      state.lastSyncAt = s('last_sync_at');
      state.lastSyncStatus = s('last_sync_status');
      state.lastSyncError = s('last_sync_error');
      state.lastInsertedCount = l('last_inserted_count');
      state.deepestPageFetched = l('deepest_page_fetched');
      state.totalRecords = l('total_records');
      state.oldestRecordAt = s('oldest_record_at');
      state.newestRecordAt = s('newest_record_at');
    }
    rs.close();
    return state;
  }

  // ---- 聚合 ----
  async totals(period: string): Promise<Totals> {
    const f = UsageRepository.periodWhere(period);
    const store = await RdbHelper.getStore();
    const rs = await store.querySql(
      `SELECT COUNT(*) AS request_count,
              COUNT(DISTINCT CASE WHEN session_id IS NOT NULL AND session_id != '' THEN session_id END) AS session_count,
              SUM(input_tokens + cache_read_tokens + cache_write_5m_tokens + cache_write_1h_tokens) AS total_input_tokens,
              SUM(input_tokens) AS uncached_input_tokens,
              SUM(reasoning_tokens) AS total_reasoning_tokens,
              SUM(cache_read_tokens) AS cache_hit_tokens,
              SUM(cache_write_5m_tokens + cache_write_1h_tokens) AS cache_write_tokens,
              SUM(output_tokens) AS total_output_tokens,
              SUM(cost_usd) AS total_cost_usd
       FROM usage_records ${f.where}`, f.params);
    const out: Totals = {
      requestCount: 0, sessionCount: 0, totalInputTokens: 0, uncachedInputTokens: 0,
      totalReasoningTokens: 0, cacheHitTokens: 0, cacheWriteTokens: 0,
      totalOutputTokens: 0, totalCostUsd: 0, hitRate: 0,
    };
    if (rs.goToFirstRow()) {
      const l = (n: string): number => rs.getLong(rs.getColumnIndex(n));
      const d = (n: string): number => rs.getDouble(rs.getColumnIndex(n));
      out.requestCount = l('request_count');
      out.sessionCount = l('session_count');
      out.totalInputTokens = l('total_input_tokens');
      out.uncachedInputTokens = l('uncached_input_tokens');
      out.totalReasoningTokens = l('total_reasoning_tokens');
      out.cacheHitTokens = l('cache_hit_tokens');
      out.cacheWriteTokens = l('cache_write_tokens');
      out.totalOutputTokens = l('total_output_tokens');
      out.totalCostUsd = d('total_cost_usd');
      out.hitRate = UsageRepository.hitRate(out.cacheHitTokens, out.uncachedInputTokens);
    }
    rs.close();
    return out;
  }

  async modelStats(period: string): Promise<ModelStat[]> {
    const f = UsageRepository.periodWhere(period);
    const store = await RdbHelper.getStore();
    const rs = await store.querySql(
      `SELECT model,
              COUNT(*) AS request_count,
              COUNT(DISTINCT CASE WHEN session_id IS NOT NULL AND session_id != '' THEN session_id END) AS session_count,
              SUM(input_tokens + cache_read_tokens + cache_write_5m_tokens + cache_write_1h_tokens) AS total_input_tokens,
              SUM(input_tokens) AS uncached_input_tokens,
              SUM(reasoning_tokens) AS total_reasoning_tokens,
              SUM(cache_read_tokens) AS cache_hit_tokens,
              SUM(cache_write_5m_tokens + cache_write_1h_tokens) AS cache_write_tokens,
              SUM(output_tokens) AS total_output_tokens,
              SUM(cost_usd) AS total_cost_usd
       FROM usage_records ${f.where}
       GROUP BY model
       ORDER BY (SUM(input_tokens + cache_read_tokens + cache_write_5m_tokens + cache_write_1h_tokens) + SUM(output_tokens)) DESC`, f.params);
    const out: ModelStat[] = [];
    while (rs.goToNextRow()) {
      const l = (n: string): number => rs.getLong(rs.getColumnIndex(n));
      const d = (n: string): number => rs.getDouble(rs.getColumnIndex(n));
      const hit = l('cache_hit_tokens');
      const miss = l('uncached_input_tokens');
      out.push({
        model: rs.getString(rs.getColumnIndex('model')),
        requestCount: l('request_count'),
        sessionCount: l('session_count'),
        totalInputTokens: l('total_input_tokens'),
        uncachedInputTokens: miss,
        totalReasoningTokens: l('total_reasoning_tokens'),
        cacheHitTokens: hit,
        cacheWriteTokens: l('cache_write_tokens'),
        totalOutputTokens: l('total_output_tokens'),
        totalCostUsd: d('total_cost_usd'),
        hitRate: UsageRepository.hitRate(hit, miss),
      });
    }
    rs.close();
    return out;
  }

  async dailyStats(days: number): Promise<DailyStat[]> {
    const store = await RdbHelper.getStore();
    const rs = await store.querySql(
      `SELECT substr(datetime(created_at, 'localtime'), 1, 10) AS date,
              SUM(input_tokens + cache_read_tokens + cache_write_5m_tokens + cache_write_1h_tokens) AS total_input_tokens,
              SUM(input_tokens) AS uncached_input_tokens,
              SUM(reasoning_tokens) AS total_reasoning_tokens,
              SUM(cache_read_tokens) AS cache_hit_tokens,
              SUM(cache_write_5m_tokens + cache_write_1h_tokens) AS cache_write_tokens,
              SUM(output_tokens) AS total_output_tokens,
              SUM(cost_usd) AS total_cost_usd,
              COUNT(*) AS request_count
       FROM usage_records
       WHERE substr(datetime(created_at, 'localtime'), 1, 10) >= date('now', 'localtime', ?)
       GROUP BY substr(datetime(created_at, 'localtime'), 1, 10)
       ORDER BY date ASC`, [`-${days} days`]);
    const out: DailyStat[] = [];
    while (rs.goToNextRow()) {
      const l = (n: string): number => rs.getLong(rs.getColumnIndex(n));
      const d = (n: string): number => rs.getDouble(rs.getColumnIndex(n));
      const hit = l('cache_hit_tokens');
      const miss = l('uncached_input_tokens');
      out.push({
        date: rs.getString(rs.getColumnIndex('date')),
        totalInputTokens: l('total_input_tokens'),
        uncachedInputTokens: miss,
        totalReasoningTokens: l('total_reasoning_tokens'),
        cacheHitTokens: hit,
        cacheWriteTokens: l('cache_write_tokens'),
        totalOutputTokens: l('total_output_tokens'),
        totalCostUsd: d('total_cost_usd'),
        requestCount: l('request_count'),
        hitRate: UsageRepository.hitRate(hit, miss),
      });
    }
    rs.close();
    return out;
  }

  async todayTrend(): Promise<TrendPoint[]> {
    const store = await RdbHelper.getStore();
    const rs = await store.querySql(
      `SELECT CAST(strftime('%H', datetime(created_at, 'localtime')) AS INTEGER) AS h,
              SUM(input_tokens) AS input,
              SUM(output_tokens) AS output,
              SUM(reasoning_tokens) AS reasoning
       FROM usage_records
       WHERE substr(datetime(created_at, 'localtime'), 1, 10) = date('now', 'localtime')
       GROUP BY h`);
    const byHour = new Map<number, HourBucket>();
    while (rs.goToNextRow()) {
      const h = rs.getLong(rs.getColumnIndex('h'));
      byHour.set(h, {
        input: rs.getLong(rs.getColumnIndex('input')),
        output: rs.getLong(rs.getColumnIndex('output')),
        reasoning: rs.getLong(rs.getColumnIndex('reasoning')),
      });
    }
    rs.close();
    const out: TrendPoint[] = [];
    for (let h = 0; h < 24; h++) {
      const item = byHour.get(h);
      const p = (v: number): string => (v < 10 ? `0${v}` : `${v}`);
      out.push({
        hour: `${p(h)}:00`,
        input: item !== undefined ? item.input : 0,
        output: item !== undefined ? item.output : 0,
        reasoning: item !== undefined ? item.reasoning : 0,
      });
    }
    return out;
  }

  async sessionStatsPage(page: number, pageSize: number, days: number | null): Promise<[SessionStat[], number]> {
    const store = await RdbHelper.getStore();
    const where = days !== null && days > 0 ? `WHERE datetime(created_at) >= datetime('now', '-${days} days')` : '';
    const totalRs = await store.querySql(
      `SELECT COUNT(DISTINCT CASE WHEN session_id IS NULL OR session_id = '' THEN '' ELSE session_id END) AS c
       FROM usage_records ${where}`);
    let total = 0;
    if (totalRs.goToFirstRow()) {
      total = totalRs.getLong(totalRs.getColumnIndex('c'));
    }
    totalRs.close();
    const offset = (page - 1) * pageSize;
    const rs = await store.querySql(
      `SELECT CASE WHEN session_id IS NULL OR session_id = '' THEN '' ELSE session_id END AS session_id,
              COUNT(*) AS request_count,
              SUM(input_tokens + cache_read_tokens + cache_write_5m_tokens + cache_write_1h_tokens) AS total_input_tokens,
              SUM(input_tokens) AS uncached_input_tokens,
              SUM(output_tokens) AS total_output_tokens,
              SUM(reasoning_tokens) AS total_reasoning_tokens,
              SUM(cost_usd) AS total_cost_usd,
              MAX(created_at) AS last_at
       FROM usage_records ${where}
       GROUP BY session_id
       ORDER BY last_at DESC
       LIMIT ? OFFSET ?`, [pageSize, offset]);
    const out: SessionStat[] = [];
    while (rs.goToNextRow()) {
      const l = (n: string): number => rs.getLong(rs.getColumnIndex(n));
      const d = (n: string): number => rs.getDouble(rs.getColumnIndex(n));
      out.push({
        sessionId: rs.getString(rs.getColumnIndex('session_id')),
        requestCount: l('request_count'),
        totalInputTokens: l('total_input_tokens'),
        uncachedInputTokens: l('uncached_input_tokens'),
        totalOutputTokens: l('total_output_tokens'),
        totalReasoningTokens: l('total_reasoning_tokens'),
        totalCostUsd: d('total_cost_usd'),
        lastAt: rs.getString(rs.getColumnIndex('last_at')),
      });
    }
    rs.close();
    return [out, total];
  }

  async usageRecordsPage(page: number, pageSize: number, model: string | null, days: number | null): Promise<[RecordRow[], number]> {
    const store = await RdbHelper.getStore();
    const conds: string[] = [];
    const params: relationalStore.ValueType[] = [];
    if (model !== null && model !== '') {
      conds.push('model = ?');
      params.push(model);
    }
    if (days !== null && days > 0) {
      conds.push(`datetime(created_at) >= datetime('now', '-${days} days')`);
    }
    const where = conds.length > 0 ? `WHERE ${conds.join(' AND ')}` : '';
    const countRs = await store.querySql(`SELECT COUNT(*) AS c FROM usage_records ${where}`, params);
    let total = 0;
    if (countRs.goToFirstRow()) {
      total = countRs.getLong(countRs.getColumnIndex('c'));
    }
    countRs.close();
    const offset = (page - 1) * pageSize;
    const rs = await store.querySql(
      `SELECT * FROM usage_records ${where} ORDER BY created_at DESC LIMIT ? OFFSET ?`,
      [...params, pageSize, offset]);
    const out: RecordRow[] = [];
    while (rs.goToNextRow()) {
      const rec = rowAsUsageRecord(rs);
      out.push({
        usgId: rec.usgId,
        createdAt: rec.createdAt,
        model: rec.model,
        provider: rec.provider,
        inputTokens: rec.inputTokens,
        outputTokens: rec.outputTokens,
        reasoningTokens: rec.reasoningTokens,
        cacheReadTokens: rec.cacheReadTokens,
        cacheWriteTokens: rec.cacheWrite5mTokens + rec.cacheWrite1hTokens,
        costUsd: rec.costUsd,
        sessionId: rec.sessionId,
        plan: rec.plan,
      });
    }
    rs.close();
    return [out, total];
  }

  async listModels(): Promise<string[]> {
    const store = await RdbHelper.getStore();
    const rs = await store.querySql('SELECT DISTINCT model FROM usage_records ORDER BY model');
    const out: string[] = [];
    while (rs.goToNextRow()) {
      out.push(rs.getString(rs.getColumnIndex('model')));
    }
    rs.close();
    return out;
  }
}

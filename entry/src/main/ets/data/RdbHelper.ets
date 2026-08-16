// entry/src/main/ets/data/RdbHelper.ets
import { relationalStore } from '@kit.ArkData';
import { AppContext } from '../common/AppContext';
import { Constants } from '../common/constants/Constants';

// RDB executeSql 一次只执行一条语句，schema 拆成数组逐条执行
const SCHEMA_STATEMENTS: string[] = [
  `CREATE TABLE IF NOT EXISTS usage_records (
     usg_id TEXT PRIMARY KEY,
     created_at TEXT NOT NULL,
     model TEXT NOT NULL,
     provider TEXT,
     input_tokens INTEGER NOT NULL,
     output_tokens INTEGER NOT NULL,
     reasoning_tokens INTEGER NOT NULL DEFAULT 0,
     cache_read_tokens INTEGER NOT NULL DEFAULT 0,
     cache_write_5m_tokens INTEGER NOT NULL DEFAULT 0,
     cache_write_1h_tokens INTEGER NOT NULL DEFAULT 0,
     cost_raw INTEGER NOT NULL,
     cost_usd REAL NOT NULL,
     key_id TEXT,
     session_id TEXT,
     plan TEXT,
     synced_at TEXT NOT NULL
   );`,
  `CREATE INDEX IF NOT EXISTS idx_usage_time ON usage_records(created_at DESC);`,
  `CREATE TABLE IF NOT EXISTS usage_sync_state (
     id INTEGER PRIMARY KEY CHECK (id = 1),
     last_sync_at TEXT,
     last_sync_status TEXT,
     last_sync_error TEXT,
     last_inserted_count INTEGER NOT NULL DEFAULT 0,
     deepest_page_fetched INTEGER NOT NULL DEFAULT -1,
     total_records INTEGER NOT NULL DEFAULT 0,
     oldest_record_at TEXT,
     newest_record_at TEXT
   );`,
  `CREATE TABLE IF NOT EXISTS account (
     id INTEGER PRIMARY KEY CHECK (id = 1),
     name TEXT NOT NULL DEFAULT 'Default',
     workspace_id TEXT NOT NULL DEFAULT 'Default',
     resolved_workspace_id TEXT,
     token TEXT NOT NULL DEFAULT '',
     created_at TEXT NOT NULL,
     updated_at TEXT NOT NULL
   );`,
];

/** RDB 单例：建库建表，初始化单行表。 */
export class RdbHelper {
  private static store: relationalStore.RdbStore | null = null;

  static async getStore(): Promise<relationalStore.RdbStore> {
    if (RdbHelper.store !== null) {
      return RdbHelper.store;
    }
    const ctx = AppContext.get();
    const config: relationalStore.StoreConfig = {
      name: Constants.DB_NAME,
      securityLevel: relationalStore.SecurityLevel.S1,
    };
    const store = await relationalStore.getRdbStore(ctx, config);
    for (const stmt of SCHEMA_STATEMENTS) {
      await store.executeSql(stmt);
    }
    // 初始化单行：account / usage_sync_state
    const acct = await store.querySql('SELECT id FROM account WHERE id = 1');
    let acctExists = false;
    if (acct.goToFirstRow()) {
      acctExists = true;
    }
    acct.close();
    if (!acctExists) {
      const now = RdbHelper.nowIso();
      await store.executeSql(
        `INSERT INTO account (id, name, workspace_id, resolved_workspace_id, token, created_at, updated_at)
         VALUES (1, 'Default', 'Default', NULL, '', ?, ?)`, [now, now]);
    }
    const sync = await store.querySql('SELECT id FROM usage_sync_state WHERE id = 1');
    let syncExists = false;
    if (sync.goToFirstRow()) {
      syncExists = true;
    }
    sync.close();
    if (!syncExists) {
      await store.executeSql('INSERT INTO usage_sync_state (id) VALUES (1)');
    }
    RdbHelper.store = store;
    return store;
  }

  static nowIso(): string {
    return new Date().toISOString();
  }
}

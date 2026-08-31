// entry/src/main/ets/data/RdbHelper.ets
import { relationalStore } from '@kit.ArkData';
import { AppContext } from '../common/AppContext';
import { Constants } from '../common/constants/Constants';
import { toCanonicalIso } from '../common/utils/TimeUtil';

/** 存量 created_at 规范化迁移的行级记录。 */
interface RowTimeFix {
  id: string;
  createdAt: string;
}

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

/** RDB 单例：建库建表，初始化单行表。getStore 单飞（并发首次调用共享同一次初始化），避免竞争抛错。 */
export class RdbHelper {
  private static store: relationalStore.RdbStore | null = null;
  private static initPromise: Promise<relationalStore.RdbStore> | null = null;

  static getStore(): Promise<relationalStore.RdbStore> {
    if (RdbHelper.store !== null) {
      return Promise.resolve(RdbHelper.store);
    }
    if (RdbHelper.initPromise === null) {
      RdbHelper.initPromise = RdbHelper.init();
    }
    return RdbHelper.initPromise;
  }

  private static async init(): Promise<relationalStore.RdbStore> {
    try {
      const ctx = AppContext.get();
      const config: relationalStore.StoreConfig = {
        name: Constants.DB_NAME,
        securityLevel: relationalStore.SecurityLevel.S1,
      };
      const store = await relationalStore.getRdbStore(ctx, config);
      for (const stmt of SCHEMA_STATEMENTS) {
        await store.executeSql(stmt);
      }
      // 存量数据时区/格式规范化：把 created_at 统一为 UTC ISO。
      // 服务器可能返回 JS `new Date(...)` 可解析但 SQLite `datetime()` 解析为 NULL 的格式
      // （如 'Sat Aug 16 2026 05:02:00 GMT+0000'），会导致「今天/近7天」等过滤查不到；
      // 幂等——已是规范格式的行保持不变。
      const rs = await store.querySql('SELECT usg_id, created_at FROM usage_records');
      const fixes: RowTimeFix[] = [];
      while (rs.goToNextRow()) {
        const id = rs.getString(rs.getColumnIndex('usg_id'));
        const raw = rs.getString(rs.getColumnIndex('created_at'));
        const canonical = toCanonicalIso(raw);
        if (canonical !== raw) {
          fixes.push({ id: id, createdAt: canonical });
        }
      }
      rs.close();
      for (const f of fixes) {
        await store.executeSql('UPDATE usage_records SET created_at = ? WHERE usg_id = ?',
          [f.createdAt, f.id]);
      }
      // 初始化单行：account / usage_sync_state。
      // 用 INSERT OR IGNORE 替代「先查再插」，并发首次初始化也不会主键冲突。
      const now = RdbHelper.nowIso();
      await store.executeSql(
        `INSERT OR IGNORE INTO account (id, name, workspace_id, resolved_workspace_id, token, created_at, updated_at)
         VALUES (1, 'Default', 'Default', NULL, '', ?, ?)`, [now, now]);
      await store.executeSql('INSERT OR IGNORE INTO usage_sync_state (id) VALUES (1)');
      RdbHelper.store = store;
      return store;
    } catch (e) {
      // ArkTS：函数可能抛异常须显式处理；保持向上抛出，由调用方决定策略。
      throw e instanceof Error ? e : new Error(String(e));
    } finally {
      // 失败时清空，允许下次调用重新初始化；成功时 store 已缓存，直接走快捷路径。
      RdbHelper.initPromise = null;
    }
  }

  static nowIso(): string {
    return new Date().toISOString();
  }
}

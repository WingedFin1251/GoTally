// entry/src/main/ets/common/constants/Constants.ets
/** 应用全局常量：接口地址、server id、cookie、同步与汇率参数。 */
export class Constants {
  // opencode.ai 接口
  static readonly DASHBOARD_BASE: string = 'https://opencode.ai/workspace';
  static readonly WORKSPACE_SERVER_ID: string =
    'def39973159c7f0483d8793a822b8dbb10d067e12c65455fcb4608459ba0234f';
  static readonly DEFAULT_USAGE_SERVER_ID: string =
    'bfd684bfc2e4eed05cd0b518f5e4eafd3f3376e3938abb9e536e7c03df831e5c';
  static readonly USER_AGENT: string =
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) Gecko/20100101 Firefox/148.0';
  static readonly AUTH_HEADER_PREFIX: string = 'auth=';
  static readonly REQUEST_TIMEOUT_MS: number = 30000;
  static readonly MAX_BODY_BYTES: number = 4 * 1024 * 1024;
  static readonly RETRY_BACKOFF_MS: number[] = [500, 1500, 3000];

  // 登录
  static readonly LOGIN_BASE: string = 'https://auth.opencode.ai/authorize';
  static readonly LOGIN_CLIENT_ID: string = 'app';
  static readonly LOGIN_REDIRECT_URI: string = 'https://opencode.ai/auth/callback';
  static readonly LOGIN_COOKIE_DOMAIN: string = 'https://opencode.ai';
  static readonly AUTH_COOKIE_NAME: string = 'auth';

  // 配额/同步
  static readonly QUOTA_CACHE_TTL_MS: number = 30 * 1000;
  static readonly PAGE_SIZE: number = 50;
  static readonly INCREMENTAL_PAGES: number = 5;
  static readonly MAX_FULL_PAGES: number = 2000;
  static readonly FETCH_BATCH: number = 5;

  // 汇率
  static readonly EXCHANGE_URL: string = 'https://open.er-api.com/v6/latest/USD';
  static readonly EXCHANGE_TTL_MS: number = 6 * 3600 * 1000;
  static readonly DEFAULT_USD_CNY: number = 7.2;

  // 数据库/偏好
  static readonly DB_NAME: string = 'gousage.db';
  static readonly PREF_NAME: string = 'gousage_settings';

  // 同步间隔（秒）与同步范围（天）
  static readonly SYNC_INTERVAL_OPTIONS: number[] = [60, 300, 900, 1800];
  static readonly WINDOW_DAYS_OPTIONS: number[] = [30, 60, 90, 180];

  // 周期标签（对齐 db.py _period_where）
  static readonly PERIOD_TODAY: string = 'today';
  static readonly PERIOD_ALL: string = 'all';

  // Mock 开关：开发用 true（数据层返回示例数据），发布前置 false
  static readonly USE_MOCK_DATA: boolean = true;
}

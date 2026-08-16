# OpenCode Go 用量面板（HarmonyOS 移植）实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将 GoGauge（OpenCode Go 用量统计仪表盘）完整移植为原生 HarmonyOS 应用，运行于手机+平板，支持登录、配额监控、用量统计、会话/记录浏览、设置、双主题、中英双语。

**Architecture:** 单 entry 模块，原生 ArkTS。数据层用 RDB（`@kit.ArkData`）承载记录/同步状态/账户，Preferences 承载设置；网络层用 `@kit.NetworkKit` http 调用 opencode.ai 接口（移植 `opencode_api.py` 的 URL 构造与正则解析）；登录用 `@kit.ArkWeb` Web 组件加载授权页并读取 auth cookie；图表全部用 Canvas 自绘；UI 用 ArkUI 组件 + 响应式布局（手机底部 Tab / 平板侧边栏）。

**Tech Stack:** ArkTS（HarmonyOS 6.1.1，targetSdk 6.1.1(24)）、ArkUI（声明式）、`@kit.ArkData`（RDB + Preferences）、`@kit.NetworkKit`（http）、`@kit.ArkWeb`（Web）、`@kit.AbilityKit`（context）、hypium/hamock（测试）。

## Global Constraints

- 工程位于 `d:\DevelopFiles\DevEcoStudioProjects\OpencodeUsage2`（Windows 路径），所有相对路径以工程根为基准。
- **构建与测试通过 DevEco Studio 执行**（工程未含 `hvigorw` 命令行包装器；如已配置 hvigorw，命令等价）。CLI 等价命令在步骤中注明，若不可用请用 DevEco Studio 对应菜单。
- **非 git 仓库**：本目录无 `.git`，每个任务的 Commit 步骤若未 `git init` 则跳过；若已 init，按 `git add` 范围提交。
- ArkTS 严格模式（`caseSensitiveCheck`、`useNormalizedOHMUrl`）：不使用 `any`，对象字面量须匹配显式 interface/class，`JSON.parse` 结果须类型断言。
- API 版本下限：compatibleSdkVersion 6.1.0(23)。使用 `@kit.*` 形式导入，不直接导入 `@ohos.*`（除 `@ohos/hypium`、`@ohos/hamock` 测试库）。
- 数据结构与聚合口径与参考项目一致：总 Token = 输入(含缓存写) + 输出 + 推理；命中率 = 命中/(命中+未命中)；费用 USD 原值 + CNY 按实时汇率。
- 全部文案沿用参考项目，中英双语（`zh_CN` / `en_US` 资源），主题深浅色（`base`/`dark` 资源）。
- 参考项目源码只读，不修改：`D:\Users\Downloads\opencode-go-gauge-main`。
- Mock：`Constants.USE_MOCK_DATA` 为 `true` 时数据层返回示例数据（默认 true 便于无账号调试），发布前置 false。

---

## 任务分解（依赖顺序）

| 任务 | 交付物 | 测试 |
|---|---|---|
| 1 | 工程基础：Constants、资源（中英/深浅）、INTERNET 权限 | 编译通过 |
| 2 | 数据模型 + Formatter/TimeUtil 工具 | 本地单测 |
| 3 | RDB 数据层 + SettingsStore + UsageStore 接口 | 设备单测 |
| 4 | 网络层 OpenCodeApi（含纯解析函数） | 本地单测 |
| 5 | SyncManager 同步状态机 | 本地单测 |
| 6 | 登录页 + Index 导航壳 | 编译/冒烟 |
| 7 | Canvas 图表组件（Bar/Donut/Line） | 编译/冒烟 |
| 8 | 首页仪表盘 | 编译/冒烟 |
| 9 | 统计页 | 编译/冒烟 |
| 10 | 记录页（会话+明细） | 编译/冒烟 |
| 11 | 设置页 + 关于页 | 编译/冒烟 |
| 12 | 响应式收尾 + 主题/语言联动 + 全量测试 | 全量测试 |

---

### Task 1: 工程基础（常量、资源、权限）

**Files:**
- Create: `entry/src/main/ets/common/constants/Constants.ets`
- Create: `entry/src/main/ets/common/AppContext.ets`
- Modify: `entry/src/main/resources/base/element/string.json`
- Create: `entry/src/main/resources/en_US/element/string.json`
- Modify: `entry/src/main/resources/base/element/color.json`
- Create: `entry/src/main/resources/dark/element/color.json`
- Modify: `entry/src/main/module.json5`（INTERNET 权限）
- Modify: `entry/src/main/resources/base/profile/main_pages.json`（注册 Login 页）

**Interfaces:**
- Produces: `Constants`（全部网络/登录/同步常量 + `USE_MOCK_DATA`）、`AppContext.context`（供 RDB/Preferences 取上下文）。

- [ ] **Step 1: 创建 `Constants.ets`**

```typescript
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
```

- [ ] **Step 2: 创建 `AppContext.ets`（全局上下文持有者）**

```typescript
// entry/src/main/ets/common/AppContext.ets
import { common } from '@kit.AbilityKit';

/** 在 EntryAbility.onCreate 注入，供 RDB/Preferences 等需要 context 的单例使用。 */
export class AppContext {
  static context: common.UIAbilityContext | null = null;

  static get(): common.UIAbilityContext {
    if (AppContext.context === null) {
      throw new Error('AppContext not initialized');
    }
    return AppContext.context;
  }
}
```

- [ ] **Step 3: 修改 `EntryAbility.ets` 注入 context**

在 `onCreate` 中 `AppContext.context = this.context;`，并删除该文件的测试色板调用（`setColorMode` 保留亦可）：

```typescript
// entry/src/main/ets/entryability/EntryAbility.ets
import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { AppContext } from '../common/AppContext';

const DOMAIN = 0x0000;

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    AppContext.context = this.context;
    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to set colorMode. Cause: %{public}s', JSON.stringify(err));
    }
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageCreate');
    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, 'testTag', 'Succeeded in loading the content.');
    });
  }

  onWindowStageDestroy(): void { /* 释放资源 */ }
  onForeground(): void { /* 前台 */ }
  onBackground(): void { /* 后台 */ }
}
```

- [ ] **Step 4: 修改 `module.json5` 增加 INTERNET 权限**

在 `"module": {` 内（`mainElement` 之后）加入：

```json5
    "requestPermissions": [
      {
        "name": "ohos.permission.INTERNET"
      }
    ],
```

- [ ] **Step 5: 创建完整中文字符串资源 `string.json`**

```json
{
  "string": [
    { "name": "module_desc", "value": "OpenCode Go 用量统计面板" },
    { "name": "EntryAbility_desc", "value": "OpenCode Go 用量统计面板" },
    { "name": "EntryAbility_label", "value": "GoGauge" },

    { "name": "tab_home", "value": "首页" },
    { "name": "tab_stats", "value": "统计" },
    { "name": "tab_records", "value": "记录" },
    { "name": "tab_settings", "value": "设置" },
    { "name": "tab_about", "value": "关于" },

    { "name": "syncing", "value": "同步中" },
    { "name": "refresh", "value": "刷新" },
    { "name": "theme", "value": "主题" },
    { "name": "light", "value": "浅色" },
    { "name": "dark", "value": "深色" },
    { "name": "updated_at", "value": "更新于" },

    { "name": "home_title", "value": "用量统计总览" },
    { "name": "today", "value": "今天" },
    { "name": "days_7", "value": "近7天" },
    { "name": "days_30", "value": "近30天" },
    { "name": "all", "value": "全部" },

    { "name": "quota_title", "value": "配额窗口" },
    { "name": "quota_5h", "value": "5小时" },
    { "name": "quota_weekly", "value": "每周" },
    { "name": "quota_monthly", "value": "每月" },
    { "name": "used", "value": "已用" },
    { "name": "remaining", "value": "剩余" },
    { "name": "reset_in", "value": "重置倒计时" },

    { "name": "overview_title", "value": "用量概览" },
    { "name": "follow_range", "value": "数据跟随时间范围" },
    { "name": "ov_hit_rate", "value": "缓存命中率" },
    { "name": "ov_hits", "value": "命中量" },
    { "name": "ov_total_tokens", "value": "总TOKEN" },
    { "name": "ov_requests", "value": "请求数" },
    { "name": "ov_cost", "value": "费用" },
    { "name": "ov_sessions", "value": "会话数" },

    { "name": "today_trend", "value": "今日趋势" },
    { "name": "hours_24", "value": "24 小时" },
    { "name": "input", "value": "输入" },
    { "name": "output", "value": "输出" },
    { "name": "reasoning", "value": "推理" },
    { "name": "cache_read", "value": "缓存读" },
    { "name": "cache_write", "value": "缓存写" },

    { "name": "stats_title", "value": "用量统计" },
    { "name": "token_breakdown", "value": "Token 构成" },
    { "name": "model_usage", "value": "模型用量" },
    { "name": "usage_trend", "value": "用量趋势" },
    { "name": "cost", "value": "成本" },
    { "name": "requests", "value": "请求" },
    { "name": "total_tokens", "value": "总Token" },

    { "name": "records_page", "value": "使用记录" },
    { "name": "session_usage", "value": "会话用量" },
    { "name": "usage_records", "value": "使用记录" },
    { "name": "all_models", "value": "全部模型" },
    { "name": "col_session", "value": "会话" },
    { "name": "col_last_used", "value": "最后使用" },
    { "name": "col_input", "value": "输入" },
    { "name": "col_output", "value": "输出" },
    { "name": "col_reasoning", "value": "推理" },
    { "name": "col_requests", "value": "请求" },
    { "name": "col_cost", "value": "成本" },
    { "name": "col_time", "value": "时间" },
    { "name": "col_model", "value": "模型" },
    { "name": "col_cache_read", "value": "缓存读" },
    { "name": "col_fee", "value": "费用" },
    { "name": "prev", "value": "上一页" },
    { "name": "next", "value": "下一页" },
    { "name": "page_of", "value": "第 {0} / {1} 页" },

    { "name": "settings_title", "value": "设置" },
    { "name": "set_account", "value": "OpenCode 账户" },
    { "name": "set_login_state", "value": "登录状态" },
    { "name": "set_workspace", "value": "工作区" },
    { "name": "set_login_method", "value": "登录方式" },
    { "name": "login_method_desc", "value": "内置浏览器打开官方授权页，自动回填" },
    { "name": "relogin", "value": "重新登录" },
    { "name": "logout", "value": "退出登录" },
    { "name": "logout_desc", "value": "清除本地 token 与缓存数据" },
    { "name": "logged_in", "value": "已登录" },
    { "name": "not_logged_in", "value": "未登录" },

    { "name": "set_auto_sync", "value": "自动同步" },
    { "name": "auto_sync", "value": "自动增量同步" },
    { "name": "auto_sync_desc", "value": "按间隔拉取最新用量记录" },
    { "name": "sync_interval", "value": "同步间隔" },
    { "name": "sync_interval_desc", "value": "多久自动同步一次" },
    { "name": "min_1", "value": "1 分钟" },
    { "name": "min_5", "value": "5 分钟" },
    { "name": "min_15", "value": "15 分钟" },
    { "name": "min_30", "value": "30 分钟" },
    { "name": "sync_range", "value": "同步范围" },
    { "name": "sync_range_desc", "value": "本地保留与首次拉取的历史窗口；所有=拉取全部" },
    { "name": "days_30short", "value": "30天" },
    { "name": "days_60", "value": "60天" },
    { "name": "days_90", "value": "90天" },
    { "name": "days_180", "value": "180天" },
    { "name": "full_sync", "value": "立即全量同步" },
    { "name": "full_sync_desc", "value": "重新拉取历史记录，补全数据" },
    { "name": "start_full_sync", "value": "开始全量同步" },

    { "name": "set_appearance", "value": "外观" },
    { "name": "theme_desc", "value": "亮色 / 深色" },
    { "name": "currency", "value": "默认货币" },
    { "name": "currency_desc", "value": "费用主显示货币（实时汇率）" },
    { "name": "language", "value": "语言 / Language" },
    { "name": "language_desc", "value": "界面显示语言" },

    { "name": "set_data", "value": "数据" },
    { "name": "data_dir", "value": "数据目录" },
    { "name": "sync_info", "value": "同步记录" },
    { "name": "last_sync", "value": "最近同步" },
    { "name": "total_records", "value": "记录总数" },
    { "name": "never", "value": "从未" },

    { "name": "set_update", "value": "软件更新" },
    { "name": "current_version", "value": "当前版本" },
    { "name": "check_update", "value": "检查更新" },
    { "name": "check_update_desc", "value": "打开 GitHub Releases 页" },
    { "name": "check_update_btn", "value": "查看发布页" },

    { "name": "about_title", "value": "关于" },
    { "name": "about_intro", "value": "简介" },
    { "name": "intro_text", "value": "本地优先的 OpenCode Go 用量面板：配额窗口、Token 构成、模型排行与使用记录整理在同一处，打开即见。所有数据仅保存在本地，登录凭证只用于同步官方接口。" },
    { "name": "about_features", "value": "功能" },
    { "name": "feat_1", "value": "配额窗口实时监控（滚动 5 小时 / 每周 / 每月）" },
    { "name": "feat_2", "value": "今日用量与 24 小时趋势" },
    { "name": "feat_3", "value": "各模型 Token 消耗排行与用量趋势" },
    { "name": "feat_4", "value": "详细使用记录分页浏览" },
    { "name": "feat_5", "value": "自动同步数据，无需手动刷新" },
    { "name": "about_links", "value": "链接" },
    { "name": "about_thanks", "value": "致谢" },
    { "name": "thanks_text", "value": "数据提供" },
    { "name": "page_foot", "value": "GoGauge · 数据仅保存在本地 · 数据提供 OpenCode" },

    { "name": "welcome_desc", "value": "本地优先的 OpenCode Go 用量仪表盘 — 配额窗口、Token 构成、模型排行、使用记录，打开即见。" },
    { "name": "welcome_feat_1", "value": "配额实时监控（5 小时 / 每周 / 每月）" },
    { "name": "welcome_feat_2", "value": "Token 全维度统计与 24 小时趋势" },
    { "name": "welcome_feat_3", "value": "数据仅保存在本机，安全私密" },
    { "name": "login_btn", "value": "立即登录" },
    { "name": "login_note", "value": "点击后将打开 OpenCode Go 官方授权页完成登录。" },

    { "name": "sync_idle", "value": "待同步" },
    { "name": "sync_done", "value": "同步完成，新增 {0} 条" },
    { "name": "sync_error", "value": "同步失败" },
    { "name": "error_auth", "value": "认证失败，请重新登录" },
    { "name": "error_network", "value": "网络错误，请稍后重试" },
    { "name": "error_workspace", "value": "工作区不存在" },
    { "name": "error_no_token", "value": "未登录" },
    { "name": "confirm_title", "value": "确认" },
    { "name": "logout_confirm_msg", "value": "将清除本地 token 与全部用量数据，确定退出登录吗？" },
    { "name": "cancel", "value": "取消" },
    { "name": "ok", "value": "确定" }
  ]
}
```

- [ ] **Step 6: 创建英文资源 `en_US/element/string.json`**

同上结构，值替换为英文：

```json
{
  "string": [
    { "name": "module_desc", "value": "OpenCode Go Usage Panel" },
    { "name": "EntryAbility_desc", "value": "OpenCode Go Usage Panel" },
    { "name": "EntryAbility_label", "value": "GoGauge" },
    { "name": "tab_home", "value": "Home" },
    { "name": "tab_stats", "value": "Stats" },
    { "name": "tab_records", "value": "Records" },
    { "name": "tab_settings", "value": "Settings" },
    { "name": "tab_about", "value": "About" },
    { "name": "syncing", "value": "Syncing" },
    { "name": "refresh", "value": "Refresh" },
    { "name": "theme", "value": "Theme" },
    { "name": "light", "value": "Light" },
    { "name": "dark", "value": "Dark" },
    { "name": "updated_at", "value": "Updated" },
    { "name": "home_title", "value": "Usage Overview" },
    { "name": "today", "value": "Today" },
    { "name": "days_7", "value": "7 Days" },
    { "name": "days_30", "value": "30 Days" },
    { "name": "all", "value": "All" },
    { "name": "quota_title", "value": "Quota Window" },
    { "name": "quota_5h", "value": "5 Hours" },
    { "name": "quota_weekly", "value": "Weekly" },
    { "name": "quota_monthly", "value": "Monthly" },
    { "name": "used", "value": "Used" },
    { "name": "remaining", "value": "Remaining" },
    { "name": "reset_in", "value": "Reset in" },
    { "name": "overview_title", "value": "Usage Overview" },
    { "name": "follow_range", "value": "Follows the time range" },
    { "name": "ov_hit_rate", "value": "Cache Hit Rate" },
    { "name": "ov_hits", "value": "Cache Hits" },
    { "name": "ov_total_tokens", "value": "Total Tokens" },
    { "name": "ov_requests", "value": "Requests" },
    { "name": "ov_cost", "value": "Cost" },
    { "name": "ov_sessions", "value": "Sessions" },
    { "name": "today_trend", "value": "Today Trend" },
    { "name": "hours_24", "value": "24 hours" },
    { "name": "input", "value": "Input" },
    { "name": "output", "value": "Output" },
    { "name": "reasoning", "value": "Reasoning" },
    { "name": "cache_read", "value": "Cache Read" },
    { "name": "cache_write", "value": "Cache Write" },
    { "name": "stats_title", "value": "Usage Stats" },
    { "name": "token_breakdown", "value": "Token Breakdown" },
    { "name": "model_usage", "value": "Model Usage" },
    { "name": "usage_trend", "value": "Usage Trend" },
    { "name": "cost", "value": "Cost" },
    { "name": "requests", "value": "Requests" },
    { "name": "total_tokens", "value": "Total Tokens" },
    { "name": "records_page", "value": "Usage Records" },
    { "name": "session_usage", "value": "Session Usage" },
    { "name": "usage_records", "value": "Usage Records" },
    { "name": "all_models", "value": "All Models" },
    { "name": "col_session", "value": "Session" },
    { "name": "col_last_used", "value": "Last Used" },
    { "name": "col_input", "value": "Input" },
    { "name": "col_output", "value": "Output" },
    { "name": "col_reasoning", "value": "Reasoning" },
    { "name": "col_requests", "value": "Requests" },
    { "name": "col_cost", "value": "Cost" },
    { "name": "col_time", "value": "Time" },
    { "name": "col_model", "value": "Model" },
    { "name": "col_cache_read", "value": "Cache Read" },
    { "name": "col_fee", "value": "Fee" },
    { "name": "prev", "value": "Prev" },
    { "name": "next", "value": "Next" },
    { "name": "page_of", "value": "Page {0} / {1}" },
    { "name": "settings_title", "value": "Settings" },
    { "name": "set_account", "value": "OpenCode Account" },
    { "name": "set_login_state", "value": "Login State" },
    { "name": "set_workspace", "value": "Workspace" },
    { "name": "set_login_method", "value": "Login Method" },
    { "name": "login_method_desc", "value": "Opens the official auth page in an embedded browser" },
    { "name": "relogin", "value": "Re-login" },
    { "name": "logout", "value": "Log out" },
    { "name": "logout_desc", "value": "Clear local token and cached data" },
    { "name": "logged_in", "value": "Logged in" },
    { "name": "not_logged_in", "value": "Not logged in" },
    { "name": "set_auto_sync", "value": "Auto Sync" },
    { "name": "auto_sync", "value": "Auto incremental sync" },
    { "name": "auto_sync_desc", "value": "Fetch latest usage records periodically" },
    { "name": "sync_interval", "value": "Sync Interval" },
    { "name": "sync_interval_desc", "value": "How often to sync" },
    { "name": "min_1", "value": "1 min" },
    { "name": "min_5", "value": "5 min" },
    { "name": "min_15", "value": "15 min" },
    { "name": "min_30", "value": "30 min" },
    { "name": "sync_range", "value": "Sync Range" },
    { "name": "sync_range_desc", "value": "History window kept locally; All = fetch everything" },
    { "name": "days_30short", "value": "30d" },
    { "name": "days_60", "value": "60d" },
    { "name": "days_90", "value": "90d" },
    { "name": "days_180", "value": "180d" },
    { "name": "full_sync", "value": "Full Sync Now" },
    { "name": "full_sync_desc", "value": "Re-fetch history to fill gaps" },
    { "name": "start_full_sync", "value": "Start Full Sync" },
    { "name": "set_appearance", "value": "Appearance" },
    { "name": "theme_desc", "value": "Light / Dark" },
    { "name": "currency", "value": "Currency" },
    { "name": "currency_desc", "value": "Primary currency for cost display" },
    { "name": "language", "value": "Language" },
    { "name": "language_desc", "value": "UI display language" },
    { "name": "set_data", "value": "Data" },
    { "name": "data_dir", "value": "Data Directory" },
    { "name": "sync_info", "value": "Sync Records" },
    { "name": "last_sync", "value": "Last Sync" },
    { "name": "total_records", "value": "Total Records" },
    { "name": "never", "value": "Never" },
    { "name": "set_update", "value": "Software Update" },
    { "name": "current_version", "value": "Current Version" },
    { "name": "check_update", "value": "Check Update" },
    { "name": "check_update_desc", "value": "Open GitHub Releases page" },
    { "name": "check_update_btn", "value": "View Releases" },
    { "name": "about_title", "value": "About" },
    { "name": "about_intro", "value": "Introduction" },
    { "name": "intro_text", "value": "A local-first OpenCode Go usage panel: quota windows, token breakdown, model ranking and usage records in one place. All data stays on your device." },
    { "name": "about_features", "value": "Features" },
    { "name": "feat_1", "value": "Real-time quota monitoring (rolling 5h / weekly / monthly)" },
    { "name": "feat_2", "value": "Today usage and 24-hour trend" },
    { "name": "feat_3", "value": "Per-model token ranking and usage trend" },
    { "name": "feat_4", "value": "Detailed paginated usage records" },
    { "name": "feat_5", "value": "Auto sync without manual refresh" },
    { "name": "about_links", "value": "Links" },
    { "name": "about_thanks", "value": "Thanks" },
    { "name": "thanks_text", "value": "Data provided by" },
    { "name": "page_foot", "value": "GoGauge · Data stays local · Powered by OpenCode" },
    { "name": "welcome_desc", "value": "Local-first OpenCode Go usage dashboard — quota windows, token breakdown, model ranking, usage records, all at a glance." },
    { "name": "welcome_feat_1", "value": "Real-time quota monitoring (5h / weekly / monthly)" },
    { "name": "welcome_feat_2", "value": "Full token statistics and 24-hour trend" },
    { "name": "welcome_feat_3", "value": "Data stays on your device only" },
    { "name": "login_btn", "value": "Log In Now" },
    { "name": "login_note", "value": "You will be taken to the official OpenCode Go auth page." },
    { "name": "sync_idle", "value": "Idle" },
    { "name": "sync_done", "value": "Synced, {0} new" },
    { "name": "sync_error", "value": "Sync failed" },
    { "name": "error_auth", "value": "Authentication failed, please log in again" },
    { "name": "error_network", "value": "Network error, please retry later" },
    { "name": "error_workspace", "value": "Workspace not found" },
    { "name": "error_no_token", "value": "Not logged in" },
    { "name": "confirm_title", "value": "Confirm" },
    { "name": "logout_confirm_msg", "value": "This clears your local token and all usage data. Continue?" },
    { "name": "cancel", "value": "Cancel" },
    { "name": "ok", "value": "OK" }
  ]
}
```

- [ ] **Step 7: 色板资源**

`base/element/color.json`（亮色）新增：

```json
{
  "color": [
    { "name": "start_window_background", "value": "#FFFFFF" },
    { "name": "bg_page", "value": "#F5F6F7" },
    { "name": "bg_card", "value": "#FFFFFF" },
    { "name": "text_primary", "value": "#1A1A1A" },
    { "name": "text_secondary", "value": "#666666" },
    { "name": "text_muted", "value": "#999999" },
    { "name": "divider", "value": "#EEEEEE" },
    { "name": "accent", "value": "#2F6FED" },
    { "name": "bar_input", "value": "#2F6FED" },
    { "name": "bar_output", "value": "#34A853" },
    { "name": "bar_reasoning", "value": "#FBBC04" },
    { "name": "donut_1", "value": "#2F6FED" },
    { "name": "donut_2", "value": "#34A853" },
    { "name": "donut_3", "value": "#FBBC04" },
    { "name": "donut_4", "value": "#EA4335" },
    { "name": "donut_5", "value": "#9334E6" },
    { "name": "donut_6", "value": "#00ACC1" },
    { "name": "danger", "value": "#D93026" },
    { "name": "success", "value": "#34A853" },
    { "name": "quota_track", "value": "#E8EAED" }
  ]
}
```

`dark/element/color.json`（深色）创建：

```json
{
  "color": [
    { "name": "start_window_background", "value": "#1A1A1A" },
    { "name": "bg_page", "value": "#141414" },
    { "name": "bg_card", "value": "#1F1F1F" },
    { "name": "text_primary", "value": "#E8EAED" },
    { "name": "text_secondary", "value": "#B0B0B0" },
    { "name": "text_muted", "value": "#808080" },
    { "name": "divider", "value": "#333333" },
    { "name": "accent", "value": "#5B8DEF" },
    { "name": "bar_input", "value": "#5B8DEF" },
    { "name": "bar_output", "value": "#4CBB6C" },
    { "name": "bar_reasoning", "value": "#E3B23C" },
    { "name": "donut_1", "value": "#5B8DEF" },
    { "name": "donut_2", "value": "#4CBB6C" },
    { "name": "donut_3", "value": "#E3B23C" },
    { "name": "donut_4", "value": "#E0614F" },
    { "name": "donut_5", "value": "#A86CE8" },
    { "name": "donut_6", "value": "#4FC3D6" },
    { "name": "danger", "value": "#E0614F" },
    { "name": "success", "value": "#4CBB6C" },
    { "name": "quota_track", "value": "#333333" }
  ]
}
```

- [ ] **Step 8: 注册 Login 页到 `main_pages.json`**

```json
{
  "src": [
    "pages/Index",
    "pages/Login"
  ]
}
```

- [ ] **Step 9: 验证编译**

在 DevEco Studio 打开工程 → `Build → Make Project`。预期：无编译错误。（CLI 等价：`hvigorw assembleHap`，若已配置。）

- [ ] **Step 10: Commit（非 git 仓库则跳过）**

```bash
git add entry/src/main/ets/common entry/src/main/resources entry/src/main/module.json5
git commit -m "feat: project scaffold, constants, resources, permissions"
```

---

### Task 2: 数据模型 + 格式化/时间工具

**Files:**
- Create: `entry/src/main/ets/model/UsageRecord.ets`
- Create: `entry/src/main/ets/model/Stats.ets`
- Create: `entry/src/main/ets/common/utils/Formatter.ets`
- Create: `entry/src/main/ets/common/utils/TimeUtil.ets`
- Test: `entry/src/test/Formatter.test.ets`, `entry/src/test/TimeUtil.test.ets`, `entry/src/test/List.test.ets`（改写为注册新测试）

**Interfaces:**
- Consumes: `Constants`（`PERIOD_TODAY`/`PERIOD_ALL`）。
- Produces:
  - `interface UsageRecord`（字段见下）
  - `interface QuotaWindow / QuotaResult / SyncState`
  - `interface Totals / ModelStat / DailyStat / TrendPoint / SessionStat / RecordRow / WorkspaceRef`
  - `Formatter.formatTokens(n) : string`、`formatCost(usd, currency, usdCny) : string`、`formatPercent(p) : string`、`formatDuration(sec) : string`、`formatCount(n) : string`
  - `TimeUtil.parseIso(iso) : number`、`formatDateTime(ms) : string`、`formatDate(ms) : string`、`formatRelative(ms) : string`、`formatDuration(sec) : string`

- [ ] **Step 1: 写失败测试（Formatter + TimeUtil）**

```typescript
// entry/src/test/Formatter.test.ets
import { describe, it, expect } from '@ohos/hypium';
import { formatTokens, formatCost, formatPercent } from '../main/ets/common/utils/Formatter';

export default function formatterTest() {
  describe('FormatterTest', () => {
    it('formatTokens_kilo', 0, () => {
      expect(formatTokens(1500)).assertEqual('1.5k');
    });
    it('formatTokens_mega', 0, () => {
      expect(formatTokens(2500000)).assertEqual('2.5M');
    });
    it('formatTokens_plain', 0, () => {
      expect(formatTokens(999)).assertEqual('999');
    });
    it('formatCost_usd', 0, () => {
      expect(formatCost(0.0123, 'USD', 7.2)).assertEqual('$0.0123');
    });
    it('formatCost_cny', 0, () => {
      expect(formatCost(0.5, 'CNY', 7.2)).assertEqual('¥3.60');
    });
    it('formatPercent', 0, () => {
      expect(formatPercent(45.678)).assertEqual('45.7%');
    });
  });
}
```

```typescript
// entry/src/test/TimeUtil.test.ets
import { describe, it, expect } from '@ohos/hypium';
import { parseIso, formatDuration } from '../main/ets/common/utils/TimeUtil';

export default function timeUtilTest() {
  describe('TimeUtilTest', () => {
    it('parseIso_utc', 0, () => {
      expect(parseIso('2026-08-16T10:00:00Z')).assertEqual(Date.UTC(2026, 7, 16, 10, 0, 0));
    });
    it('formatDuration_hours', 0, () => {
      expect(formatDuration(3720)).assertEqual('1小时2分');
    });
    it('formatDuration_minutes', 0, () => {
      expect(formatDuration(90)).assertEqual('1分30秒');
    });
    it('formatDuration_zero', 0, () => {
      expect(formatDuration(0)).assertEqual('0秒');
    });
  });
}
```

- [ ] **Step 2: 运行测试，确认失败**

DevEco Studio：打开 `entry/src/test` → 运行 `List.test`（本地单元测试）。预期：失败（找不到模块/函数）。

- [ ] **Step 3: 创建数据模型**

```typescript
// entry/src/main/ets/model/UsageRecord.ets
/** 一条请求级用量记录（对齐 db.py UsageRecord）。 */
export interface UsageRecord {
  usgId: string;
  createdAt: string;        // ISO 8601 UTC
  model: string;
  provider: string;
  inputTokens: number;
  outputTokens: number;
  reasoningTokens: number;
  cacheReadTokens: number;
  cacheWrite5mTokens: number;
  cacheWrite1hTokens: number;
  costRaw: number;          // 单位 1e-8 USD
  costUsd: number;
  keyId: string;
  sessionId: string;
  plan: string;
  syncedAt: string;
}

/** 配额窗口（对齐 db.py QuotaWindow）。 */
export interface QuotaWindow {
  label: string;
  used: number;      // 0-100
  remaining: number;
  total: number;
  unit: string;
  resetAt: string;   // ISO
  resetInSec: number;
}

export interface QuotaResult {
  name: string;
  workspaceId: string;
  success: boolean;
  updatedAt: string;
  windows: QuotaWindow[];
  error: string;
}

export interface SyncState {
  lastSyncAt: string;
  lastSyncStatus: string;
  lastSyncError: string;
  lastInsertedCount: number;
  deepestPageFetched: number;
  totalRecords: number;
  oldestRecordAt: string;
  newestRecordAt: string;
}

export interface WorkspaceRef {
  id: string;
  name: string;
}
```

```typescript
// entry/src/main/ets/model/Stats.ets
/** 聚合统计结果（对齐 db.py 各查询返回值）。 */

export interface Totals {
  requestCount: number;
  sessionCount: number;
  totalInputTokens: number;
  uncachedInputTokens: number;
  totalReasoningTokens: number;
  cacheHitTokens: number;
  cacheWriteTokens: number;
  totalOutputTokens: number;
  totalCostUsd: number;
  hitRate: number; // 0-100
}

export interface ModelStat {
  model: string;
  requestCount: number;
  sessionCount: number;
  totalInputTokens: number;
  uncachedInputTokens: number;
  totalReasoningTokens: number;
  cacheHitTokens: number;
  cacheWriteTokens: number;
  totalOutputTokens: number;
  totalCostUsd: number;
  hitRate: number;
}

export interface DailyStat {
  date: string;             // 'YYYY-MM-DD'（本地）
  totalInputTokens: number;
  uncachedInputTokens: number;
  totalReasoningTokens: number;
  cacheHitTokens: number;
  cacheWriteTokens: number;
  totalOutputTokens: number;
  totalCostUsd: number;
  requestCount: number;
  hitRate: number;
}

export interface TrendPoint {
  hour: string;   // 'HH:00'
  input: number;
  output: number;
  reasoning: number;
}

export interface SessionStat {
  sessionId: string;
  requestCount: number;
  totalInputTokens: number;
  uncachedInputTokens: number;
  totalOutputTokens: number;
  totalReasoningTokens: number;
  totalCostUsd: number;
  lastAt: string;
}

export interface RecordRow {
  usgId: string;
  createdAt: string;
  model: string;
  provider: string;
  inputTokens: number;
  outputTokens: number;
  reasoningTokens: number;
  cacheReadTokens: number;
  cacheWriteTokens: number;
  costUsd: number;
  sessionId: string;
  plan: string;
}
```

- [ ] **Step 4: 实现 `Formatter.ets`**

```typescript
// entry/src/main/ets/common/utils/Formatter.ets
/** 数值/费用/百分比格式化（移植前端 app.js 的格式函数）。 */

/** 千分位缩写：999 / 1.5k / 2.5M。 */
export function formatTokens(n: number): string {
  if (n >= 1000000) {
    return `${(n / 1000000).toFixed(2)}M`;
  }
  if (n >= 1000) {
    return `${(n / 1000).toFixed(1)}k`;
  }
  return `${n}`;
}

/** 成本格式化：CNY 换算并保留两位，USD 保留四位。 */
export function formatCost(usd: number, currency: string, usdCny: number): string {
  if (currency === 'CNY') {
    const cny = usd * usdCny;
    return `¥${cny.toFixed(2)}`;
  }
  return `$${usd.toFixed(4)}`;
}

/** 百分比：保留 1 位小数。 */
export function formatPercent(p: number): string {
  return `${p.toFixed(1)}%`;
}

/** 一般整数（带千分位）。 */
export function formatCount(n: number): string {
  return n.toLocaleString('en-US');
}
```

- [ ] **Step 5: 实现 `TimeUtil.ets`**

```typescript
// entry/src/main/ets/common/utils/TimeUtil.ets
import { formatTokens } from './Formatter';

/** 解析 ISO 字符串（含 Z 结尾）为毫秒时间戳。 */
export function parseIso(iso: string): number {
  const ts = Date.parse(iso);
  return Number.isNaN(ts) ? 0 : ts;
}

/** 'YYYY-MM-DD HH:mm'（本地时区）。 */
export function formatDateTime(ms: number): string {
  if (ms <= 0) {
    return '--';
  }
  const d = new Date(ms);
  const p = (v: number): string => (v < 10 ? `0${v}` : `${v}`);
  return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())} ${p(d.getHours())}:${p(d.getMinutes())}`;
}

/** 'MM-DD'（本地时区）。 */
export function formatDate(ms: number): string {
  if (ms <= 0) {
    return '--';
  }
  const d = new Date(ms);
  const p = (v: number): string => (v < 10 ? `0${v}` : `${v}`);
  return `${p(d.getMonth() + 1)}-${p(d.getDate())}`;
}

/** 相对时间：刚刚 / n分钟前 / n小时前 / n天前。 */
export function formatRelative(ms: number, nowMs: number = Date.now()): string {
  if (ms <= 0) {
    return '--';
  }
  const diffSec = Math.max(0, Math.floor((nowMs - ms) / 1000));
  if (diffSec < 60) {
    return '刚刚';
  }
  if (diffSec < 3600) {
    return `${Math.floor(diffSec / 60)}分钟前`;
  }
  if (diffSec < 86400) {
    return `${Math.floor(diffSec / 3600)}小时前`;
  }
  return `${Math.floor(diffSec / 86400)}天前`;
}

/** 倒计时格式化：'1小时2分' / '1分30秒' / '0秒'。 */
export function formatDuration(totalSec: number): string {
  if (totalSec <= 0) {
    return '0秒';
  }
  const h = Math.floor(totalSec / 3600);
  const m = Math.floor((totalSec % 3600) / 60);
  const s = totalSec % 60;
  if (h > 0) {
    return `${h}小时${m}分`;
  }
  if (m > 0) {
    return `${m}分${s}秒`;
  }
  return `${s}秒`;
}

/** 倒计时格式（英文/短）：'1h 2m'。 */
export function formatDurationShort(totalSec: number): string {
  if (totalSec <= 0) {
    return '0s';
  }
  const h = Math.floor(totalSec / 3600);
  const m = Math.floor((totalSec % 3600) / 60);
  const s = totalSec % 60;
  if (h > 0) {
    return `${h}h ${m}m`;
  }
  if (m > 0) {
    return `${m}m ${s}s`;
  }
  return `${s}s`;
}

/** 依赖声明占位：保证 Formatter 在依赖图中被引用（避免未使用告警时仍被摇树）。 */
const _unused = formatTokens;
void _unused;
```

- [ ] **Step 6: 改写 `entry/src/test/List.test.ets` 注册测试**

```typescript
// entry/src/test/List.test.ets
import formatterTest from './Formatter.test';
import timeUtilTest from './TimeUtil.test';

export default function testsuite() {
  formatterTest();
  timeUtilTest();
}
```

- [ ] **Step 7: 运行测试，确认通过**

DevEco Studio：运行 `List.test`。预期：6 个 Formatter 用例 + 4 个 TimeUtil 用例全部通过。

> 说明：Step 5 中 `formatDuration` 返回中文字符串；`formatDurationShort` 供英文界面倒计时使用（Task 11 用 `language` 设置切换）。

- [ ] **Step 8: Commit（非 git 仓库则跳过）**

```bash
git add entry/src/main/ets/model entry/src/main/ets/common/utils entry/src/test
git commit -m "feat: data models and formatter/time utils with tests"
```

---

### Task 3: RDB 数据层 + SettingsStore + UsageStore 接口

**Files:**
- Create: `entry/src/main/ets/data/RdbHelper.ets`
- Create: `entry/src/main/ets/data/UsageRepository.ets`
- Create: `entry/src/main/ets/data/SettingsStore.ets`
- Create: `entry/src/main/ets/data/UsageStore.ets`（接口，供 SyncManager 注入）
- Test: `entry/src/ohosTest/ets/test/Repository.test.ets`（设备测试）
- Modify: `entry/src/ohosTest/ets/test/List.test.ets`（注册）

**Interfaces:**
- Consumes: `AppContext`, `model/*`, `Constants`。
- Produces:
  - `class RdbHelper { static async getStore(): Promise<RdbStore> }`
  - `class UsageRepository implements UsageStore`：`getToken()/getWorkspaceHint()/saveResolvedWorkspace()/saveToken()/clearAccount()/insertUsageRecords()/pruneOldRecords()/updateSyncState()/getSyncState()/totals()/modelStats()/dailyStats()/todayTrend()/sessionStatsPage()/usageRecordsPage()/listModels()/getWindowDays()`
  - `class SettingsStore { static async get(key)/put(key,value)/getAll()/save(payload) }`
  - `interface UsageStore { getToken(): string; getWorkspaceHint(): string; saveResolvedWorkspace(id: string): void; saveToken(token: string, ws: string): void; insertUsageRecords(records: UsageRecord[]): number; pruneOldRecords(windowDays: number): number; getWindowDays(): number | null; updateSyncState(status: string, error: string, inserted: number): void; getSyncState(): SyncState; getCurrency(): string; getLanguage(): string; }`

- [ ] **Step 1: 写失败测试（Repository，设备测试）**

```typescript
// entry/src/ohosTest/ets/test/Repository.test.ets
import { describe, it, expect } from '@ohos/hypium';
import { relationalStore } from '@kit.ArkData';
import { RdbHelper } from '../../../main/ets/data/RdbHelper';
import { UsageRepository } from '../../../main/ets/data/UsageRepository';
import type { UsageRecord } from '../../../main/ets/model/UsageRecord';

export default function repositoryTest() {
  describe('UsageRepositoryTest', () => {
    it('insertAndTotals', 0, async () => {
      const store = await RdbHelper.getStore();
      expect(store).not().assertNull();
      const repo = new UsageRepository();
      const now = '2026-08-16T10:00:00.000Z';
      const rec: UsageRecord = {
        usgId: 'usg_test_1', createdAt: now, model: 'gpt-4o', provider: 'openai',
        inputTokens: 100, outputTokens: 50, reasoningTokens: 10,
        cacheReadTokens: 200, cacheWrite5mTokens: 0, cacheWrite1hTokens: 0,
        costRaw: 1000000, costUsd: 0.01, keyId: 'k1', sessionId: 's1', plan: 'pro', syncedAt: now,
      };
      const inserted = repo.insertUsageRecords([rec]);
      expect(inserted).assertEqual(1);
      const totals = repo.totals('today');
      expect(totals.requestCount).assertEqual(1);
      expect(totals.cacheHitTokens).assertEqual(200);
      expect(totals.totalOutputTokens).assertEqual(50);
      // 幂等：再次插入去重
      const again = repo.insertUsageRecords([rec]);
      expect(again).assertEqual(0);
    });
  });
}
```

- [ ] **Step 2: 运行测试确认失败（需模拟器/真机）**

DevEco Studio：在设备上运行 `entry` 的 ohosTest（`Run 'List.test'` @ ohosTest）。预期：失败（找不到 `RdbHelper`）。

- [ ] **Step 3: 实现 `RdbHelper.ets`**

```typescript
// entry/src/main/ets/data/RdbHelper.ets
import { relationalStore } from '@kit.ArkData';
import { AppContext } from '../common/AppContext';
import { Constants } from '../common/constants/Constants';

const SQL_CREATE: string =
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
   );
   CREATE INDEX IF NOT EXISTS idx_usage_time ON usage_records(created_at DESC);
   CREATE TABLE IF NOT EXISTS usage_sync_state (
     id INTEGER PRIMARY KEY CHECK (id = 1),
     last_sync_at TEXT,
     last_sync_status TEXT,
     last_sync_error TEXT,
     last_inserted_count INTEGER NOT NULL DEFAULT 0,
     deepest_page_fetched INTEGER NOT NULL DEFAULT -1,
     total_records INTEGER NOT NULL DEFAULT 0,
     oldest_record_at TEXT,
     newest_record_at TEXT
   );
   CREATE TABLE IF NOT EXISTS account (
     id INTEGER PRIMARY KEY CHECK (id = 1),
     name TEXT NOT NULL DEFAULT 'Default',
     workspace_id TEXT NOT NULL DEFAULT 'Default',
     resolved_workspace_id TEXT,
     token TEXT NOT NULL DEFAULT '',
     created_at TEXT NOT NULL,
     updated_at TEXT NOT NULL
   );`;

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
    await store.executeSql(SQL_CREATE);
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
```

- [ ] **Step 4: 创建 `UsageStore.ets` 接口**

```typescript
// entry/src/main/ets/data/UsageStore.ets
import type { UsageRecord, SyncState } from '../model/UsageRecord';

/** SyncManager 依赖的最小数据访问面（便于本地单测注入内存实现）。 */
export interface UsageStore {
  getToken(): string;
  getWorkspaceHint(): string;
  saveResolvedWorkspace(workspaceId: string): void;
  saveToken(token: string, workspaceId: string): void;
  insertUsageRecords(records: UsageRecord[]): number;
  pruneOldRecords(windowDays: number): number;
  getWindowDays(): number | null;
  updateSyncState(status: string, error: string, inserted: number): void;
  getSyncState(): SyncState;
}
```

- [ ] **Step 5: 实现 `UsageRepository.ets`（数据写入 + 全部聚合查询）**

```typescript
// entry/src/main/ets/data/UsageRepository.ets
import { relationalStore } from '@kit.ArkData';
import { RdbHelper } from './RdbHelper';
import type { UsageStore } from './UsageStore';
import type { UsageRecord, SyncState } from '../model/UsageRecord';
import type { Totals, ModelStat, DailyStat, TrendPoint, SessionStat, RecordRow } from '../model/Stats';
import { Constants } from '../common/constants/Constants';

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
export class UsageRepository implements UsageStore {
  // ---- 账户 ----
  async getToken(): Promise<string> { /* 见 Step 6 */ return ''; }
  async getWorkspaceHint(): Promise<string> { return 'Default'; }
  async saveResolvedWorkspace(workspaceId: string): Promise<void> {}
  async saveToken(token: string, workspaceId: string): Promise<void> {}
  async clearAccount(): Promise<void> {}
  // ---- 记录写入 ----
  async insertUsageRecords(records: UsageRecord[]): Promise<number> { return 0; }
  async pruneOldRecords(windowDays: number): Promise<number> { return 0; }
  async getWindowDays(): Promise<number | null> { return 60; }
  async updateSyncState(status: string, error: string, inserted: number): Promise<void> {}
  async getSyncState(): Promise<SyncState> { return {} as SyncState; }
  // ---- 聚合 ----
  async totals(period: string): Promise<Totals> { return {} as Totals; }
  async modelStats(period: string): Promise<ModelStat[]> { return []; }
  async dailyStats(days: number): Promise<DailyStat[]> { return []; }
  async todayTrend(): Promise<TrendPoint[]> { return []; }
  async sessionStatsPage(page: number, pageSize: number, days: number | null): Promise<[SessionStat[], number]> { return [[], 0]; }
  async usageRecordsPage(page: number, pageSize: number, model: string | null, days: number | null): Promise<[RecordRow[], number]> { return [[], 0]; }
  async listModels(): Promise<string[]> { return []; }
}
```

> 说明：Step 5 中方法均为 `async`，返回 Promise。请直接在后续步骤覆盖为完整实现——以**本文件最终版本**为准，逐段替换上述占位方法体（见 Step 6-7）。

- [ ] **Step 6: 账户与记录写入的完整实现（替换 Step 5 中对应方法）**

将 Step 5 文件中的账户/写入方法替换为：

```typescript
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
    const rs = await store.querySql(
      `DELETE FROM usage_records WHERE datetime(created_at) < datetime('now', ?)`,
      [`-${windowDays} days`]);
    rs.close();
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
```

- [ ] **Step 7: 聚合查询完整实现（替换 Step 5 中聚合方法）**

```typescript
  // ---- 周期过滤（对齐 db.py _period_where） ----
  private static periodWhere(period: string): [string, relationalStore.ValueType[]] {
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
    return [clause === '' ? '' : `WHERE ${clause}`, params];
  }

  private static hitRate(hit: number, miss: number): number {
    if (hit + miss <= 0) {
      return 0;
    }
    return Number(((hit / (hit + miss)) * 100).toFixed(2));
  }

  async totals(period: string): Promise<Totals> {
    const [where, params] = UsageRepository.periodWhere(period);
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
       FROM usage_records ${where}`, params);
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
    const [where, params] = UsageRepository.periodWhere(period);
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
       FROM usage_records ${where}
       GROUP BY model
       ORDER BY (SUM(input_tokens + cache_read_tokens + cache_write_5m_tokens + cache_write_1h_tokens) + SUM(output_tokens)) DESC`, params);
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
    const byHour = new Map<number, { input: number; output: number; reasoning: number }>();
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
```

> 注意：`rowAsUsageRecord` 已在文件顶部定义，`SettingsStore` 在 Task 3 Step 8 实现后供 `getWindowDays()` 使用。

- [ ] **Step 8: 实现 `SettingsStore.ets`（Preferences）**

```typescript
// entry/src/main/ets/data/SettingsStore.ets
import { preferences } from '@kit.ArkData';
import { AppContext } from '../common/AppContext';
import { Constants } from '../common/constants/Constants';

/** 设置项键名。 */
export class SettingsKeys {
  static readonly SYNC_INTERVAL_SEC: string = 'sync_interval_sec';
  static readonly WINDOW_DAYS: string = 'window_days';
  static readonly AUTO_SYNC: string = 'auto_sync';
  static readonly THEME: string = 'theme';
  static readonly CURRENCY: string = 'currency';
  static readonly LANGUAGE: string = 'language';
}

export interface AppSettings {
  syncIntervalSec: number;
  windowDays: number | null;
  autoSync: boolean;
  theme: string;
  currency: string;
  language: string;
}

const DEFAULT_SETTINGS: AppSettings = {
  syncIntervalSec: 300,
  windowDays: 60,
  autoSync: true,
  theme: 'light',
  currency: 'CNY',
  language: 'zh',
};

/** Preferences 设置存储（同步间隔/范围/开关/主题/货币/语言）。 */
export class SettingsStore {
  private static pref: preferences.Preferences | null = null;

  static async getPref(): Promise<preferences.Preferences> {
    if (SettingsStore.pref !== null) {
      return SettingsStore.pref;
    }
    const ctx = AppContext.get();
    const pref = await preferences.getPreferences(ctx, Constants.PREF_NAME);
    SettingsStore.pref = pref;
    return pref;
  }

  static async getAll(): Promise<AppSettings> {
    const pref = await SettingsStore.getPref();
    const interval = await pref.get(SettingsKeys.SYNC_INTERVAL_SEC, DEFAULT_SETTINGS.syncIntervalSec) as number;
    const windowRaw = await pref.get(SettingsKeys.WINDOW_DAYS, 60) as number;
    const autoSync = await pref.get(SettingsKeys.AUTO_SYNC, DEFAULT_SETTINGS.autoSync) as boolean;
    const theme = await pref.get(SettingsKeys.THEME, DEFAULT_SETTINGS.theme) as string;
    const currency = await pref.get(SettingsKeys.CURRENCY, DEFAULT_SETTINGS.currency) as string;
    const language = await pref.get(SettingsKeys.LANGUAGE, DEFAULT_SETTINGS.language) as string;
    return {
      syncIntervalSec: interval,
      windowDays: windowRaw > 0 ? windowRaw : null,
      autoSync: autoSync,
      theme: theme,
      currency: currency,
      language: language,
    };
  }

  static async getWindowDays(): Promise<number | null> {
    return (await SettingsStore.getAll()).windowDays;
  }

  static async getSyncIntervalSec(): Promise<number> {
    return (await SettingsStore.getAll()).syncIntervalSec;
  }

  static async getAutoSync(): Promise<boolean> {
    return (await SettingsStore.getAll()).autoSync;
  }

  static async getCurrency(): Promise<string> {
    return (await SettingsStore.getAll()).currency;
  }

  static async getLanguage(): Promise<string> {
    return (await SettingsStore.getAll()).language;
  }

  static async put(key: string, value: preferences.ValueType): Promise<void> {
    const pref = await SettingsStore.getPref();
    await pref.put(key, value);
    await pref.flush();
  }

  static async save(payload: AppSettings): Promise<void> {
    const pref = await SettingsStore.getPref();
    await pref.put(SettingsKeys.SYNC_INTERVAL_SEC, payload.syncIntervalSec);
    await pref.put(SettingsKeys.WINDOW_DAYS, payload.windowDays !== null ? payload.windowDays : 0);
    await pref.put(SettingsKeys.AUTO_SYNC, payload.autoSync);
    await pref.put(SettingsKeys.THEME, payload.theme);
    await pref.put(SettingsKeys.CURRENCY, payload.currency);
    await pref.put(SettingsKeys.LANGUAGE, payload.language);
    await pref.flush();
  }
}
```

- [ ] **Step 9: 修正 `UsageRepository` 的接口一致性（异步 vs 同步）**

Task 3 Step 5 中 `UsageStore` 接口方法为同步签名，但 RDB 实现为异步。**最终约定：`UsageStore` 接口改为异步**：

```typescript
// entry/src/main/ets/data/UsageStore.ets（最终版本）
import type { UsageRecord, SyncState } from '../model/UsageRecord';

/** SyncManager 依赖的最小数据访问面（本地单测注入内存实现）。 */
export interface UsageStore {
  getToken(): Promise<string>;
  getWorkspaceHint(): Promise<string>;
  saveResolvedWorkspace(workspaceId: string): Promise<void>;
  saveToken(token: string, workspaceId: string): Promise<void>;
  insertUsageRecords(records: UsageRecord[]): Promise<number>;
  pruneOldRecords(windowDays: number): Promise<number>;
  getWindowDays(): Promise<number | null>;
  updateSyncState(status: string, error: string, inserted: number): Promise<void>;
  getSyncState(): Promise<SyncState>;
}
```

> `UsageRepository` 按上述异步签名实现即可；`SettingsStore.getWindowDays()` 返回 `Promise<number|null>`，与接口一致。

- [ ] **Step 10: 注册 ohosTest 测试并运行**

```typescript
// entry/src/ohosTest/ets/test/List.test.ets（若已存在，替换内容）
import abilityTest from './Ability.test';
import repositoryTest from './Repository.test';

export default function testsuite() {
  abilityTest();
  repositoryTest();
}
```

DevEco Studio：连接模拟器/真机，运行 `entry` 的 ohosTest。预期：`insertAndTotals` 通过（insert=1，totals 正确，幂等去重=0）。

> 说明：`Repository.test` 使用 `AppContext.get()` 取设备上下文，需在测试执行环境中可用；若 `AppContext` 未初始化，可在测试 setUp 中 `AppContext.context = getContext(this) as UIAbilityContext`（ohosTest 里通过 `getContext()` 获取测试上下文）。

- [ ] **Step 11: Commit（非 git 仓库则跳过）**

```bash
git add entry/src/main/ets/data entry/src/ohosTest
git commit -m "feat: RDB data layer, settings store, usage store interface"
```

---

### Task 4: 网络层 OpenCodeApi

**Files:**
- Create: `entry/src/main/ets/network/OpenCodeApi.ets`
- Test: `entry/src/test/OpenCodeApi.test.ets`

**Interfaces:**
- Consumes: `Constants`, `model/*`。
- Produces:
  - `class OpenCodeApi`：
    - 纯解析（可单测）：`static parseQuotaHtml(html: string, nowIso: string): QuotaWindow[]`、`static parseUsageResponse(text: string): UsageRecord[]`、`static parseWorkspaceRefs(text: string): WorkspaceRef[]`、`static extractWorkspaceId(hint: string): string`、`static buildCookieHeader(token: string): string`、`static buildLoginUrl(): string`
    - 网络（封装 http）：`static async fetchQuota(token, workspaceHint): Promise<QuotaResult>`、`static async fetchWorkspaceRefs(token): Promise<WorkspaceRef[]>`、`static async resolveWorkspaceId(hint, token): Promise<string>`、`static async fetchUsagePage(token, workspaceId, page, keyId?): Promise<UsageRecord[]>`、`static async fetchUsdCny(): Promise<number>`

- [ ] **Step 1: 写失败测试（正则解析，本地单测）**

```typescript
// entry/src/test/OpenCodeApi.test.ets
import { describe, it, expect } from '@ohos/hypium';
import { OpenCodeApi } from '../main/ets/network/OpenCodeApi';

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
    it('extractWorkspaceId', 0, () => {
      expect(OpenCodeApi.extractWorkspaceId('wrk_abc123')).assertEqual('wrk_abc123');
      expect(OpenCodeApi.extractWorkspaceId('https://opencode.ai/workspace/wrk_abc123/go')).assertEqual('wrk_abc123');
      expect(OpenCodeApi.extractWorkspaceId('default')).assertEqual('');
    });
  });
}
```

- [ ] **Step 2: 运行测试确认失败**

DevEco Studio：运行 `List.test`（需把 `OpenCodeApi.test` 加入 `src/test/List.test.ets`，见 Step 5）。预期：失败（找不到 `OpenCodeApi`）。

- [ ] **Step 3: 实现 `OpenCodeApi.ets`（解析 + 网络）**

```typescript
// entry/src/main/ets/network/OpenCodeApi.ets
import { http } from '@kit.NetworkKit';
import { Constants } from '../common/constants/Constants';
import type { QuotaWindow, QuotaResult, UsageRecord, WorkspaceRef } from '../model/UsageRecord';

interface Field { name: string; value: string; }

const QUOTA_PATTERNS: Array<{ label: string; pctFirst: RegExp; resetFirst: RegExp }> = [
  {
    label: '5h',
    pctFirst: /rollingUsage:\s*\$R\[\d+\]\s*=\s*\{[^}]*usagePercent\s*:\s*(-?\d+(?:\.\d+)?)[^}]*resetInSec\s*:\s*(-?\d+(?:\.\d+)?)[^}]*\}/,
    resetFirst: /rollingUsage:\s*\$R\[\d+\]\s*=\s*\{[^}]*resetInSec\s*:\s*(-?\d+(?:\.\d+)?)[^}]*usagePercent\s*:\s*(-?\d+(?:\.\d+)?)[^}]*\}/,
  },
  {
    label: 'weekly',
    pctFirst: /weeklyUsage:\s*\$R\[\d+\]\s*=\s*\{[^}]*usagePercent\s*:\s*(-?\d+(?:\.\d+)?)[^}]*resetInSec\s*:\s*(-?\d+(?:\.\d+)?)[^}]*\}/,
    resetFirst: /weeklyUsage:\s*\$R\[\d+\]\s*=\s*\{[^}]*resetInSec\s*:\s*(-?\d+(?:\.\d+)?)[^}]*usagePercent\s*:\s*(-?\d+(?:\.\d+)?)[^}]*\}/,
  },
  {
    label: 'monthly',
    pctFirst: /monthlyUsage:\s*\$R\[\d+\]\s*=\s*\{[^}]*usagePercent\s*:\s*(-?\d+(?:\.\d+)?)[^}]*resetInSec\s*:\s*(-?\d+(?:\.\d+)?)[^}]*\}/,
    resetFirst: /monthlyUsage:\s*\$R\[\d+\]\s*=\s*\{[^}]*resetInSec\s*:\s*(-?\d+(?:\.\d+)?)[^}]*usagePercent\s*:\s*(-?\d+(?:\.\d+)?)[^}]*\}/,
  },
];

const WORKSPACE_ID_RE: RegExp = /wrk_[A-Za-z0-9]+/;
const WORKSPACE_ENTRY_RE: RegExp = /id\s*:\s*"(wrk_[^"]+)"[^{}]*?name\s*:\s*"([^"]*)"/;
const RECORD_ANCHOR_RE: RegExp = /id:\s*"(usg_[^"]+)"/;
const PLAN_RE: RegExp = /id:\s*"(usg_[^"]+)"[^}]*?enrichment:\$R\[\d+\]=\{plan:"([^"]+)"\}/;
const CREATED_RE: RegExp = /timeCreated:\s*\$R\[\d+\]\s*=\s*new Date\("([^"]+)"\)/;

function clampPercent(v: number): number {
  return Math.max(0, Math.min(100, v));
}

function parseNumField(body: string, name: string): number {
  const re = new RegExp(`${name}:\\s*(\\d+|null)`);
  const m = re.exec(body);
  if (m === null) {
    return 0;
  }
  if (m[1] === 'null') {
    return 0;
  }
  const n = Number(m[1]);
  return Number.isNaN(n) ? 0 : n;
}

function parseStrField(body: string, name: string): string {
  const re = new RegExp(`${name}:\\s*"([^"]*)"`);
  const m = re.exec(body);
  return m !== null ? m[1] : '';
}

/** OpenCode Go API 客户端：配额/用量/工作区，含网络与纯解析。 */
export class OpenCodeApi {

  // ---------- 纯解析（可单测） ----------

  static buildCookieHeader(token: string): string {
    let cookie = token.trim();
    if (cookie.toLowerCase().startsWith('cookie:')) {
      cookie = cookie.substring(7).trim();
    }
    if (cookie === '') {
      return '';
    }
    const parts = cookie.split(';');
    for (const part of parts) {
      const p = part.trim();
      if (p.startsWith('auth=')) {
        return p;
      }
    }
    return `auth=${cookie}`;
  }

  static buildLoginUrl(): string {
    const state = Date.now().toString(36) + Math.floor(Math.random() * 1e9).toString(36);
    return `${Constants.LOGIN_BASE}?client_id=${Constants.LOGIN_CLIENT_ID}` +
      `&redirect_uri=${encodeURIComponent(Constants.LOGIN_REDIRECT_URI)}` +
      `&response_type=code&state=${state}`;
  }

  static extractWorkspaceId(hint: string): string {
    const value = hint.trim();
    if (value.startsWith('wrk_') && value.length > 4) {
      return value;
    }
    const m = WORKSPACE_ID_RE.exec(value);
    return m !== null ? m[0] : '';
  }

  static parseQuotaHtml(html: string, nowIso: string): QuotaWindow[] {
    const nowMs = Date.parse(nowIso);
    const windows: QuotaWindow[] = [];
    for (const pattern of QUOTA_PATTERNS) {
      let match = pattern.pctFirst.exec(html);
      let used: number;
      let resetIn: number;
      if (match !== null) {
        used = Number(match[1]);
        resetIn = Number(match[2]);
      } else {
        match = pattern.resetFirst.exec(html);
        if (match === null) {
          continue;
        }
        used = Number(match[2]);
        resetIn = Number(match[1]);
      }
      used = clampPercent(used);
      resetIn = Math.max(0, Math.floor(resetIn));
      const resetAt = new Date(nowMs + resetIn * 1000).toISOString();
      windows.push({
        label: pattern.label,
        used: used,
        remaining: Number((100 - used).toFixed(1)),
        total: 100,
        unit: '%',
        resetAt: resetAt,
        resetInSec: resetIn,
      });
    }
    return windows;
  }

  static parseWorkspaceRefs(text: string): WorkspaceRef[] {
    const refs: WorkspaceRef[] = [];
    const seen = new Set<string>();
    let m = WORKSPACE_ENTRY_RE.exec(text);
    while (m !== null) {
      const id = m[1];
      const name = m[2].trim();
      if (!seen.has(id)) {
        seen.add(id);
        refs.push({ id: id, name: name });
      }
      m = WORKSPACE_ENTRY_RE.exec(text, m.index + 1);
    }
    return refs;
  }

  static parseUsageResponse(text: string): UsageRecord[] {
    const plans = new Map<string, string>();
    let pm = PLAN_RE.exec(text);
    while (pm !== null) {
      plans.set(pm[1], pm[2]);
      pm = PLAN_RE.exec(text, pm.index + 1);
    }
    const anchors: Array<{ id: string; start: number }> = [];
    let am = RECORD_ANCHOR_RE.exec(text);
    while (am !== null) {
      anchors.push({ id: am[1], start: am.index });
      am = RECORD_ANCHOR_RE.exec(text, am.index + 1);
    }
    const records: UsageRecord[] = [];
    for (let i = 0; i < anchors.length; i++) {
      const anchor = anchors[i];
      const end = i + 1 < anchors.length ? anchors[i + 1].start : text.length;
      const body = text.substring(anchor.start, end);
      const created = CREATED_RE.exec(body);
      if (created === null) {
        continue;
      }
      records.push({
        usgId: anchor.id,
        createdAt: created[1],
        model: parseStrField(body, 'model'),
        provider: parseStrField(body, 'provider'),
        inputTokens: parseNumField(body, 'inputTokens'),
        outputTokens: parseNumField(body, 'outputTokens'),
        reasoningTokens: parseNumField(body, 'reasoningTokens'),
        cacheReadTokens: parseNumField(body, 'cacheReadTokens'),
        cacheWrite5mTokens: parseNumField(body, 'cacheWrite5mTokens'),
        cacheWrite1hTokens: parseNumField(body, 'cacheWrite1hTokens'),
        costRaw: parseNumField(body, 'cost'),
        costUsd: parseNumField(body, 'cost') / 100000000,
        keyId: parseStrField(body, 'keyID'),
        sessionId: parseStrField(body, 'sessionID'),
        plan: plans.get(anchor.id) ?? '',
        syncedAt: '',
      });
    }
    return records;
  }

  // ---------- 网络 ----------

  static async fetchWorkspaceRefs(token: string): Promise<WorkspaceRef[]> {
    const cookie = OpenCodeApi.buildCookieHeader(token);
    if (cookie === '') {
      throw new Error('token 为空');
    }
    const url = `https://opencode.ai/_server?id=${encodeURIComponent(Constants.WORKSPACE_SERVER_ID)}`;
    const text = await OpenCodeApi.fetchText(url, cookie, Constants.WORKSPACE_SERVER_ID, 'https://opencode.ai');
    const refs = OpenCodeApi.parseWorkspaceRefs(text);
    if (refs.length === 0) {
      throw new Error('无法从账号数据解析工作区 ID');
    }
    return refs;
  }

  static async resolveWorkspaceId(hint: string, token: string): Promise<string> {
    const direct = OpenCodeApi.extractWorkspaceId(hint);
    if (direct !== '') {
      return direct;
    }
    const refs = await OpenCodeApi.fetchWorkspaceRefs(token);
    const hintL = hint.trim().toLowerCase();
    for (const ref of refs) {
      if (ref.id.toLowerCase() === hintL || ref.name.toLowerCase() === hintL) {
        return ref.id;
      }
    }
    return refs[0].id;
  }

  static async fetchQuota(token: string, workspaceHint: string): Promise<QuotaResult> {
    const updatedAt = new Date().toISOString();
    const hint = (workspaceHint.trim() === '' ? 'Default' : workspaceHint.trim());
    if (token.trim() === '') {
      return { name: 'Default', workspaceId: hint, success: false, updatedAt: updatedAt, windows: [], error: '未配置 token' };
    }
    try {
      const workspaceId = await OpenCodeApi.resolveWorkspaceId(hint, token);
      const cookie = OpenCodeApi.buildCookieHeader(token);
      const url = `${Constants.DASHBOARD_BASE}/${encodeURIComponent(workspaceId)}/go`;
      const html = await OpenCodeApi.fetchText(url, cookie, '', 'https://opencode.ai');
      const windows = OpenCodeApi.parseQuotaHtml(html, new Date().toISOString());
      if (windows.length === 0) {
        throw new Error('无法从 Dashboard HTML 解析额度数据');
      }
      return { name: 'Default', workspaceId: workspaceId, success: true, updatedAt: updatedAt, windows: windows, error: '' };
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      return { name: 'Default', workspaceId: hint, success: false, updatedAt: updatedAt, windows: [], error: msg };
    }
  }

  static async fetchUsagePage(token: string, workspaceId: string, page: number = 0, keyId: string = ''): Promise<UsageRecord[]> {
    const args: string[] = [workspaceId];
    if (keyId !== '') {
      if (page > 0) {
        args.push(`${page}`, keyId);
      } else {
        args.push(keyId);
      }
    } else if (page > 0) {
      args.push(`${page}`);
    }
    const url = `https://opencode.ai/_server?id=${encodeURIComponent(Constants.DEFAULT_USAGE_SERVER_ID)}` +
      `&args=${encodeURIComponent(JSON.stringify(args))}`;
    const cookie = OpenCodeApi.buildCookieHeader(token);
    const text = await OpenCodeApi.fetchText(
      url, cookie, Constants.DEFAULT_USAGE_SERVER_ID, `/workspace/${workspaceId}/usage`);
    return OpenCodeApi.parseUsageResponse(text);
  }

  static async fetchUsdCny(): Promise<number> {
    try {
      const req = http.createHttp();
      const resp = await req.request(Constants.EXCHANGE_URL, {
        method: http.RequestMethod.GET,
        header: { 'Accept': 'application/json' },
        connectTimeout: 10000,
        readTimeout: 10000,
      });
      req.destroy();
      if (resp.responseCode !== 200) {
        return Constants.DEFAULT_USD_CNY;
      }
      const data = JSON.parse(resp.result as string) as Record<string, Object>;
      const rates = data['rates'] as Record<string, Object>;
      const cny = Number(rates['CNY'] ?? 0);
      return cny > 0 ? cny : Constants.DEFAULT_USD_CNY;
    } catch (e) {
      return Constants.DEFAULT_USD_CNY;
    }
  }

  private static async fetchText(url: string, cookie: string, serverId: string, referer: string): Promise<string> {
    if (cookie === '') {
      throw new Error('token 为空');
    }
    let lastErr: Error = new Error('未知错误');
    for (let attempt = 0; attempt < Constants.RETRY_BACKOFF_MS.length; attempt++) {
      try {
        const req = http.createHttp();
        const header: Record<string, string> = {
          'Cookie': cookie,
          'X-Server-Instance': `server-fn:${Date.now()}`,
          'User-Agent': Constants.USER_AGENT,
          'Origin': 'https://opencode.ai',
          'Accept': 'text/javascript, application/json;q=0.9, */*;q=0.8',
        };
        if (serverId !== '') {
          header['X-Server-Id'] = serverId;
        }
        if (referer !== '') {
          header['Referer'] = `https://opencode.ai${referer}`;
        }
        const resp = await req.request(url, {
          method: http.RequestMethod.GET,
          header: header,
          connectTimeout: Constants.REQUEST_TIMEOUT_MS,
          readTimeout: Constants.REQUEST_TIMEOUT_MS,
        });
        req.destroy();
        const code = resp.responseCode;
        if (code === 401 || code === 403) {
          throw new Error(`认证失败 (HTTP ${code})，请重新登录`);
        }
        if (code === 404) {
          throw new Error('工作区不存在 (HTTP 404)');
        }
        if (code < 200 || code >= 300) {
          throw new Error(`请求返回 HTTP ${code}`);
        }
        return resp.result as string;
      } catch (e) {
        lastErr = e instanceof Error ? e : new Error(String(e));
        if (lastErr.message.includes('认证失败') || lastErr.message.includes('HTTP 404')) {
          throw lastErr;
        }
        if (attempt < Constants.RETRY_BACKOFF_MS.length - 1) {
          await OpenCodeApi.sleep(Constants.RETRY_BACKOFF_MS[attempt]);
        }
      }
    }
    throw lastErr;
  }

  private static sleep(ms: number): Promise<void> {
    return new Promise<void>((resolve) => {
      setTimeout(resolve, ms);
    });
  }
}
```

> 说明：`Field` interface 未使用，可删除；保留 `parseNumField`/`parseStrField` 为文件私有函数。测试中 `parseUsageResponse` 的 `costUsd` 由 `costRaw/1e8` 计算（对齐 db.py）。

- [ ] **Step 4: 运行测试确认通过**

将 `OpenCodeApi.test` 加入 `src/test/List.test.ets`：

```typescript
// entry/src/test/List.test.ets
import formatterTest from './Formatter.test';
import timeUtilTest from './TimeUtil.test';
import openCodeApiTest from './OpenCodeApi.test';

export default function testsuite() {
  formatterTest();
  timeUtilTest();
  openCodeApiTest();
}
```

DevEco Studio：运行 `List.test`。预期：新增 5 个用例全部通过（3 个解析 + cookie/workspace 各 1）。

- [ ] **Step 5: Commit（非 git 仓库则跳过）**

```bash
git add entry/src/main/ets/network entry/src/test
git commit -m "feat: opencode api client with parsers and tests"
```

---

### Task 5: SyncManager 同步状态机

**Files:**
- Create: `entry/src/main/ets/network/SyncManager.ets`
- Create: `entry/src/main/ets/network/UsageFetcher.ets`（接口）
- Test: `entry/src/test/SyncManager.test.ets`

**Interfaces:**
- Consumes: `UsageStore`（Task 3 异步签名）、`Constants`、`model/*`。
- Produces:
  - `interface UsageFetcher { fetchUsagePage(workspaceId: string, page: number, keyId?: string): Promise<UsageRecord[]> }`
  - `interface SyncProgress { running: boolean; mode: string; page: number; inserted: number; phase: string; message: string }`
  - `class SyncManager { static instance: SyncManager; setStore(store: UsageStore): void; setFetcher(fetcher: UsageFetcher): void; onProgress: (p: SyncProgress) => void; async sync(mode: 'incremental'|'full'): Promise<{ok:boolean; error?:string; inserted?:number}>; getProgress(): SyncProgress; async startAutoSyncLoop(): Promise<void>; stopAutoSync(): void }`

- [ ] **Step 1: 写失败测试（状态机，注入内存 store + fake fetcher）**

```typescript
// entry/src/test/SyncManager.test.ets
import { describe, it, expect } from '@ohos/hypium';
import { SyncManager, SyncProgress } from '../main/ets/network/SyncManager';
import type { UsageFetcher } from '../main/ets/network/UsageFetcher';
import type { UsageStore } from '../main/ets/data/UsageStore';
import type { UsageRecord, SyncState } from '../main/ets/model/UsageRecord';

const mkRec = (i: number): UsageRecord => ({
  usgId: `usg_${i}`, createdAt: `2026-08-1${i % 10}T00:00:00Z`, model: 'gpt-4o',
  provider: 'openai', inputTokens: 100, outputTokens: 50, reasoningTokens: 0,
  cacheReadTokens: 0, cacheWrite5mTokens: 0, cacheWrite1hTokens: 0,
  costRaw: 0, costUsd: 0, keyId: 'k', sessionId: 's', plan: '', syncedAt: '',
});

class FakeStore implements UsageStore {
  records: UsageRecord[] = [];
  token = 'auth=test';
  windowDays: number | null = 30;
  syncState: SyncState = {
    lastSyncAt: '', lastSyncStatus: '', lastSyncError: '', lastInsertedCount: 0,
    deepestPageFetched: -1, totalRecords: 0, oldestRecordAt: '', newestRecordAt: '',
  };
  async getToken(): Promise<string> { return this.token; }
  async getWorkspaceHint(): Promise<string> { return 'wrk_test'; }
  async saveResolvedWorkspace(id: string): Promise<void> {}
  async saveToken(token: string, ws: string): Promise<void> {}
  async insertUsageRecords(records: UsageRecord[]): Promise<number> {
    let n = 0;
    for (const r of records) {
      if (!this.records.some((x) => x.usgId === r.usgId)) {
        this.records.push(r);
        n++;
      }
    }
    return n;
  }
  async pruneOldRecords(windowDays: number): Promise<number> { return 0; }
  async getWindowDays(): Promise<number | null> { return this.windowDays; }
  async updateSyncState(status: string, error: string, inserted: number): Promise<void> {
    this.syncState.lastSyncStatus = status;
    this.syncState.lastSyncError = error;
  }
  async getSyncState(): Promise<SyncState> { return this.syncState; }
}

export default function syncManagerTest() {
  describe('SyncManagerTest', () => {
    it('incremental_inserts_new', 0, async () => {
      const store = new FakeStore();
      const fetcher: UsageFetcher = {
        fetchUsagePage: async (ws: string, page: number): Promise<UsageRecord[]> => {
          if (page === 0) { return [mkRec(1), mkRec(2)]; }
          return [];
        },
      };
      const mgr = new SyncManager(store, fetcher);
      const result = await mgr.sync('incremental');
      expect(result.ok).assertTrue();
      expect(result.inserted).assertEqual(2);
      expect(store.records.length).assertEqual(2);
    });
    it('no_token_fails', 0, async () => {
      const store = new FakeStore();
      store.token = '';
      const mgr = new SyncManager(store, { fetchUsagePage: async () => [] });
      const result = await mgr.sync('incremental');
      expect(result.ok).assertFalse();
      expect(result.error).assertEqual('未登录');
    });
    it('dedupe_on_retry', 0, async () => {
      const store = new FakeStore();
      const fetcher: UsageFetcher = {
        fetchUsagePage: async (ws: string, page: number): Promise<UsageRecord[]> =>
          page === 0 ? [mkRec(1)] : [],
      };
      const mgr = new SyncManager(store, fetcher);
      await mgr.sync('incremental');
      const second = await mgr.sync('incremental');
      expect(second.inserted).assertEqual(0);
      expect(store.records.length).assertEqual(1);
    });
  });
}
```

- [ ] **Step 2: 运行测试确认失败**

DevEco Studio：运行 `List.test`。预期：失败（找不到 `SyncManager`）。

- [ ] **Step 3: 实现 `UsageFetcher.ets` 接口**

```typescript
// entry/src/main/ets/network/UsageFetcher.ets
import type { UsageRecord } from '../model/UsageRecord';

/** 用量页拉取抽象：SyncManager 通过它取数，便于单测注入。 */
export interface UsageFetcher {
  fetchUsagePage(workspaceId: string, page: number, keyId?: string): Promise<UsageRecord[]>;
}
```

- [ ] **Step 4: 实现 `SyncManager.ets`**

```typescript
// entry/src/main/ets/network/SyncManager.ets
import { Constants } from '../common/constants/Constants';
import type { UsageStore } from '../data/UsageStore';
import type { UsageFetcher } from './UsageFetcher';

export interface SyncProgress {
  running: boolean;
  mode: string;
  page: number;
  inserted: number;
  phase: string; // idle | usage | done | error
  message: string;
}

const IDLE_PROGRESS: SyncProgress = { running: false, mode: '', page: 0, inserted: 0, phase: 'idle', message: '' };

/** 同步状态机：增量/全量拉取、去重写入、窗口裁剪、进度回调。 */
export class SyncManager {
  private store: UsageStore;
  private fetcher: UsageFetcher;
  private progress: SyncProgress = { ...IDLE_PROGRESS };
  private busy = false;
  private timer: number | null = null;
  onProgress: (p: SyncProgress) => void = () => {};

  constructor(store: UsageStore, fetcher: UsageFetcher) {
    this.store = store;
    this.fetcher = fetcher;
  }

  getProgress(): SyncProgress {
    return { ...this.progress };
  }

  private setPhase(phase: string, message: string): void {
    this.progress.phase = phase;
    this.progress.message = message;
    this.progress.running = phase === 'usage';
    this.onProgress(this.getProgress());
  }

  async sync(mode: 'incremental' | 'full'): Promise<{ ok: boolean; error?: string; inserted?: number }> {
    const token = await this.store.getToken();
    if (token.trim() === '') {
      return { ok: false, error: '未登录' };
    }
    if (this.busy) {
      return { ok: false, error: '已有同步任务进行中' };
    }
    this.busy = true;
    this.progress.mode = mode;
    this.progress.page = 0;
    this.progress.inserted = 0;
    this.setPhase('usage', '');

    try {
      const workspaceId = await this.store.getWorkspaceHint();
      const windowDays = await this.store.getWindowDays();
      const maxPages = mode === 'full' ? Constants.MAX_FULL_PAGES : Constants.INCREMENTAL_PAGES;
      let totalInserted = 0;
      let page = 0;
      let emptyBatches = 0;

      while (page < maxPages) {
        const batchPages: number[] = [];
        for (let p = page; p < Math.min(page + Constants.FETCH_BATCH, maxPages); p++) {
          batchPages.push(p);
        }
        this.progress.page = page;
        this.onProgress(this.getProgress());

        const results: Array<UsageRecordOrError> = [];
        for (const p of batchPages) {
          results.push(await this.fetchOne(workspaceId, p));
        }

        let batchInserted = 0;
        let batchFullPages = 0;
        let batchFailed = 0;
        for (let i = 0; i < results.length; i++) {
          const result = results[i];
          if (result.error !== undefined) {
            batchFailed += 1;
            continue;
          }
          const recs = result.records;
          if (recs.length === 0) {
            continue;
          }
          const inserted = await this.store.insertUsageRecords(recs);
          totalInserted += inserted;
          batchInserted += inserted;
          if (recs.length >= Constants.PAGE_SIZE) {
            batchFullPages += 1;
          }
          this.progress.inserted = totalInserted;
          this.onProgress(this.getProgress());
        }

        page += Constants.FETCH_BATCH;

        if (batchFailed > 0) {
          if (mode === 'incremental') {
            const msg = '网络请求失败 (超时/中断)';
            this.setPhase('error', msg);
            await this.store.updateSyncState('error', msg, totalInserted);
            this.busy = false;
            return { ok: false, error: msg, inserted: totalInserted };
          }
        }

        if (batchFullPages === 0) {
          break;
        }
        if (mode === 'incremental' && batchInserted === 0) {
          emptyBatches += 1;
          if (emptyBatches >= 2) {
            break;
          }
        } else {
          emptyBatches = 0;
        }
      }

      if (windowDays !== null && windowDays > 0) {
        await this.store.pruneOldRecords(windowDays);
      }

      await this.store.updateSyncState('ok', '', totalInserted);
      this.setPhase('done', `同步完成, 新增 ${totalInserted} 条`);
      this.busy = false;
      return { ok: true, inserted: totalInserted };
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      await this.store.updateSyncState('error', msg, this.progress.inserted);
      this.setPhase('error', msg);
      this.busy = false;
      return { ok: false, error: msg };
    }
  }

  private async fetchOne(workspaceId: string, page: number): Promise<UsageRecordOrError> {
    try {
      const records = await this.fetcher.fetchUsagePage(workspaceId, page);
      return { records: records };
    } catch (e) {
      return { records: [], error: e instanceof Error ? e.message : String(e) };
    }
  }

  async startAutoSyncLoop(): Promise<void> {
    this.stopAutoSync();
    const intervalSec = await this.getIntervalSec();
    this.timer = setInterval(() => {
      if (this.busy) {
        return;
      }
      this.sync('incremental');
    }, intervalSec * 1000) as unknown as number;
  }

  stopAutoSync(): void {
    if (this.timer !== null) {
      clearInterval(this.timer);
      this.timer = null;
    }
  }

  private async getIntervalSec(): Promise<number> {
    const store = this.store as UsageStore;
    // 读取设置：默认 300s
    const settings = await (store as unknown as { getSyncIntervalSec?: () => Promise<number> }).getSyncIntervalSec?.();
    return settings !== undefined ? settings : 300;
  }
}

interface UsageRecordOrError {
  records: import('../model/UsageRecord').UsageRecord[];
  error?: string;
}
```

> 说明：`getIntervalSec` 通过可选方法读取同步间隔；若 store 未实现 `getSyncIntervalSec`（如测试 FakeStore），回退 300s。真实环境由 `SettingsStore` 提供。

- [ ] **Step 5: 注册并运行测试**

将 `SyncManager.test` 加入 `src/test/List.test.ets`。DevEco Studio 运行 `List.test`。预期：3 个 SyncManager 用例全部通过。

- [ ] **Step 6: Commit（非 git 仓库则跳过）**

```bash
git add entry/src/main/ets/network entry/src/test
git commit -m "feat: sync state machine with tests"
```

---

### Task 6: 登录页 + Index 导航壳 + Mock 数据源

**Files:**
- Create: `entry/src/main/ets/auth/LoginPage.ets`
- Create: `entry/src/main/ets/data/MockRepository.ets`（实现 UsageStore，提供示例数据）
- Create: `entry/src/main/ets/data/DataProvider.ets`（按 USE_MOCK_DATA 返回 store/fetcher 单例）
- Modify: `entry/src/main/ets/pages/Index.ets`（导航壳 + 欢迎页）
- Modify: `entry/src/main/ets/pages/Login.ets`（登录页）
- Create: `entry/src/main/ets/components/ui/*.ets`（Task 6 用到的基础组件：StatCard 等放 Task 7/8 再建，此处只建壳与欢迎页）

**Interfaces:**
- Consumes: `AppContext`、`UsageRepository`、`SettingsStore`、`OpenCodeApi`、`SyncManager`、`webview`（`@kit.ArkWeb`）。
- Produces:
  - `class MockRepository implements UsageStore`（静态示例数据）
  - `class DataProvider { static getStore(): UsageStore; static getFetcher(): UsageFetcher; static getSyncManager(): SyncManager }`
  - `page Login`（`@Entry @Component struct Login`）：内嵌 Web，成功回调 `(token, workspaceHint)` → `router.back()` 并触发首同步。
  - `page Index`：导航壳 + 欢迎页，5 Tab（占位，Task 8-11 填充）。

- [ ] **Step 1: 实现 `MockRepository.ets`（示例数据，供无账号调试）**

```typescript
// entry/src/main/ets/data/MockRepository.ets
import type { UsageStore } from './UsageStore';
import type { UsageRecord, SyncState } from '../model/UsageRecord';
import { Constants } from '../common/constants/Constants';

function seedRecords(): UsageRecord[] {
  const out: UsageRecord[] = [];
  const models: string[] = ['gpt-4o', 'claude-opus-4', 'deepseek-chat', 'glm-4-plus', 'qwen-max'];
  const now = Date.now();
  for (let i = 0; i < 800; i++) {
    const ts = now - i * 5400 * 1000; // 每 1.5 小时一条，覆盖约 50 天
    const input = 800 + Math.floor(Math.random() * 12000);
    const output = 300 + Math.floor(Math.random() * 4000);
    const reasoning = Math.floor(Math.random() * 2000);
    const cacheRead = Math.floor(Math.random() * 20000);
    const cacheWrite = Math.floor(Math.random() * 3000);
    const costRaw = Math.floor((input + output) * 8 + Math.random() * 1000);
    out.push({
      usgId: `usg_mock_${i}`,
      createdAt: new Date(ts).toISOString(),
      model: models[i % models.length],
      provider: models[i % models.length].split('-')[0],
      inputTokens: input,
      outputTokens: output,
      reasoningTokens: reasoning,
      cacheReadTokens: cacheRead,
      cacheWrite5mTokens: cacheWrite,
      cacheWrite1hTokens: 0,
      costRaw: costRaw,
      costUsd: costRaw / 100000000,
      keyId: 'k1',
      sessionId: `ses_${Math.floor(i / 6)}`,
      plan: 'pro',
      syncedAt: new Date().toISOString(),
    });
  }
  return out;
}

/** Mock 数据仓储：无账号时返回示例用量，便于调试 UI 与图表。 */
export class MockRepository implements UsageStore {
  private records: UsageRecord[] = seedRecords();
  private syncState: SyncState = {
    lastSyncAt: new Date().toISOString(), lastSyncStatus: 'ok', lastSyncError: '',
    lastInsertedCount: 0, deepestPageFetched: 0, totalRecords: 800,
    oldestRecordAt: this.records[this.records.length - 1].createdAt,
    newestRecordAt: this.records[0].createdAt,
  };

  async getToken(): Promise<string> { return Constants.USE_MOCK_DATA ? 'auth=mock' : ''; }
  async getWorkspaceHint(): Promise<string> { return 'wrk_mock'; }
  async saveResolvedWorkspace(workspaceId: string): Promise<void> {}
  async saveToken(token: string, workspaceId: string): Promise<void> {}
  async insertUsageRecords(records: UsageRecord[]): Promise<number> {
    let n = 0;
    const known = new Set(this.records.map((r) => r.usgId));
    for (const r of records) {
      if (!known.has(r.usgId)) {
        this.records.push(r);
        n++;
      }
    }
    this.syncState.totalRecords = this.records.length;
    return n;
  }
  async pruneOldRecords(windowDays: number): Promise<number> {
    const cutoff = Date.now() - windowDays * 86400 * 1000;
    const before = this.records.length;
    this.records = this.records.filter((r) => Date.parse(r.createdAt) >= cutoff);
    this.syncState.totalRecords = this.records.length;
    return before - this.records.length;
  }
  async getWindowDays(): Promise<number | null> { return 60; }
  async updateSyncState(status: string, error: string, inserted: number): Promise<void> {
    this.syncState.lastSyncStatus = status;
    this.syncState.lastSyncError = error;
    this.syncState.lastInsertedCount += inserted;
  }
  async getSyncState(): Promise<SyncState> { return this.syncState; }

  // 聚合查询（Mock：委托到内存计算，见 Step 2）
  async totals(period: string): Promise<Totals> { return this.calcTotals(period); }
  async modelStats(period: string): Promise<ModelStat[]> { return this.calcModels(period); }
  async dailyStats(days: number): Promise<DailyStat[]> { return this.calcDaily(days); }
  async todayTrend(): Promise<TrendPoint[]> { return this.calcTrend(); }
  async sessionStatsPage(page: number, pageSize: number, days: number | null): Promise<[SessionStat[], number]> { return [[], 0]; }
  async usageRecordsPage(page: number, pageSize: number, model: string | null, days: number | null): Promise<[RecordRow[], number]> { return [[], 0]; }
  async listModels(): Promise<string[]> { return [...new Set(this.records.map((r) => r.model))].sort(); }

  private inPeriod(r: UsageRecord, period: string): boolean {
    const ms = Date.parse(r.createdAt);
    const now = Date.now();
    if (period === Constants.PERIOD_TODAY) {
      const d = new Date();
      return new Date(ms).getDate() === d.getDate() && new Date(ms).getMonth() === d.getMonth();
    }
    if (period === Constants.PERIOD_ALL) {
      return true;
    }
    const m = /^(\d+)d$/.exec(period);
    const days = m !== null ? Number(m[1]) : 30;
    return now - ms <= days * 86400 * 1000;
  }

  private calcTotals(period: string): Totals { /* Step 3 填充 */ return {} as Totals; }
  private calcModels(period: string): ModelStat[] { return []; }
  private calcDaily(days: number): DailyStat[] { return []; }
  private calcTrend(): TrendPoint[] { return []; }
}
```

- [ ] **Step 2: 用内存聚合补齐 Mock 查询实现（替换 `calcTotals` 等）**

```typescript
  private calcTotals(period: string): Totals {
    const inP = this.inPeriod;
    const recs = this.records.filter((r) => inP(r, period));
    let requestCount = 0;
    const sessions = new Set<string>();
    let totalInput = 0, uncachedInput = 0, reasoning = 0, hit = 0, write = 0, output = 0, cost = 0;
    for (const r of recs) {
      requestCount++;
      if (r.sessionId !== '') { sessions.add(r.sessionId); }
      totalInput += r.inputTokens + r.cacheReadTokens + r.cacheWrite5mTokens + r.cacheWrite1hTokens;
      uncachedInput += r.inputTokens;
      reasoning += r.reasoningTokens;
      hit += r.cacheReadTokens;
      write += r.cacheWrite5mTokens + r.cacheWrite1hTokens;
      output += r.outputTokens;
      cost += r.costUsd;
    }
    const hitRate = hit + uncachedInput > 0 ? Number((hit / (hit + uncachedInput) * 100).toFixed(2)) : 0;
    return {
      requestCount, sessionCount: sessions.size, totalInputTokens: totalInput,
      uncachedInputTokens: uncachedInput, totalReasoningTokens: reasoning,
      cacheHitTokens: hit, cacheWriteTokens: write, totalOutputTokens: output,
      totalCostUsd: Number(cost.toFixed(6)), hitRate,
    };
  }

  private calcModels(period: string): ModelStat[] {
    const inP = this.inPeriod;
    const map = new Map<string, ModelStat>();
    for (const r of this.records) {
      if (!inP(r, period)) { continue; }
      let stat = map.get(r.model);
      if (stat === undefined) {
        stat = { model: r.model, requestCount: 0, sessionCount: 0, totalInputTokens: 0, uncachedInputTokens: 0, totalReasoningTokens: 0, cacheHitTokens: 0, cacheWriteTokens: 0, totalOutputTokens: 0, totalCostUsd: 0, hitRate: 0 };
        map.set(r.model, stat);
      }
      stat.requestCount++;
      if (r.sessionId !== '') { /* 近似 */ }
      stat.totalInputTokens += r.inputTokens + r.cacheReadTokens + r.cacheWrite5mTokens + r.cacheWrite1hTokens;
      stat.uncachedInputTokens += r.inputTokens;
      stat.totalReasoningTokens += r.reasoningTokens;
      stat.cacheHitTokens += r.cacheReadTokens;
      stat.cacheWriteTokens += r.cacheWrite5mTokens + r.cacheWrite1hTokens;
      stat.totalOutputTokens += r.outputTokens;
      stat.totalCostUsd += r.costUsd;
    }
    const out = [...map.values()];
    out.sort((a, b) => (b.totalInputTokens + b.totalOutputTokens) - (a.totalInputTokens + a.totalOutputTokens));
    for (const s of out) {
      s.hitRate = s.cacheHitTokens + s.uncachedInputTokens > 0
        ? Number((s.cacheHitTokens / (s.cacheHitTokens + s.uncachedInputTokens) * 100).toFixed(2)) : 0;
      s.totalCostUsd = Number(s.totalCostUsd.toFixed(6));
    }
    return out;
  }

  private calcDaily(days: number): DailyStat[] {
    const now = Date.now();
    const cutoff = now - days * 86400 * 1000;
    const map = new Map<string, DailyStat>();
    for (const r of this.records) {
      const ms = Date.parse(r.createdAt);
      if (ms < cutoff) { continue; }
      const d = new Date(ms);
      const p = (v: number): string => (v < 10 ? `0${v}` : `${v}`);
      const key = `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}`;
      let stat = map.get(key);
      if (stat === undefined) {
        stat = { date: key, totalInputTokens: 0, uncachedInputTokens: 0, totalReasoningTokens: 0, cacheHitTokens: 0, cacheWriteTokens: 0, totalOutputTokens: 0, totalCostUsd: 0, requestCount: 0, hitRate: 0 };
        map.set(key, stat);
      }
      stat.totalInputTokens += r.inputTokens + r.cacheReadTokens + r.cacheWrite5mTokens + r.cacheWrite1hTokens;
      stat.uncachedInputTokens += r.inputTokens;
      stat.totalReasoningTokens += r.reasoningTokens;
      stat.cacheHitTokens += r.cacheReadTokens;
      stat.cacheWriteTokens += r.cacheWrite5mTokens + r.cacheWrite1hTokens;
      stat.totalOutputTokens += r.outputTokens;
      stat.totalCostUsd += r.costUsd;
      stat.requestCount++;
    }
    const out = [...map.values()];
    out.sort((a, b) => a.date.localeCompare(b.date));
    for (const s of out) {
      s.hitRate = s.cacheHitTokens + s.uncachedInputTokens > 0
        ? Number((s.cacheHitTokens / (s.cacheHitTokens + s.uncachedInputTokens) * 100).toFixed(2)) : 0;
      s.totalCostUsd = Number(s.totalCostUsd.toFixed(6));
    }
    return out;
  }

  private calcTrend(): TrendPoint[] {
    const d = new Date();
    const map = new Map<number, { input: number; output: number; reasoning: number }>();
    for (const r of this.records) {
      const ms = Date.parse(r.createdAt);
      const rd = new Date(ms);
      if (rd.getDate() !== d.getDate() || rd.getMonth() !== d.getMonth()) { continue; }
      const h = rd.getHours();
      const item = map.get(h);
      if (item !== undefined) {
        item.input += r.inputTokens;
        item.output += r.outputTokens;
        item.reasoning += r.reasoningTokens;
      } else {
        map.set(h, { input: r.inputTokens, output: r.outputTokens, reasoning: r.reasoningTokens });
      }
    }
    const out: TrendPoint[] = [];
    for (let h = 0; h < 24; h++) {
      const item = map.get(h);
      const p = (v: number): string => (v < 10 ? `0${v}` : `${v}`);
      out.push({ hour: `${p(h)}:00`, input: item !== undefined ? item.input : 0, output: item !== undefined ? item.output : 0, reasoning: item !== undefined ? item.reasoning : 0 });
    }
    return out;
  }
```

> 说明：`MockRepository` 需在文件顶部 `import type { Totals, ModelStat, DailyStat, TrendPoint } from '../model/Stats';`（Step 1 未含，请补上）。`usageRecordsPage`/`sessionStatsPage` 返回空——Task 10 之前 Mock 记录页可显示空列表，若需完整可在 Task 10 补内存分页实现。

- [ ] **Step 3: 实现 `DataProvider.ets`（按开关选择真实/Mock）**

```typescript
// entry/src/main/ets/data/DataProvider.ets
import { Constants } from '../common/constants/Constants';
import type { UsageStore } from './UsageStore';
import { UsageRepository } from './UsageRepository';
import { MockRepository } from './MockRepository';
import type { UsageFetcher } from '../network/UsageFetcher';
import { OpenCodeApi } from '../network/OpenCodeApi';
import type { UsageRecord } from '../model/UsageRecord';
import { SyncManager } from '../network/SyncManager';

const realFetcher: UsageFetcher = {
  fetchUsagePage: async (ws: string, page: number, keyId?: string): Promise<UsageRecord[]> => {
    const token = await DataProvider.getStore().getToken();
    return OpenCodeApi.fetchUsagePage(token, ws, page, keyId ?? '');
  },
};

/** 统一入口：按 Constants.USE_MOCK_DATA 返回真实或 Mock 实现。 */
export class DataProvider {
  private static store: UsageStore | null = null;
  private static fetcher: UsageFetcher | null = null;
  private static sync: SyncManager | null = null;

  static getStore(): UsageStore {
    if (DataProvider.store === null) {
      DataProvider.store = Constants.USE_MOCK_DATA ? new MockRepository() : new UsageRepository();
    }
    return DataProvider.store;
  }

  static getFetcher(): UsageFetcher {
    if (DataProvider.fetcher === null) {
      DataProvider.fetcher = realFetcher;
    }
    return DataProvider.fetcher;
  }

  static getSyncManager(): SyncManager {
    if (DataProvider.sync === null) {
      DataProvider.sync = new SyncManager(DataProvider.getStore(), DataProvider.getFetcher());
    }
    return DataProvider.sync;
  }
}
```

- [ ] **Step 4: 实现登录页 `pages/Login.ets`**

```typescript
// entry/src/main/ets/pages/Login.ets
import { router } from '@kit.ArkUI';
import { webview } from '@kit.ArkWeb';
import { OpenCodeApi } from '../network/OpenCodeApi';
import { DataProvider } from '../data/DataProvider';
import { Constants } from '../common/constants/Constants';

const WORKSPACE_URL_RE: RegExp = /\/workspace\/(wrk_[A-Za-z0-9]+)/;

@Entry
@Component
struct Login {
  @State loginUrl: string = OpenCodeApi.buildLoginUrl();
  @State loading: boolean = true;
  @State done: boolean = false;
  private controller: webview.WebviewController = new webview.WebviewController();

  private async captureAndFinish(url: string): Promise<void> {
    if (this.done) {
      return;
    }
    const cookies = webview.WebCookieManager.getCookieSync(Constants.LOGIN_COOKIE_DOMAIN);
    if (cookies === null || cookies === '') {
      return;
    }
    let authValue = '';
    for (const part of cookies.split(';')) {
      const p = part.trim();
      if (p.startsWith(`${Constants.AUTH_COOKIE_NAME}=`)) {
        authValue = p.substring(Constants.AUTH_COOKIE_NAME.length + 1);
        break;
      }
    }
    if (authValue === '') {
      return;
    }
    const m = WORKSPACE_URL_RE.exec(url);
    const workspaceHint = m !== null ? m[1] : 'Default';
    this.done = true;
    await DataProvider.getStore().saveToken(`auth=${authValue}`, workspaceHint);
    // 触发首次全量同步（后台）
    DataProvider.getSyncManager().sync('full');
    router.back();
  }

  build() {
    Column() {
      Row() {
        Text('GoGauge')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
        Blank()
        Button('取消')
          .fontSize(14)
          .onClick(() => router.back())
      }
      .width('100%')
      .padding(12)

      if (this.loading) {
        LoadingProgress().width(40).height(40)
      }

      Web({ src: this.loginUrl, controller: this.controller })
        .width('100%')
        .height('100%')
        .onPageBegin((event) => {
          this.loading = false;
        })
        .onUrlLoadIntercept((event) => {
          const url = event.data.url;
          if (url.startsWith('https://opencode.ai')) {
            this.captureAndFinish(url);
          }
          return false;
        })
        .javaScriptAccess(true)
        .domStorageAccess(true)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.bg_page'))
  }
}
```

> 说明：`webview.WebCookieManager.getCookieSync` 为静态方法，直接读取域 cookie。若编译报 `WebCookieManager` 不可用，改用 `this.controller.getCookieSync()`（`WebviewController.getCookieSync(url)`）。二者取其一，以 SDK 实际 API 为准（6.1 均有）。

- [ ] **Step 5: 实现导航壳 `pages/Index.ets`（含欢迎页 + 5 Tab 占位）**

```typescript
// entry/src/main/ets/pages/Index.ets
import { router } from '@kit.ArkUI';
import { display } from '@kit.ArkUI';
import { DataProvider } from '../data/DataProvider';

@Entry
@Component
struct Index {
  @State currentTab: number = 0;
  @State loggedIn: boolean = false;
  @State wide: boolean = false;

  aboutToAppear(): void {
    this.checkLogin();
    this.updateLayout();
  }

  onPageShow(): void {
    this.checkLogin();
    this.updateLayout();
  }

  private async checkLogin(): Promise<void> {
    const token = await DataProvider.getStore().getToken();
    this.loggedIn = token.trim() !== '';
  }

  private updateLayout(): void {
    const w = display.getDefaultDisplaySync().width;
    this.wide = w >= 840;
  }

  @Builder
  WelcomePage() {
    Column({ space: 16 }) {
      Text('GoGauge')
        .fontSize(40)
        .fontWeight(FontWeight.Bold)
      Text($r('app.string.welcome_desc'))
        .fontSize(14)
        .fontColor($r('app.color.text_secondary'))
        .textAlign(TextAlign.Center)
        .padding({ left: 32, right: 32 })
      Column({ space: 8 }) {
        Text(`· ${$r('app.string.welcome_feat_1') as string}`).fontSize(14)
        Text(`· ${$r('app.string.welcome_feat_2') as string}`).fontSize(14)
        Text(`· ${$r('app.string.welcome_feat_3') as string}`).fontSize(14)
      }
      .alignItems(HorizontalAlign.Start)

      Button($r('app.string.login_btn'))
        .fontSize(16)
        .width(200)
        .height(44)
        .onClick(() => {
          router.pushUrl({ url: 'pages/Login' });
        })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  TabContentPlaceholder(label: string) {
    Column() {
      Text(label)
        .fontSize(16)
        .fontColor($r('app.color.text_muted'))
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  TabBar() {
    Row() {
      this.TabItem(0, $r('app.string.tab_home'))
      this.TabItem(1, $r('app.string.tab_stats'))
      this.TabItem(2, $r('app.string.tab_records'))
      this.TabItem(3, $r('app.string.tab_settings'))
      this.TabItem(4, $r('app.string.tab_about'))
    }
    .width('100%')
    .height(56)
    .backgroundColor($r('app.color.bg_card'))
  }

  @Builder
  TabItem(index: number, label: ResourceStr) {
    Column({ space: 2 }) {
      Text(index === 0 ? '◧' : index === 1 ? '◬' : index === 2 ? '▤' : index === 3 ? '⚙' : 'ⓘ')
        .fontSize(20)
        .fontColor(this.currentTab === index ? $r('app.color.accent') : $r('app.color.text_muted'))
      Text(label)
        .fontSize(11)
        .fontColor(this.currentTab === index ? $r('app.color.accent') : $r('app.color.text_muted'))
    }
    .layoutWeight(1)
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .onClick(() => {
      this.currentTab = index;
    })
  }

  build() {
    if (!this.loggedIn) {
      this.WelcomePage();
    } else {
      Row() {
        if (this.wide) {
          // 平板：左侧导航栏
          Column() {
            ForEach([$r('app.string.tab_home'), $r('app.string.tab_stats'), $r('app.string.tab_records'),
              $r('app.string.tab_settings'), $r('app.string.tab_about')], (item: Resource, i: number) => {
              Text(item)
                .fontSize(16)
                .fontColor(this.currentTab === i ? $r('app.color.accent') : $r('app.color.text_secondary'))
                .padding(12)
                .width('100%')
                .onClick(() => { this.currentTab = i; })
            }, (item: Resource, i: number) => `${item}_${i}`)
          }
          .width(180)
          .height('100%')
          .backgroundColor($r('app.color.bg_card'))

          this.MainArea()
        } else {
          Column() {
            this.MainArea()
            this.TabBar()
          }
          .width('100%')
          .height('100%')
        }
      }
      .width('100%')
      .height('100%')
    }
  }

  @Builder
  MainArea() {
    Column() {
      if (this.currentTab === 0) {
        this.TabContentPlaceholder('首页占位')
      } else if (this.currentTab === 1) {
        this.TabContentPlaceholder('统计占位')
      } else if (this.currentTab === 2) {
        this.TabContentPlaceholder('记录占位')
      } else if (this.currentTab === 3) {
        this.TabContentPlaceholder('设置占位')
      } else {
        this.TabContentPlaceholder('关于占位')
      }
    }
    .layoutWeight(1)
    .width('100%')
  }
}
```

> 说明：Tab 图标用文本符号占位，后续可换图标资源。`ResourceStr`/`Resource` 是 ArkTS 内置类型。

- [ ] **Step 6: 验证编译 + 冒烟**

DevEco Studio：`Build → Make Project`，然后运行到模拟器：未登录显示欢迎页 → 点「立即登录」→ 进入 Login 页加载授权页（真实登录需账号；Mock 模式下也可直接看 Welcome 后续）。Mock 模式（`USE_MOCK_DATA=true`）下 `getToken()` 返回 mock，会直接进入 Tab 壳（占位页）。

- [ ] **Step 7: Commit（非 git 仓库则跳过）**

```bash
git add entry/src/main/ets/auth entry/src/main/ets/data entry/src/main/ets/pages
git commit -m "feat: login page, nav shell, mock data provider"
```

---

### Task 7: Canvas 图表组件（Bar / Donut / Line）

**Files:**
- Create: `entry/src/main/ets/components/charts/BarChart.ets`
- Create: `entry/src/main/ets/components/charts/DonutChart.ets`
- Create: `entry/src/main/ets/components/charts/LineChart.ets`
- Create: `entry/src/main/ets/components/charts/ChartTheme.ets`（色板取值 helper）

**Interfaces:**
- Consumes: `$r` 资源色板。
- Produces:
  - `struct BarChart { @Prop values: number[]; @Prop labels: string[]; @Prop colors: string[]; @Prop version: number; }`（`version` 变化触发重绘）
  - `struct DonutChart { @Prop items: DonutItem[]; @Prop centerTitle: string; @Prop centerValue: string; @Prop version: number; }`，`interface DonutItem { label: string; value: number; color: string }`
  - `struct LineChart { @Prop series: LineSeries[]; @Prop labels: string[]; @Prop version: number; }`，`interface LineSeries { name: string; color: string; values: number[] }`

- [ ] **Step 1: 实现 `ChartTheme.ets`（取色 helper）**

```typescript
// entry/src/main/ets/components/charts/ChartTheme.ets
import { getResourceString } from '@kit.ArkUI';

/** 通过 $r 取当前主题色板颜色（随深/浅色自动切换）。 */
export class ChartTheme {
  static color(name: string): string {
    // $r('app.color.' + name) 动态构造需在组件内用 getResourceString
    return '';
  }
}
```

> 说明：ChartTheme 作为色板取值的占位设计；实际绘图组件内直接用 `$r('app.color.bar_input')` 的字符串形式传入绘制颜色。为保证 Canvas 绘制能拿到色值，组件通过 `this.colors` 传入**已解析的色值字符串**（由页面层用 `getContext(this).resourceManager.getColorSync(...)` 解析）。为简化，Task 7 各图表组件接受 `string[]` 颜色参数，页面传入字面色值即可（浅色/深色由页面根据主题选择传参）。**删除 ChartTheme.ets 或用静态色值即可**——本任务改为在页面层解析色板。

- [ ] **Step 2: 实现 `BarChart.ets`**

```typescript
// entry/src/main/ets/components/charts/BarChart.ets
@Component
export struct BarChart {
  @Prop labels: string[] = [];
  @Prop values: number[] = [];
  @Prop colors: string[] = [];
  @Prop version: number = 0;
  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);
  @State axisColor: string = '#999999';
  @State textColor: string = '#666666';

  private max(): number {
    let m = 0;
    for (const v of this.values) {
      if (v > m) { m = v; }
    }
    return m > 0 ? m : 1;
  }

  private redraw(): void {
    if (this.ctx.width > 0 && this.ctx.height > 0) {
      this.draw();
    }
  }

  private draw(): void {
    const w = this.ctx.width;
    const h = this.ctx.height;
    const padL = 34;
    const padR = 8;
    const padT = 10;
    const padB = 22;
    const plotW = w - padL - padR;
    const plotH = h - padT - padB;
    this.ctx.clearRect(0, 0, w, h);
    const n = this.values.length;
    if (n === 0) {
      return;
    }
    const slot = plotW / n;
    const bw = slot * 0.6;
    const max = this.max();
    // Y 轴网格
    this.ctx.fillStyle = this.axisColor;
    this.ctx.strokeStyle = this.axisColor;
    this.ctx.font = '9vp sans-serif';
    for (let g = 0; g <= 4; g++) {
      const gy = padT + plotH - (plotH * g / 4);
      this.ctx.beginPath();
      this.ctx.moveTo(padL, gy);
      this.ctx.lineTo(w - padR, gy);
      this.ctx.globalAlpha = 0.15;
      this.ctx.stroke();
      this.ctx.globalAlpha = 1;
      const val = Math.round(max * g / 4);
      this.ctx.fillText(`${val}`, 4, gy + 3);
    }
    // 柱子
    for (let i = 0; i < n; i++) {
      const barH = this.values[i] > 0 ? (this.values[i] / max) * plotH : 1;
      const x = padL + i * slot + (slot - bw) / 2;
      const y = padT + plotH - barH;
      this.ctx.fillStyle = this.colors[i % this.colors.length];
      this.ctx.fillRect(x, y, bw, barH);
      // 标签
      this.ctx.fillStyle = this.textColor;
      if (i % Math.max(1, Math.floor(n / 8)) === 0) {
        this.ctx.fillText(this.labels[i] ?? '', x, h - 8);
      }
    }
  }

  build() {
    Canvas(this.ctx)
      .width('100%')
      .height('100%')
      .onReady(() => {
        this.redraw();
      })
  }
}
```

> 说明：`version` 变化时由父组件 `if` 重建或手动触发重绘。ArkUI `@Prop version` 变化不会自动调用 `draw`，页面可在数据变化后通过 `this.ctx` 直接调用——为此**在每个图表组件暴露 `drawNow()` 方法**：`drawNow(): void { this.redraw(); }`（补充到上述 struct 内，父组件用 `@State chartRef: BarChart` 的 `child()` 方式调用）。简化方案：父组件用 `.key(this.dataVersion)` 强制重建组件，`onReady` 时即重绘。**采用 `.key()` 重建方案**——Task 8 起所有图表在数据变更后通过 `.key(version)` 重建。

- [ ] **Step 3: 实现 `DonutChart.ets`**

```typescript
// entry/src/main/ets/components/charts/DonutChart.ets

export interface DonutItem {
  label: string;
  value: number;
  color: string;
}

@Component
export struct DonutChart {
  @Prop items: DonutItem[] = [];
  @Prop centerTitle: string = '';
  @Prop centerValue: string = '';
  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);

  private total(): number {
    let t = 0;
    for (const it of this.items) {
      t += it.value;
    }
    return t;
  }

  private draw(): void {
    const w = this.ctx.width;
    const h = this.ctx.height;
    this.ctx.clearRect(0, 0, w, h);
    const cx = w / 2;
    const cy = h / 2;
    const r = Math.min(w, h) / 2 - 8;
    const innerR = r * 0.62;
    const total = this.total();
    if (total <= 0) {
      this.ctx.fillStyle = '#e8eaed';
      this.ctx.beginPath();
      this.ctx.arc(cx, cy, r, 0, Math.PI * 2);
      this.ctx.fill();
      return;
    }
    let start = -Math.PI / 2;
    for (const it of this.items) {
      const sweep = (it.value / total) * Math.PI * 2;
      this.ctx.beginPath();
      this.ctx.fillStyle = it.color;
      this.ctx.moveTo(cx, cy);
      this.ctx.arc(cx, cy, r, start, start + sweep);
      this.ctx.closePath();
      this.ctx.fill();
      // 内圈挖空（环形）
      this.ctx.globalCompositeOperation = 'destination-out';
      this.ctx.beginPath();
      this.ctx.arc(cx, cy, innerR, 0, Math.PI * 2);
      this.ctx.fill();
      this.ctx.globalCompositeOperation = 'source-over';
      start += sweep;
    }
    // 中心文字
    this.ctx.fillStyle = '#1a1a1a';
    this.ctx.font = 'bold 14vp sans-serif';
    this.ctx.textAlign = 'center';
    this.ctx.fillText(this.centerValue, cx, cy - 2);
    this.ctx.font = '10vp sans-serif';
    this.ctx.fillStyle = '#999999';
    this.ctx.fillText(this.centerTitle, cx, cy + 14);
  }

  build() {
    Canvas(this.ctx)
      .width('100%')
      .height('100%')
      .onReady(() => { this.draw(); })
  }
}
```

> 说明：`globalCompositeOperation = 'destination-out'` 挖空内圈，需在浅/深色背景上正常显示（背景为卡片色时挖空透出背景）。若出现异常，可改为用 `arc` 画实心扇形后用背景色画内圆覆盖。

- [ ] **Step 4: 实现 `LineChart.ets`**

```typescript
// entry/src/main/ets/components/charts/LineChart.ets

export interface LineSeries {
  name: string;
  color: string;
  values: number[];
}

@Component
export struct LineChart {
  @Prop series: LineSeries[] = [];
  @Prop labels: string[] = [];
  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);

  private maxValue(): number {
    let m = 0;
    for (const s of this.series) {
      for (const v of s.values) {
        if (v > m) { m = v; }
      }
    }
    return m > 0 ? m : 1;
  }

  private draw(): void {
    const w = this.ctx.width;
    const h = this.ctx.height;
    const padL = 40;
    const padR = 10;
    const padT = 12;
    const padB = 22;
    const plotW = w - padL - padR;
    const plotH = h - padT - padB;
    this.ctx.clearRect(0, 0, w, h);
    const n = this.labels.length;
    if (n === 0) {
      return;
    }
    const max = this.maxValue();
    const xOf = (i: number): number => padL + (n === 1 ? plotW / 2 : (plotW * i) / (n - 1));
    const yOf = (v: number): number => padT + plotH - (v / max) * plotH;
    // 网格
    this.ctx.strokeStyle = '#999999';
    this.ctx.globalAlpha = 0.15;
    this.ctx.font = '9vp sans-serif';
    for (let g = 0; g <= 4; g++) {
      const gy = padT + (plotH * g) / 4;
      this.ctx.beginPath();
      this.ctx.moveTo(padL, gy);
      this.ctx.lineTo(w - padR, gy);
      this.ctx.stroke();
    }
    this.ctx.globalAlpha = 1;
    // 折线
    for (const s of this.series) {
      this.ctx.strokeStyle = s.color;
      this.ctx.lineWidth = 2;
      this.ctx.beginPath();
      for (let i = 0; i < n; i++) {
        const x = xOf(i);
        const y = yOf(s.values[i]);
        if (i === 0) {
          this.ctx.moveTo(x, y);
        } else {
          this.ctx.lineTo(x, y);
        }
      }
      this.ctx.stroke();
    }
    // X 标签（抽样显示）
    this.ctx.fillStyle = '#999999';
    const step = Math.max(1, Math.floor(n / 6));
    for (let i = 0; i < n; i += step) {
      this.ctx.fillText(this.labels[i], xOf(i), h - 6);
    }
  }

  build() {
    Canvas(this.ctx)
      .width('100%')
      .height('100%')
      .onReady(() => { this.draw(); })
  }
}
```

- [ ] **Step 5: 验证编译**

DevEco Studio：`Build → Make Project`。预期：无编译错误。

> 说明：Task 7 图表组件不单独测试；Task 8 首页接入后由 UI 冒烟验证。颜色由页面解析色板后作为 `string[]`/`DonutItem.color` 传入。

- [ ] **Step 6: Commit（非 git 仓库则跳过）**

```bash
git add entry/src/main/ets/components
git commit -m "feat: canvas chart components (bar/donut/line)"
```

---

### Task 8: 首页仪表盘（DashboardPage）

**Files:**
- Create: `entry/src/main/ets/pages/DashboardPage.ets`
- Create: `entry/src/main/ets/components/ui/StatCard.ets`
- Create: `entry/src/main/ets/components/ui/QuotaProgress.ets`
- Modify: `entry/src/main/ets/pages/Index.ets`（挂载 DashboardPage）
- Create: `entry/src/main/ets/pages/DashboardViewModel.ets`（页面数据加载/轮询逻辑，便于测试）

**Interfaces:**
- Consumes: `DataProvider`、`UsageRepository`（或 store 的聚合方法）、`BarChart`、`Formatter/TimeUtil`、`$r` 资源。
- Produces:
  - `struct StatCard { @Prop title: string; @Prop value: string; @Prop sub: string; @Prop accent: boolean }`
  - `struct QuotaProgress { @Prop label: string; @Prop percent: number; @Prop remainingText: string; @Prop resetText: string }`
  - `class DashboardViewModel { period: string; totals: Totals; todayTotals: Totals; trend: TrendPoint[]; quota: QuotaWindow[]; loading: boolean; async load(): Promise<void>; setPeriod(p: string): void; }`

- [ ] **Step 1: 实现 `StatCard.ets` 与 `QuotaProgress.ets`**

```typescript
// entry/src/main/ets/components/ui/StatCard.ets
@Component
export struct StatCard {
  @Prop title: string = '';
  @Prop value: string = '';
  @Prop sub: string = '';
  @Prop accent: boolean = false;

  build() {
    Column({ space: 4 }) {
      Text(this.title)
        .fontSize(12)
        .fontColor($r('app.color.text_muted'))
      Text(this.value)
        .fontSize(this.accent ? 22 : 18)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.accent ? $r('app.color.accent') : $r('app.color.text_primary'))
      if (this.sub !== '') {
        Text(this.sub)
          .fontSize(11)
          .fontColor($r('app.color.text_muted'))
      }
    }
    .width('100%')
    .padding(12)
    .borderRadius(12)
    .backgroundColor($r('app.color.bg_card'))
    .alignItems(HorizontalAlign.Start)
  }
}
```

```typescript
// entry/src/main/ets/components/ui/QuotaProgress.ets
@Component
export struct QuotaProgress {
  @Prop label: string = '';
  @Prop percent: number = 0;
  @Prop remainingText: string = '';
  @Prop resetText: string = '';

  build() {
    Column({ space: 6 }) {
      Row() {
        Text(this.label).fontSize(13).fontColor($r('app.color.text_primary'))
        Blank()
        Text(`${this.percent.toFixed(1)}%`).fontSize(13).fontWeight(FontWeight.Bold)
      }
      .width('100%')

      Progress({ value: this.percent, total: 100, type: ProgressType.Linear })
        .width('100%')
        .color($r('app.color.accent'))
        .backgroundColor($r('app.color.quota_track'))
        .height(8)

      Row() {
        Text(`剩余 ${this.remainingText}`).fontSize(11).fontColor($r('app.color.text_muted'))
        Blank()
        Text(`重置 ${this.resetText}`).fontSize(11).fontColor($r('app.color.text_muted'))
      }
      .width('100%')
    }
    .width('100%')
    .padding(14)
    .borderRadius(12)
    .backgroundColor($r('app.color.bg_card'))
  }
}
```

- [ ] **Step 2: 实现 `DashboardViewModel.ets`**

```typescript
// entry/src/main/ets/pages/DashboardViewModel.ets
import { DataProvider } from '../data/DataProvider';
import type { Totals, TrendPoint } from '../model/Stats';
import type { QuotaWindow } from '../model/UsageRecord';
import { Constants } from '../common/constants/Constants';
import { OpenCodeApi } from '../network/OpenCodeApi';

/** 首页数据加载与周期切换（无 UI 依赖，便于单测）。 */
export class DashboardViewModel {
  period: string = Constants.PERIOD_TODAY;
  totals: Totals = { requestCount: 0, sessionCount: 0, totalInputTokens: 0, uncachedInputTokens: 0, totalReasoningTokens: 0, cacheHitTokens: 0, cacheWriteTokens: 0, totalOutputTokens: 0, totalCostUsd: 0, hitRate: 0 };
  todayTotals: Totals = this.totals;
  trend: TrendPoint[] = [];
  daily: Array<import('../model/Stats').DailyStat> = [];
  quota: QuotaWindow[] = [];
  loading: boolean = false;
  loaded: boolean = false;

  setPeriod(p: string): void {
    this.period = p;
  }

  async load(): Promise<void> {
    this.loading = true;
    const store = DataProvider.getStore() as unknown as UsageAggregator;
    this.totals = await store.totals(this.period);
    this.todayTotals = await store.totals(Constants.PERIOD_TODAY);
    this.trend = await store.todayTrend();
    this.daily = await store.dailyStats(7);
    this.quota = await this.loadQuota();
    this.loading = false;
    this.loaded = true;
  }

  private async loadQuota(): Promise<QuotaWindow[]> {
    const token = await DataProvider.getStore().getToken();
    if (token.trim() === '' || Constants.USE_MOCK_DATA) {
      // Mock 或未登录：返回模拟配额窗口
      return [
        { label: '5h', used: 42.5, remaining: 57.5, total: 100, unit: '%', resetAt: '', resetInSec: 3720 },
        { label: 'weekly', used: 60.2, remaining: 39.8, total: 100, unit: '%', resetAt: '', resetInSec: 86400 },
        { label: 'monthly', used: 7.8, remaining: 92.2, total: 100, unit: '%', resetAt: '', resetInSec: 2592000 },
      ];
    }
    const hint = await DataProvider.getStore().getWorkspaceHint();
    const result = await OpenCodeApi.fetchQuota(token, hint);
    return result.success ? result.windows : [];
  }
}

/** 聚合查询的最小接口（UsageRepository 与 MockRepository 均实现）。 */
export interface UsageAggregator {
  totals(period: string): Promise<Totals>;
  todayTrend(): Promise<TrendPoint[]>;
  dailyStats(days: number): Promise<Array<import('../model/Stats').DailyStat>>;
}
```

> 说明：`DataProvider.getStore()` 返回 `UsageStore`，不含聚合方法；页面/ViewModel 通过 `as unknown as UsageAggregator` 断言。更稳做法：`DataProvider` 额外暴露 `getAggregator(): UsageAggregator`，Task 8 Step 3 补充。

- [ ] **Step 3: 扩展 `DataProvider` 暴露聚合接口**

在 `DataProvider.ets` 增加：

```typescript
  static getAggregator(): UsageAggregator {
    return DataProvider.getStore() as unknown as UsageAggregator;
  }
```

并在文件头部 `import type { UsageAggregator } from '../pages/DashboardViewModel';`（或把 `UsageAggregator` 移到 `model/Stats.ets` 统一导出，更佳——**将 `UsageAggregator` 定义移至 `model/Stats.ets`**，Task 8 Step 2 中改为 `import { UsageAggregator } from '../model/Stats'`，并让 `DashboardViewModel` 从 `model/Stats` 引入）。

- [ ] **Step 4: 实现 `DashboardPage.ets`**

```typescript
// entry/src/main/ets/pages/DashboardPage.ets
import { DashboardViewModel } from './DashboardViewModel';
import { StatCard } from '../components/ui/StatCard';
import { QuotaProgress } from '../components/ui/QuotaProgress';
import { BarChart } from '../components/charts/BarChart';
import { formatTokens, formatCost, formatPercent } from '../common/utils/Formatter';
import { formatDurationShort, parseIso } from '../common/utils/TimeUtil';
import { Constants } from '../common/constants/Constants';
import { SettingsStore } from '../data/SettingsStore';
import { OpenCodeApi } from '../network/OpenCodeApi';

@Component
export struct DashboardPage {
  @State vm: DashboardViewModel = new DashboardViewModel();
  @State chartVersion: number = 0;
  @State currency: string = 'CNY';
  @State usdCny: number = Constants.DEFAULT_USD_CNY;

  aboutToAppear(): void {
    this.refresh();
    this.initCurrency();
  }

  private async refresh(): Promise<void> {
    await this.vm.load();
    this.chartVersion++;
  }

  private async initCurrency(): Promise<void> {
    this.currency = await SettingsStore.getCurrency();
    this.usdCny = await OpenCodeApi.fetchUsdCny();
  }

  @Builder
  RangePills() {
    Row({ space: 6 }) {
      this.Pill(Constants.PERIOD_TODAY, $r('app.string.today'))
      this.Pill('7d', $r('app.string.days_7'))
      this.Pill('30d', $r('app.string.days_30'))
      this.Pill(Constants.PERIOD_ALL, $r('app.string.all'))
    }
  }

  @Builder
  Pill(period: string, label: Resource) {
    Text(label)
      .fontSize(12)
      .padding({ left: 12, right: 12, top: 5, bottom: 5 })
      .borderRadius(14)
      .backgroundColor(this.vm.period === period ? $r('app.color.accent') : $r('app.color.divider'))
      .fontColor(this.vm.period === period ? Color.White : $r('app.color.text_secondary'))
      .onClick(() => {
        this.vm.setPeriod(period);
        this.refresh();
      })
  }

  @Builder
  QuotaRow() {
    Column({ space: 10 }) {
      Row() {
        Text($r('app.string.quota_title')).fontSize(15).fontWeight(FontWeight.Bold)
        Blank()
      }
      .width('100%')
      ForEach(this.vm.quota, (q: QuotaWindow) => {
        QuotaProgress({
          label: this.quotaLabel(q.label),
          percent: q.used,
          remainingText: `${q.remaining}%`,
          resetText: formatDurationShort(q.resetInSec),
        })
      }, (q: QuotaWindow) => q.label)
    }
    .width('100%')
  }

  private quotaLabel(label: string): string {
    if (label === '5h') { return '5小时'; }
    if (label === 'weekly') { return '每周'; }
    return '每月';
  }

  @Builder
  OverviewGrid() {
    Column({ space: 10 }) {
      Row() {
        Text($r('app.string.overview_title')).fontSize(15).fontWeight(FontWeight.Bold)
        Blank()
      }
      .width('100%')

      Grid() {
        GridItem() {
          StatCard({ title: $r('app.string.ov_hit_rate') as string, value: formatPercent(this.vm.totals.hitRate), sub: '', accent: true })
        }
        GridItem() {
          StatCard({ title: $r('app.string.ov_hits') as string, value: formatTokens(this.vm.totals.cacheHitTokens), sub: '', accent: false })
        }
        GridItem() {
          StatCard({ title: $r('app.string.ov_total_tokens') as string, value: formatTokens(this.vm.totals.totalInputTokens + this.vm.totals.totalOutputTokens + this.vm.totals.totalReasoningTokens), sub: '', accent: false })
        }
        GridItem() {
          StatCard({ title: $r('app.string.ov_requests') as string, value: `${this.vm.totals.requestCount}`, sub: '', accent: false })
        }
        GridItem() {
          StatCard({ title: $r('app.string.ov_cost') as string, value: formatCost(this.vm.totals.totalCostUsd, this.currency, this.usdCny), sub: '', accent: false })
        }
        GridItem() {
          StatCard({ title: $r('app.string.ov_sessions') as string, value: `${this.vm.totals.sessionCount}`, sub: '', accent: false })
        }
      }
      .columnsTemplate('1fr 1fr')
      .rowsGap(10)
      .columnsGap(10)
      .width('100%')
    }
    .width('100%')
  }

  @Builder
  TodayTrendCard() {
    Column({ space: 8 }) {
      Row() {
        Text($r('app.string.today_trend')).fontSize(15).fontWeight(FontWeight.Bold)
        Text(` ${$r('app.string.hours_24')}`).fontSize(11).fontColor($r('app.color.text_muted'))
        Blank()
      }
      .width('100%')

      // 输入 + 输出分组柱状图（今日 24h）
      Row({ space: 2 }) {
        ForEach(this.vm.trend, (t: TrendPoint) => {
          Column() {
            BarChart({
              labels: [t.hour],
              values: [t.input],
              colors: [$r('app.color.bar_input') as string],
              version: this.chartVersion,
            })
              .height(180)
              .layoutWeight(1)
          }
        }, (t: TrendPoint) => t.hour)
      }
      .width('100%')
      .height(200)
    }
    .width('100%')
    .padding(12)
    .borderRadius(12)
    .backgroundColor($r('app.color.bg_card'))
  }

  build() {
    Scroll() {
      Column({ space: 12 }) {
        Row() {
          Text($r('app.string.home_title')).fontSize(18).fontWeight(FontWeight.Bold)
          Blank()
          this.RangePills()
        }
        .width('100%')

        this.QuotaRow()
        this.OverviewGrid()
        this.TodayTrendCard()
      }
      .padding(12)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.bg_page'))
    .scrollBar(BarState.Off)
  }
}
```

> 说明：今日 24h 分组柱状图当前用 24 个单柱 `BarChart` 拼接（简单直观）；如需真正分组，可用一个 `BarChart` 传入 48 个值（输入、输出交替）实现——此处以简洁可跑为准。`QuotaWindow`、`TrendPoint` 类型需 import（`model/UsageRecord`、`model/Stats`）。

- [ ] **Step 5: 挂载到 `Index.ets`**

在 `Index.ets` 的 `MainArea()` 中把首页占位替换为真实页面：

```typescript
      if (this.currentTab === 0) {
        DashboardPage()
      } else if (this.currentTab === 1) {
```

并在文件头 `import { DashboardPage } from './DashboardPage';`。

- [ ] **Step 6: 验证编译 + 冒烟**

DevEco Studio：`Make Project` + 运行。Mock 模式下首页应显示配额进度条、概览 6 卡、今日柱状图。

- [ ] **Step 7: Commit（非 git 仓库则跳过）**

```bash
git add entry/src/main/ets/pages entry/src/main/ets/components/ui
git commit -m "feat: dashboard page with quota, overview, today trend"
```

---

### Task 9: 用量统计页（StatsPage）

**Files:**
- Create: `entry/src/main/ets/pages/StatsPage.ets`
- Create: `entry/src/main/ets/pages/StatsViewModel.ets`
- Modify: `entry/src/main/ets/pages/Index.ets`

**Interfaces:**
- Consumes: `DataProvider.getAggregator()`、`DonutChart`、`LineChart`、`StatCard`、`Formatter/TimeUtil`。
- Produces:
  - `class StatsViewModel { period; totals; models: ModelStat[]; daily30: DailyStat[]; dim: 'input'|'output'|'cost'; async load(); setPeriod(); setDim(); }`

- [ ] **Step 1: 实现 `StatsViewModel.ets`**

```typescript
// entry/src/main/ets/pages/StatsViewModel.ets
import { DataProvider } from '../data/DataProvider';
import type { Totals, ModelStat, DailyStat } from '../model/Stats';
import { Constants } from '../common/constants/Constants';

/** 统计页数据：KPI、模型排行、30 天趋势。 */
export class StatsViewModel {
  period: string = '7d';
  totals: Totals = { requestCount: 0, sessionCount: 0, totalInputTokens: 0, uncachedInputTokens: 0, totalReasoningTokens: 0, cacheHitTokens: 0, cacheWriteTokens: 0, totalOutputTokens: 0, totalCostUsd: 0, hitRate: 0 };
  models: ModelStat[] = [];
  daily30: DailyStat[] = [];
  dim: 'input' | 'output' | 'cost' = 'input';
  loading: boolean = false;

  setPeriod(p: string): void { this.period = p; }
  setDim(d: 'input' | 'output' | 'cost'): void { this.dim = d; }

  async load(): Promise<void> {
    this.loading = true;
    const agg = DataProvider.getAggregator();
    this.totals = await agg.totals(this.period);
    this.models = await agg.modelStats(this.period);
    this.daily30 = await agg.dailyStats(30);
    this.loading = false;
  }
}
```

- [ ] **Step 2: 实现 `StatsPage.ets`**

```typescript
// entry/src/main/ets/pages/StatsPage.ets
import { StatsViewModel } from './StatsViewModel';
import { StatCard } from '../components/ui/StatCard';
import { DonutChart, DonutItem } from '../components/charts/DonutChart';
import { LineChart, LineSeries } from '../components/charts/LineChart';
import { formatTokens, formatCost, formatPercent } from '../common/utils/Formatter';
import { Constants } from '../common/constants/Constants';
import { SettingsStore } from '../data/SettingsStore';
import { OpenCodeApi } from '../network/OpenCodeApi';
import type { ModelStat } from '../model/Stats';

@Component
export struct StatsPage {
  @State vm: StatsViewModel = new StatsViewModel();
  @State chartVersion: number = 0;
  @State currency: string = 'CNY';
  @State usdCny: number = Constants.DEFAULT_USD_CNY;

  aboutToAppear(): void {
    this.refresh();
    this.initCurrency();
  }

  private async refresh(): Promise<void> {
    await this.vm.load();
    this.chartVersion++;
  }

  private async initCurrency(): Promise<void> {
    this.currency = await SettingsStore.getCurrency();
    this.usdCny = await OpenCodeApi.fetchUsdCny();
  }

  private dimValue(m: ModelStat, dim: string): number {
    if (dim === 'output') { return m.totalOutputTokens; }
    if (dim === 'cost') { return m.totalCostUsd; }
    return m.totalInputTokens;
  }

  private donutItems(): DonutItem[] {
    const palette = ['#2F6FED', '#34A853', '#FBBC04', '#EA4335', '#9334E6', '#00ACC1'];
    const items: DonutItem[] = [];
    this.vm.models.forEach((m, i) => {
      items.push({ label: m.model, value: this.dimValue(m, this.vm.dim), color: palette[i % palette.length] });
    });
    return items;
  }

  private trendSeries(): LineSeries[] {
    const costs = this.vm.daily30.map((d) => d.totalCostUsd);
    const requests = this.vm.daily30.map((d) => d.requestCount);
    const tokens = this.vm.daily30.map((d) => d.totalInputTokens + d.totalOutputTokens + d.totalReasoningTokens);
    return [
      { name: 'cost', color: '#EA4335', values: costs },
      { name: 'requests', color: '#2F6FED', values: requests },
      { name: 'tokens', color: '#34A853', values: tokens },
    ];
  }

  private trendLabels(): string[] {
    return this.vm.daily30.map((d) => {
      const parts = d.date.split('-');
      return parts.length >= 2 ? `${parts[1]}-${parts[2]}` : d.date;
    });
  }

  @Builder
  RangePills() {
    Row({ space: 6 }) {
      this.Pill(Constants.PERIOD_TODAY, $r('app.string.today'))
      this.Pill('7d', $r('app.string.days_7'))
      this.Pill('30d', $r('app.string.days_30'))
      this.Pill(Constants.PERIOD_ALL, $r('app.string.all'))
    }
  }

  @Builder
  Pill(period: string, label: Resource) {
    Text(label)
      .fontSize(12)
      .padding({ left: 12, right: 12, top: 5, bottom: 5 })
      .borderRadius(14)
      .backgroundColor(this.vm.period === period ? $r('app.color.accent') : $r('app.color.divider'))
      .fontColor(this.vm.period === period ? Color.White : $r('app.color.text_secondary'))
      .onClick(() => {
        this.vm.setPeriod(period);
        this.refresh();
      })
  }

  @Builder
  KpiCards() {
    Grid() {
      GridItem() { StatCard({ title: $r('app.string.input'), value: formatTokens(this.vm.totals.totalInputTokens), sub: '', accent: false }) }
      GridItem() { StatCard({ title: $r('app.string.output'), value: formatTokens(this.vm.totals.totalOutputTokens), sub: '', accent: false }) }
      GridItem() { StatCard({ title: $r('app.string.reasoning'), value: formatTokens(this.vm.totals.totalReasoningTokens), sub: '', accent: false }) }
      GridItem() { StatCard({ title: $r('app.string.cost'), value: formatCost(this.vm.totals.totalCostUsd, this.currency, this.usdCny), sub: '', accent: true }) }
    }
    .columnsTemplate('1fr 1fr')
    .rowsGap(10)
    .columnsGap(10)
    .width('100%')
  }

  @Builder
  TokenDetail() {
    Column({ space: 8 }) {
      Text($r('app.string.token_breakdown')).fontSize(15).fontWeight(FontWeight.Bold)
      Grid() {
        GridItem() { StatCard({ title: $r('app.string.input'), value: formatTokens(this.vm.totals.uncachedInputTokens), sub: '', accent: false }) }
        GridItem() { StatCard({ title: $r('app.string.output'), value: formatTokens(this.vm.totals.totalOutputTokens), sub: '', accent: false }) }
        GridItem() { StatCard({ title: $r('app.string.reasoning'), value: formatTokens(this.vm.totals.totalReasoningTokens), sub: '', accent: false }) }
        GridItem() { StatCard({ title: $r('app.string.cache_read'), value: formatTokens(this.vm.totals.cacheHitTokens), sub: '', accent: false }) }
        GridItem() { StatCard({ title: $r('app.string.cache_write'), value: formatTokens(this.vm.totals.cacheWriteTokens), sub: '', accent: false }) }
        GridItem() { StatCard({ title: $r('app.string.ov_sessions'), value: `${this.vm.totals.sessionCount}`, sub: '', accent: false }) }
      }
      .columnsTemplate('1fr 1fr')
      .rowsGap(10)
      .columnsGap(10)
      .width('100%')
    }
    .width('100%')
    .padding(12)
    .borderRadius(12)
    .backgroundColor($r('app.color.bg_card'))
  }

  @Builder
  ModelRank() {
    Column({ space: 8 }) {
      Row() {
        Text($r('app.string.model_usage')).fontSize(15).fontWeight(FontWeight.Bold)
        Blank()
        Row({ space: 6 }) {
          this.DimPill('input', $r('app.string.input'))
          this.DimPill('output', $r('app.string.output'))
          this.DimPill('cost', $r('app.string.cost'))
        }
      }
      .width('100%')

      Row() {
        DonutChart({
          items: this.donutItems(),
          centerTitle: '总Token',
          centerValue: formatTokens(this.vm.totals.totalInputTokens + this.vm.totals.totalOutputTokens + this.vm.totals.totalReasoningTokens),
        })
          .key(this.chartVersion)
          .width(160)
          .height(160)

        Column({ space: 6 }) {
          ForEach(this.vm.models.slice(0, 6), (m: ModelStat) => {
            Row({ space: 6 }) {
              Text('●').fontSize(10).fontColor(this.modelColor(m.model))
              Text(m.model).fontSize(12).fontColor($r('app.color.text_primary')).layoutWeight(1).maxLines(1)
              Text(formatTokens(this.dimValue(m, this.vm.dim))).fontSize(12).fontColor($r('app.color.text_secondary'))
            }
            .width('100%')
          }, (m: ModelStat) => m.model)
        }
        .layoutWeight(1)
      }
      .width('100%')
    }
    .width('100%')
    .padding(12)
    .borderRadius(12)
    .backgroundColor($r('app.color.bg_card'))
  }

  private modelColor(model: string): string {
    const palette = ['#2F6FED', '#34A853', '#FBBC04', '#EA4335', '#9334E6', '#00ACC1'];
    const idx = this.vm.models.findIndex((m) => m.model === model);
    return palette[idx >= 0 ? idx % palette.length : 0];
  }

  @Builder
  DimPill(dim: string, label: Resource) {
    Text(label)
      .fontSize(11)
      .padding({ left: 8, right: 8, top: 3, bottom: 3 })
      .borderRadius(10)
      .backgroundColor(this.vm.dim === dim ? $r('app.color.accent') : $r('app.color.divider'))
      .fontColor(this.vm.dim === dim ? Color.White : $r('app.color.text_secondary'))
      .onClick(() => {
        this.vm.setDim(dim as 'input' | 'output' | 'cost');
        this.chartVersion++;
      })
  }

  @Builder
  TrendCard() {
    Column({ space: 8 }) {
      Row() {
        Text($r('app.string.usage_trend')).fontSize(15).fontWeight(FontWeight.Bold)
        Blank()
      }
      .width('100%')
      LineChart({
        series: this.trendSeries(),
        labels: this.trendLabels(),
      })
        .key(this.chartVersion)
        .width('100%')
        .height(240)
    }
    .width('100%')
    .padding(12)
    .borderRadius(12)
    .backgroundColor($r('app.color.bg_card'))
  }

  build() {
    Scroll() {
      Column({ space: 12 }) {
        Row() {
          Text($r('app.string.stats_title')).fontSize(18).fontWeight(FontWeight.Bold)
          Blank()
          this.RangePills()
        }
        .width('100%')

        this.KpiCards()
        this.TokenDetail()
        this.ModelRank()
        this.TrendCard()
      }
      .padding(12)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.bg_page'))
    .scrollBar(BarState.Off)
  }
}
```

- [ ] **Step 3: 挂载到 `Index.ets` 并验证**

`MainArea()` 中 `this.currentTab === 1` 分支替换为 `StatsPage()`；文件头 `import { StatsPage } from './StatsPage';`。`Make Project` + 运行，Mock 下统计页应显示 4 KPI、Token 构成、模型环形图+排行、三线趋势。

- [ ] **Step 4: Commit（非 git 仓库则跳过）**

```bash
git add entry/src/main/ets/pages
git commit -m "feat: stats page with kpi, model donut, trend line"
```

---

### Task 10: 记录页（会话用量 + 使用记录）

**Files:**
- Create: `entry/src/main/ets/pages/RecordsPage.ets`
- Create: `entry/src/main/ets/pages/RecordsViewModel.ets`
- Create: `entry/src/main/ets/components/ui/Pager.ets`
- Modify: `entry/src/main/ets/pages/Index.ets`

**Interfaces:**
- Consumes: `DataProvider.getAggregator()`、`TimeUtil`、`Formatter`、`SettingsStore`（货币）。
- Produces:
  - `class RecordsViewModel { sessions: SessionStat[]; sessionTotal; sessionPage; records: RecordRow[]; recordTotal; recordPage; models: string[]; selectedModel: string; async loadSessions(page); async loadRecords(page); setModel(m); }`

- [ ] **Step 1: 实现 `Pager.ets`**

```typescript
// entry/src/main/ets/components/ui/Pager.ets
@Component
export struct Pager {
  @Prop page: number = 1;
  @Prop totalPages: number = 1;
  @Prop total: number = 0;
  onPrev: () => void = () => {};
  onNext: () => void = () => {};

  build() {
    Row({ space: 10 }) {
      Button($r('app.string.prev'))
        .fontSize(12)
        .height(30)
        .enabled(this.page > 1)
        .onClick(() => this.onPrev())
      Text(`${this.page} / ${Math.max(1, this.totalPages)}`)
        .fontSize(12)
        .fontColor($r('app.color.text_muted'))
      Button($r('app.string.next'))
        .fontSize(12)
        .height(30)
        .enabled(this.page < this.totalPages)
        .onClick(() => this.onNext())
    }
    .width('100%')
    .justifyContent(FlexAlign.Center)
  }
}
```

- [ ] **Step 2: 实现 `RecordsViewModel.ets`**

```typescript
// entry/src/main/ets/pages/RecordsViewModel.ets
import { DataProvider } from '../data/DataProvider';
import type { SessionStat, RecordRow } from '../model/Stats';

const SESSION_PAGE_SIZE = 10;
const RECORD_PAGE_SIZE = 50;

/** 记录页：会话聚合 + 请求明细，各自分页。 */
export class RecordsViewModel {
  sessions: SessionStat[] = [];
  sessionTotal = 0;
  sessionPage = 1;

  records: RecordRow[] = [];
  recordTotal = 0;
  recordPage = 1;

  models: string[] = [];
  selectedModel = '';

  async loadSessions(page: number): Promise<void> {
    this.sessionPage = Math.max(1, page);
    const agg = DataProvider.getAggregator();
    const [rows, total] = await agg.sessionStatsPage(this.sessionPage, SESSION_PAGE_SIZE, null);
    this.sessions = rows;
    this.sessionTotal = total;
  }

  async loadRecords(page: number): Promise<void> {
    this.recordPage = Math.max(1, page);
    const agg = DataProvider.getAggregator();
    const [rows, total] = await agg.usageRecordsPage(this.recordPage, RECORD_PAGE_SIZE, this.selectedModel === '' ? null : this.selectedModel, null);
    this.records = rows;
    this.recordTotal = total;
    const models = await agg.listModels();
    this.models = models;
  }

  async setModel(m: string): Promise<void> {
    this.selectedModel = m;
    await this.loadRecords(1);
  }
}
```

> 说明：`usageRecordsPage` 的 model 参数类型为 `string | null`；空串传 null。`sessionStatsPage` 签名 `(page, pageSize, days)`，days 传 null。

- [ ] **Step 3: 实现 `RecordsPage.ets`**

```typescript
// entry/src/main/ets/pages/RecordsPage.ets
import { RecordsViewModel } from './RecordsViewModel';
import { Pager } from '../components/ui/Pager';
import { formatTokens, formatCost } from '../common/utils/Formatter';
import { formatDateTime, parseIso } from '../common/utils/TimeUtil';
import { SettingsStore } from '../data/SettingsStore';
import { OpenCodeApi } from '../network/OpenCodeApi';
import { Constants } from '../common/constants/Constants';
import type { SessionStat, RecordRow } from '../model/Stats';

@Component
export struct RecordsPage {
  @State vm: RecordsViewModel = new RecordsViewModel();
  @State currency: string = 'CNY';
  @State usdCny: number = Constants.DEFAULT_USD_CNY;

  aboutToAppear(): void {
    this.reload();
    this.initCurrency();
  }

  private async reload(): Promise<void> {
    await this.vm.loadSessions(1);
    await this.vm.loadRecords(1);
  }

  private async initCurrency(): Promise<void> {
    this.currency = await SettingsStore.getCurrency();
    this.usdCny = await OpenCodeApi.fetchUsdCny();
  }

  @Builder
  SessionsCard() {
    Column({ space: 8 }) {
      Row() {
        Text($r('app.string.session_usage')).fontSize(15).fontWeight(FontWeight.Bold)
        Blank()
        Text(`${this.vm.sessionTotal}`).fontSize(11).fontColor($r('app.color.text_muted'))
      }
      .width('100%')

      Column() {
        Row() {
          Text($r('app.string.col_session')).fontSize(11).layoutWeight(2).fontColor($r('app.color.text_muted'))
          Text($r('app.string.col_input')).fontSize(11).layoutWeight(1).fontColor($r('app.color.text_muted')).textAlign(TextAlign.End)
          Text($r('app.string.col_output')).fontSize(11).layoutWeight(1).fontColor($r('app.color.text_muted')).textAlign(TextAlign.End)
          Text($r('app.string.col_requests')).fontSize(11).layoutWeight(1).fontColor($r('app.color.text_muted')).textAlign(TextAlign.End)
          Text($r('app.string.col_cost')).fontSize(11).layoutWeight(1).fontColor($r('app.color.text_muted')).textAlign(TextAlign.End)
        }
        .width('100%')
        .padding({ top: 6, bottom: 6 })

        ForEach(this.vm.sessions, (s: SessionStat) => {
          Row() {
            Text(this.shortSession(s.sessionId)).fontSize(12).layoutWeight(2).fontColor($r('app.color.text_primary')).maxLines(1)
            Text(formatTokens(s.totalInputTokens)).fontSize(12).layoutWeight(1).textAlign(TextAlign.End).fontColor($r('app.color.text_secondary'))
            Text(formatTokens(s.totalOutputTokens)).fontSize(12).layoutWeight(1).textAlign(TextAlign.End).fontColor($r('app.color.text_secondary'))
            Text(`${s.requestCount}`).fontSize(12).layoutWeight(1).textAlign(TextAlign.End).fontColor($r('app.color.text_secondary'))
            Text(formatCost(s.totalCostUsd, this.currency, this.usdCny)).fontSize(12).layoutWeight(1).textAlign(TextAlign.End).fontColor($r('app.color.text_secondary'))
          }
          .width('100%')
          .padding({ top: 5, bottom: 5 })
        }, (s: SessionStat) => s.sessionId)
      }
      .width('100%')

      Pager({
        page: this.vm.sessionPage,
        totalPages: Math.ceil(this.vm.sessionTotal / 10),
        onPrev: () => { this.vm.loadSessions(this.vm.sessionPage - 1); },
        onNext: () => { this.vm.loadSessions(this.vm.sessionPage + 1); },
      })
    }
    .width('100%')
    .padding(12)
    .borderRadius(12)
    .backgroundColor($r('app.color.bg_card'))
  }

  private shortSession(id: string): string {
    if (id === '') { return '未归属'; }
    return id.length > 12 ? `…${id.substring(id.length - 12)}` : id;
  }

  @Builder
  RecordsCard() {
    Column({ space: 8 }) {
      Row() {
        Text($r('app.string.usage_records')).fontSize(15).fontWeight(FontWeight.Bold)
        Blank()
        Select(this.vm.models.length > 0 ? [''].concat(this.vm.models) : [''])
          .selected(this.vm.models.indexOf(this.vm.selectedModel) >= 0 ? this.vm.models.indexOf(this.vm.selectedModel) + 1 : 0)
          .value(this.vm.selectedModel === '' ? $r('app.string.all_models') : this.vm.selectedModel)
          .fontSize(12)
          .width(140)
          .onSelect((index: number, text: string) => {
            const target = index === 0 ? '' : this.vm.models[index - 1];
            this.vm.setModel(target);
          })
        Text(`${this.vm.recordTotal}`).fontSize(11).fontColor($r('app.color.text_muted'))
      }
      .width('100%')

      Column() {
        Row() {
          Text($r('app.string.col_time')).fontSize(11).layoutWeight(2).fontColor($r('app.color.text_muted'))
          Text($r('app.string.col_model')).fontSize(11).layoutWeight(2).fontColor($r('app.color.text_muted'))
          Text($r('app.string.col_input')).fontSize(11).layoutWeight(1).fontColor($r('app.color.text_muted')).textAlign(TextAlign.End)
          Text($r('app.string.col_output')).fontSize(11).layoutWeight(1).fontColor($r('app.color.text_muted')).textAlign(TextAlign.End)
          Text($r('app.string.col_fee')).fontSize(11).layoutWeight(1).fontColor($r('app.color.text_muted')).textAlign(TextAlign.End)
        }
        .width('100%')
        .padding({ top: 6, bottom: 6 })

        ForEach(this.vm.records, (r: RecordRow) => {
          Row() {
            Text(formatDateTime(parseIso(r.createdAt))).fontSize(11).layoutWeight(2).fontColor($r('app.color.text_secondary')).maxLines(1)
            Text(r.model).fontSize(11).layoutWeight(2).fontColor($r('app.color.text_primary')).maxLines(1)
            Text(formatTokens(r.inputTokens)).fontSize(11).layoutWeight(1).textAlign(TextAlign.End).fontColor($r('app.color.text_secondary'))
            Text(formatTokens(r.outputTokens)).fontSize(11).layoutWeight(1).textAlign(TextAlign.End).fontColor($r('app.color.text_secondary'))
            Text(formatCost(r.costUsd, this.currency, this.usdCny)).fontSize(11).layoutWeight(1).textAlign(TextAlign.End).fontColor($r('app.color.text_secondary'))
          }
          .width('100%')
          .padding({ top: 4, bottom: 4 })
        }, (r: RecordRow) => r.usgId)
      }
      .width('100%')

      Pager({
        page: this.vm.recordPage,
        totalPages: Math.ceil(this.vm.recordTotal / 50),
        onPrev: () => { this.vm.loadRecords(this.vm.recordPage - 1); },
        onNext: () => { this.vm.loadRecords(this.vm.recordPage + 1); },
      })
    }
    .width('100%')
    .padding(12)
    .borderRadius(12)
    .backgroundColor($r('app.color.bg_card'))
  }

  build() {
    Scroll() {
      Column({ space: 12 }) {
        Row() {
          Text($r('app.string.records_page')).fontSize(18).fontWeight(FontWeight.Bold)
          Blank()
        }
        .width('100%')

        this.SessionsCard()
        this.RecordsCard()
      }
      .padding(12)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.bg_page'))
    .scrollBar(BarState.Off)
  }
}
```

> 说明：`Select` 组件选项数组需 `string[]`；首项为「全部模型」。`onSelect` 里 `index-1` 对应 models 下标。若 ArkTS 对 `Select` 的 `options` 泛型有要求（`SelectOption[]`），改为 `[{ value: '' }, ...]` 并改用 `value` 定位。

- [ ] **Step 4: 挂载到 `Index.ets` 并验证**

`MainArea()` 中 `this.currentTab === 2` 替换为 `RecordsPage()`；`import { RecordsPage } from './RecordsPage';`。`Make Project` + 运行，Mock 下记录页显示会话表 + 记录表 + 分页。

> 注：Mock 的 `sessionStatsPage`/`usageRecordsPage` 目前返回空（Task 6 Step 2 说明）；如需 Mock 可看数据，请在 `MockRepository` 内补内存分页实现（过滤 + slice），代码约 20 行，按 `calcModels` 同风格补充即可。

- [ ] **Step 5: Commit（非 git 仓库则跳过）**

```bash
git add entry/src/main/ets/pages entry/src/main/ets/components/ui
git commit -m "feat: records page with sessions and paginated details"
```

---

### Task 11: 设置页 + 关于页

**Files:**
- Create: `entry/src/main/ets/pages/SettingsPage.ets`
- Create: `entry/src/main/ets/pages/AboutPage.ets`
- Create: `entry/src/main/ets/components/ui/SettingRow.ets`（通用设置行）
- Modify: `entry/src/main/ets/pages/Index.ets`
- Modify: `entry/src/main/ets/data/SettingsStore.ets`（补 `save(payload)` 已存在，无需改；加 `clearAll?` 不需要）

**Interfaces:**
- Consumes: `SettingsStore`、`DataProvider`、`router`、`SyncManager`（进度回调）。
- Produces:
  - `struct SettingRow { @Prop title; @Prop desc; }`（内容槽位用 `@BuilderParam`）
  - `page SettingsPage`：账户/自动同步/外观/数据/更新 各卡片
  - `page AboutPage`：简介/功能/链接/致谢

- [ ] **Step 1: 实现 `SettingRow.ets`**

```typescript
// entry/src/main/ets/components/ui/SettingRow.ets
@Component
export struct SettingRow {
  @Prop title: string = '';
  @Prop desc: string = '';
  @BuilderParam content: () => void = () => {};

  build() {
    Row({ space: 10 }) {
      Column({ space: 2 }) {
        Text(this.title).fontSize(14).fontColor($r('app.color.text_primary'))
        if (this.desc !== '') {
          Text(this.desc).fontSize(11).fontColor($r('app.color.text_muted'))
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      this.content()
    }
    .width('100%')
    .padding({ top: 10, bottom: 10 })
  }
}
```

- [ ] **Step 2: 实现 `SettingsPage.ets`**

```typescript
// entry/src/main/ets/pages/SettingsPage.ets
import { router } from '@kit.ArkUI';
import { SettingsStore, SettingsKeys, AppSettings } from '../data/SettingsStore';
import { DataProvider } from '../data/DataProvider';
import { SyncManager, SyncProgress } from '../network/SyncManager';
import type { SyncState } from '../model/UsageRecord';
import { SettingRow } from '../components/ui/SettingRow';
import { formatDateTime, parseIso } from '../common/utils/TimeUtil';
import { Constants } from '../common/constants/Constants';
import { promptAction } from '@kit.ArkUI';

@Component
export struct SettingsPage {
  @State settings: AppSettings = {
    syncIntervalSec: 300, windowDays: 60, autoSync: true, theme: 'light', currency: 'CNY', language: 'zh',
  };
  @State loggedIn: boolean = false;
  @State workspace: string = '';
  @State syncState: SyncState = { lastSyncAt: '', lastSyncStatus: '', lastSyncError: '', lastInsertedCount: 0, deepestPageFetched: -1, totalRecords: 0, oldestRecordAt: '', newestRecordAt: '' };
  @State syncing: boolean = false;
  @State syncProgressMsg: string = '';

  aboutToAppear(): void {
    this.load();
    const mgr = DataProvider.getSyncManager();
    mgr.onProgress = (p: SyncProgress) => {
      this.syncing = p.running;
      this.syncProgressMsg = p.message;
    };
  }

  private async load(): Promise<void> {
    this.settings = await SettingsStore.getAll();
    const token = await DataProvider.getStore().getToken();
    this.loggedIn = token.trim() !== '';
    this.workspace = await DataProvider.getStore().getWorkspaceHint();
    this.syncState = await DataProvider.getStore().getSyncState();
  }

  @Builder
  Card(title: Resource, children: () => void) {
    Column({ space: 2 }) {
      Text(title).fontSize(15).fontWeight(FontWeight.Bold).width('100%')
      children()
    }
    .width('100%')
    .padding(12)
    .borderRadius(12)
    .backgroundColor($r('app.color.bg_card'))
  }

  @Builder
  PillRow(options: Array<{ value: string; label: string }>, current: string, onPick: (v: string) => void) {
    Row({ space: 6 }) {
      ForEach(options, (opt: { value: string; label: string }) => {
        Text(opt.label)
          .fontSize(11)
          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
          .borderRadius(10)
          .backgroundColor(current === opt.value ? $r('app.color.accent') : $r('app.color.divider'))
          .fontColor(current === opt.value ? Color.White : $r('app.color.text_secondary'))
          .onClick(() => onPick(opt.value))
      }, (opt: { value: string; label: string }) => opt.value)
    }
  }

  build() {
    Scroll() {
      Column({ space: 12 }) {
        Row() {
          Text($r('app.string.settings_title')).fontSize(18).fontWeight(FontWeight.Bold)
          Blank()
        }
        .width('100%')

        // 账户
        this.Card($r('app.string.set_account')) {
          SettingRow({ title: $r('app.string.set_login_state'), desc: this.loggedIn ? $r('app.string.logged_in') : $r('app.string.not_logged_in') }) {}
          SettingRow({ title: $r('app.string.set_workspace'), desc: this.workspace }) {}
          SettingRow({ title: $r('app.string.set_login_method'), desc: $r('app.string.login_method_desc') }) {
            Button($r('app.string.relogin')).fontSize(12).height(30).onClick(() => {
              router.pushUrl({ url: 'pages/Login' });
            })
          }
          SettingRow({ title: $r('app.string.logout'), desc: $r('app.string.logout_desc') }) {
            Button($r('app.string.logout')).fontSize(12).height(30).backgroundColor($r('app.color.danger'))
              .onClick(() => this.confirmLogout())
          }
        }

        // 自动同步
        this.Card($r('app.string.set_auto_sync')) {
          SettingRow({ title: $r('app.string.auto_sync'), desc: $r('app.string.auto_sync_desc') }) {
            Toggle({ type: ToggleType.Switch, isOn: this.settings.autoSync })
              .onChange((v: boolean) => {
                this.settings.autoSync = v;
                SettingsStore.save(this.settings);
              })
          }
          SettingRow({ title: $r('app.string.sync_interval'), desc: $r('app.string.sync_interval_desc') }) {
            this.PillRow(
              [
                { value: '60', label: $r('app.string.min_1') },
                { value: '300', label: $r('app.string.min_5') },
                { value: '900', label: $r('app.string.min_15') },
                { value: '1800', label: $r('app.string.min_30') },
              ],
              `${this.settings.syncIntervalSec}`,
              (v: string) => { this.settings.syncIntervalSec = Number(v); SettingsStore.save(this.settings); })
          }
          SettingRow({ title: $r('app.string.sync_range'), desc: $r('app.string.sync_range_desc') }) {
            this.PillRow(
              [
                { value: '30', label: $r('app.string.days_30short') },
                { value: '60', label: $r('app.string.days_60') },
                { value: '90', label: $r('app.string.days_90') },
                { value: '180', label: $r('app.string.days_180') },
                { value: 'all', label: $r('app.string.all') },
              ],
              this.settings.windowDays === null ? 'all' : `${this.settings.windowDays}`,
              (v: string) => { this.settings.windowDays = v === 'all' ? null : Number(v); SettingsStore.save(this.settings); })
          }
          SettingRow({ title: $r('app.string.full_sync'), desc: this.syncProgressMsg !== '' ? this.syncProgressMsg : $r('app.string.full_sync_desc') }) {
            Button(this.syncing ? $r('app.string.syncing') : $r('app.string.start_full_sync'))
              .fontSize(12).height(30)
              .enabled(!this.syncing)
              .onClick(() => { DataProvider.getSyncManager().sync('full'); })
          }
        }

        // 外观
        this.Card($r('app.string.set_appearance')) {
          SettingRow({ title: $r('app.string.theme'), desc: $r('app.string.theme_desc') }) {
            this.PillRow(
              [{ value: 'light', label: $r('app.string.light') }, { value: 'dark', label: $r('app.string.dark') }],
              this.settings.theme,
              (v: string) => { this.settings.theme = v; SettingsStore.save(this.settings); this.applyTheme(v); })
          }
          SettingRow({ title: $r('app.string.currency'), desc: $r('app.string.currency_desc') }) {
            this.PillRow(
              [{ value: 'CNY', label: '¥ CNY' }, { value: 'USD', label: '$ USD' }],
              this.settings.currency,
              (v: string) => { this.settings.currency = v; SettingsStore.save(this.settings); })
          }
          SettingRow({ title: $r('app.string.language'), desc: $r('app.string.language_desc') }) {
            this.PillRow(
              [{ value: 'zh', label: '中文' }, { value: 'en', label: 'English' }],
              this.settings.language,
              (v: string) => { this.settings.language = v; SettingsStore.save(this.settings); promptAction.showToast({ message: '重启后生效' }); })
          }
        }

        // 数据
        this.Card($r('app.string.set_data')) {
          SettingRow({ title: $r('app.string.data_dir'), desc: Constants.DB_NAME }) {}
          SettingRow({ title: $r('app.string.sync_info'), desc: this.syncInfoDesc() }) {}
        }

        // 更新
        this.Card($r('app.string.set_update')) {
          SettingRow({ title: $r('app.string.current_version'), desc: '1.0.0' }) {}
          SettingRow({ title: $r('app.string.check_update'), desc: $r('app.string.check_update_desc') }) {
            Button($r('app.string.check_update_btn')).fontSize(12).height(30).onClick(() => {
              promptAction.openUrl('https://github.com/yphyphyph/opencode-go-gauge/releases');
            })
          }
        }
      }
      .padding(12)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.bg_page'))
    .scrollBar(BarState.Off)
  }

  private syncInfoDesc(): string {
    const last = this.syncState.lastSyncAt !== '' ? formatDateTime(parseIso(this.syncState.lastSyncAt)) : '从未';
    return `最近: ${last} · 总数: ${this.syncState.totalRecords}`;
  }

  private confirmLogout(): void {
    AlertDialog.show({
      title: $r('app.string.confirm_title'),
      message: $r('app.string.logout_confirm_msg'),
      primaryButton: {
        value: $r('app.string.cancel'), action: () => {},
      },
      secondaryButton: {
        value: $r('app.string.ok'), action: async () => {
          await DataProvider.getStore().clearAccount();
          this.load();
        },
      },
    });
  }

  private applyTheme(mode: string): void {
    const ctx = this.getUIContext();
    ctx.setColorMode(mode === 'dark' ? 1 : 0);
  }
}
```

> 说明：`setColorMode` 用 `UIContext.setColorMode(ConfigurationConstant.ColorMode)`。`0`=light，`1`=dark（`COLOR_MODE_LIGHT`/`COLOR_MODE_DARK`）。`getUIContext()` 在 `@Component` 内可用。`PillRow` 的 `options` 中 `label` 为 `ResourceStr` 类型时 `ForEach` 的 key 需字符串，这里 `value` 作 key。

- [ ] **Step 3: 实现 `AboutPage.ets`**

```typescript
// entry/src/main/ets/pages/AboutPage.ets
@Component
export struct AboutPage {
  build() {
    Scroll() {
      Column({ space: 12 }) {
        Row() {
          Text($r('app.string.about_title')).fontSize(18).fontWeight(FontWeight.Bold)
          Blank()
        }
        .width('100%')

        Column({ space: 8 }) {
          Text($r('app.string.about_intro')).fontSize(15).fontWeight(FontWeight.Bold).width('100%')
          Text($r('app.string.intro_text')).fontSize(13).fontColor($r('app.color.text_secondary')).lineHeight(20)
        }
        .width('100%')
        .padding(12)
        .borderRadius(12)
        .backgroundColor($r('app.color.bg_card'))

        Column({ space: 8 }) {
          Text($r('app.string.about_features')).fontSize(15).fontWeight(FontWeight.Bold).width('100%')
          Text(`· ${$r('app.string.feat_1')}`).fontSize(13).fontColor($r('app.color.text_secondary'))
          Text(`· ${$r('app.string.feat_2')}`).fontSize(13).fontColor($r('app.color.text_secondary'))
          Text(`· ${$r('app.string.feat_3')}`).fontSize(13).fontColor($r('app.color.text_secondary'))
          Text(`· ${$r('app.string.feat_4')}`).fontSize(13).fontColor($r('app.color.text_secondary'))
          Text(`· ${$r('app.string.feat_5')}`).fontSize(13).fontColor($r('app.color.text_secondary'))
        }
        .width('100%')
        .padding(12)
        .borderRadius(12)
        .backgroundColor($r('app.color.bg_card'))

        Column({ space: 8 }) {
          Text($r('app.string.about_links')).fontSize(15).fontWeight(FontWeight.Bold).width('100%')
          Text('GitHub: github.com/yphyphyph/opencode-go-gauge')
            .fontSize(13)
            .fontColor($r('app.color.accent'))
            .onClick(() => {
              promptAction.openUrl('https://github.com/yphyphyph/opencode-go-gauge');
            })
        }
        .width('100%')
        .padding(12)
        .borderRadius(12)
        .backgroundColor($r('app.color.bg_card'))

        Text($r('app.string.page_foot'))
          .fontSize(11)
          .fontColor($r('app.color.text_muted'))
          .margin({ top: 8 })
      }
      .padding(12)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.bg_page'))
    .scrollBar(BarState.Off)
  }
}
```

> 说明：文件头补 `import { promptAction } from '@kit.ArkUI';`。

- [ ] **Step 4: 挂载到 `Index.ets` 并验证**

`MainArea()` 中 `currentTab === 3` → `SettingsPage()`，`currentTab === 4` → `AboutPage()`；文件头补两个 import。`Make Project` + 运行：设置页各卡片可切换、退出登录弹确认、重新登录跳转 Login；关于页展示简介/功能/链接。

- [ ] **Step 5: Commit（非 git 仓库则跳过）**

```bash
git add entry/src/main/ets/pages entry/src/main/ets/components/ui
git commit -m "feat: settings and about pages"
```

---

### Task 12: 响应式收尾 + 主题/语言联动 + 全量测试

**Files:**
- Modify: `entry/src/main/ets/pages/Index.ets`（平板宽度断点细化：内容区两栏）
- Modify: `entry/src/main/ets/pages/DashboardPage.ets` / `StatsPage.ets`（宽屏两栏布局）
- Modify: `entry/src/main/ets/common/constants/Constants.ets`（发布前 `USE_MOCK_DATA = false` 注释说明）
- Test: 汇总运行全部单测；补 `entry/src/test` 用例覆盖汇率与费用换算

**Interfaces:**
- Consumes: 全部页面。
- Produces: 无新接口。

- [ ] **Step 1: 平板两栏布局（DashboardPage / StatsPage）**

在 `DashboardPage` 与 `StatsPage` 增加 `@State wide: boolean`，`aboutToAppear` 里 `this.wide = display.getDefaultDisplaySync().width >= 840;`，`build` 中当 `wide` 时把「概览 6 卡」与「今日趋势」/「模型排行」与「趋势图」排成 `Row` 双列：

```typescript
// DashboardPage.build 内（宽屏时）示例：
// if (this.wide) {
//   Row({ space: 12 }) {
//     this.OverviewGrid().layoutWeight(1)
//     this.TodayTrendCard().layoutWeight(1)
//   }.width('100%')
// } else {
//   this.OverviewGrid()
//   this.TodayTrendCard()
// }
```

> 说明：此为方向性代码；具体两栏分组的取舍（概览+趋势、配额独占行等）以实现时视觉为准，保持与参考项目「主页宽屏」一致即可。

- [ ] **Step 2: 主题联动检查**

确认 `SettingsPage.applyTheme` 用 `UIContext.setColorMode` 切换后，所有 `$r('app.color.*')` 自动走 `dark/element/color.json`；图表组件颜色若用字面色值需随主题重绘——在 `Index` 顶部加「主题变更 → 重建子页」：给 `MainArea` 内容套 `.key(this.themeVersion)`，`applyTheme` 时 `this.themeVersion++`。

- [ ] **Step 3: 补费用/汇率单测**

在 `Formatter.test.ets` 追加：

```typescript
    it('formatCost_zero', 0, () => {
      expect(formatCost(0, 'CNY', 7.2)).assertEqual('¥0.00');
    });
    it('formatCost_cny_rate', 0, () => {
      expect(formatCost(1, 'CNY', 7.25)).assertEqual('¥7.25');
    });
```

- [ ] **Step 4: 全量测试**

DevEco Studio：运行 `src/test` 全部本地单测 + `ohosTest`（设备）Repository 用例。预期：全部通过。

- [ ] **Step 5: 发布前检查**

将 `Constants.USE_MOCK_DATA` 置 `false`，确认真实数据链路（登录 → 同步 → 各页）正常；重新打开 DevEco 同步构建。

- [ ] **Step 6: Commit（非 git 仓库则跳过）**

```bash
git add entry/src/main/ets
git commit -m "feat: responsive layouts, theme wiring, final tests"
```

---

## Self-Review 记录

- **Spec 覆盖**：配额（Task 8）✓、概览（Task 8）✓、今日趋势（Task 8）✓、Token 构成（Task 9）✓、模型环形图+排行（Task 9）✓、三线趋势（Task 9）✓、会话历史（Task 10）✓、使用记录+模型筛选（Task 10）✓、WebView 登录（Task 6）✓、自动同步（Task 5 + Task 11 设置）✓、双主题（Task 11 + Task 12）✓、中英双语（Task 1 资源）✓、响应式（Task 6 壳 + Task 12 两栏）✓。
- **占位扫描**：Task 3 Step 5 的文件是「先占位后完整替换」的写法，已注明以最终版本为准；Task 6 MockRepository 的 `sessionStatsPage`/`usageRecordsPage` 返回空并附补齐说明；Task 7 ChartTheme 在 Step 1 即声明删除。均为显式说明，非静默 TBD。
- **类型一致**：`UsageStore` 统一为异步签名（Task 3 Step 9 覆盖）；`UsageAggregator` 移入 `model/Stats.ets`（Task 8 Step 3）；`sessionStatsPage`/`usageRecordsPage` 返回 `Promise<[T[], number]>`（元组）在 Task 10 ViewModel 中按 `const [rows, total]` 解构，一致。
- **测试执行**：本目录无 hvigorw，全部测试/构建经 DevEco Studio 执行；已在 Global Constraints 说明。

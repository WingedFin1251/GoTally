# OpenCode Go 用量面板 — HarmonyOS 移植设计文档

日期：2026-08-16
状态：已批准（用户确认设计方向）
参考项目：`D:\Users\Downloads\opencode-go-gauge-main`（GoGauge，Python + pywebview + SQLite + Chart.js）

## 1. 目标

将 GoGauge（OpenCode Go 用量统计仪表盘）完整移植为原生 HarmonyOS 应用，运行于**手机 + 平板**，保持全部功能：配额监控、用量概览、今日趋势、用量统计、会话历史、使用记录、内置 WebView 登录、自动同步、双主题、中英双语。

## 2. 关键决策（已与用户确认）

| 决策项 | 选择 |
|---|---|
| 功能范围 | 完整移植（全部页面/模块） |
| 目标设备 | 手机 + 平板（响应式布局） |
| 图表方案 | 自绘 Canvas（无三方依赖） |
| 实现方式 | 原生 ArkTS，单 entry 模块分包 |

## 3. 工程结构

单 entry 模块，按职责分包。复用参考项目 `db.py` / `opencode_api.py` / `server.py` / 前端 `app.js` 的逻辑。

```
entry/src/main/ets/
├── entryability/EntryAbility.ets
├── common/
│   ├── constants/Constants.ets        # API 地址、server id、Cookie 常量
│   ├── utils/Formatter.ets            # token/费用/时间格式化（移植自 app.js）
│   └── utils/TimeUtil.ets             # UTC/本地时间处理、相对时间
├── model/                             # UsageRecord / QuotaWindow / Stats 接口定义
├── data/
│   ├── RdbHelper.ets                  # RDB 建库建表（对齐 db.py schema）
│   ├── UsageRepository.ets            # 记录增删查 + 聚合查询（移植 db.py 全部查询）
│   └── SettingsStore.ets              # Preferences 存储设置/token/工作区
├── network/
│   ├── OpenCodeApi.ets                # _server 调用 + 配额 HTML 解析（移植 opencode_api.py）
│   └── SyncManager.ets                # 增量/全量同步状态机（移植 server.py sync_usage）
├── auth/LoginPage.ets                 # Web 组件登录页 + cookie 捕获
├── pages/                             # Index.ets 壳 + 各功能页
│   ├── Index.ets                      # 导航壳（手机 Tab / 平板侧栏）
│   ├── DashboardPage.ets              # 首页：配额+概览+今日趋势
│   ├── StatsPage.ets                  # 用量统计
│   ├── RecordsPage.ets                # 会话用量 + 使用记录
│   ├── SettingsPage.ets               # 设置
│   └── AboutPage.ets                  # 关于
├── components/
│   ├── charts/BarChart.ets            # Canvas 柱状图
│   ├── charts/DonutChart.ets          # Canvas 环形图
│   ├── charts/LineChart.ets           # Canvas 多线图
│   └── ui/ StatCard / QuotaProgress / TokenDetail / 分页器 / 确认弹窗 / Toast
└── resources/
    ├── base/element/string.json       # 中文文案
    ├── en_US/element/string.json      # 英文文案
    ├── base/element/color.json        # 亮色色板
    └── dark/element/color.json        # 深色色板
```

## 4. 数据层（RDB + Preferences）

### 4.1 RDB 表结构（对齐 SQLite schema）

- **usage_records**：主键 `usg_id`；字段 `created_at`、`model`、`provider`、`input_tokens`、`output_tokens`、`reasoning_tokens`、`cache_read_tokens`、`cache_write_5m_tokens`、`cache_write_1h_tokens`、`cost_raw`、`cost_usd`、`key_id`、`session_id`、`plan`、`synced_at`。索引：`created_at DESC`。
- **usage_sync_state**：单行（id=1），`last_sync_at`、`last_sync_status`、`last_sync_error`、`last_inserted_count`、`deepest_page_fetched`、`total_records`、`oldest_record_at`、`newest_record_at`。
- **account**：单行（id=1），`name`、`workspace_id`、`resolved_workspace_id`、`token`、`created_at`、`updated_at`。

### 4.2 Preferences 设置项（对齐 `_DEFAULT_SETTINGS`）

`sync_interval_sec`（300，1/5/15/30 分钟）、`window_days`（60，30/60/90/180/所有）、`auto_sync`（true）、`theme`（light/dark）、`currency`（CNY/USD）、`language`（zh/en）。

### 4.3 聚合查询移植清单（UsageRepository）

- `totals(period)`：总览指标（请求数/会话数/输入/输出/推理/缓存读/缓存写/成本/命中率）
- `model_stats(period)`：按模型聚合
- `daily_stats(days)`：每日聚合
- `today_trend()`：今日 24 小时趋势（无数据补 0）
- `session_stats_page(page, page_size, days)`：会话聚合分页（空 session 归并为一行）
- `usage_records_page(page, page_size, model, days)`：明细分页
- `list_models()`：模型列表（去重）
- `prune_old_records(window_days)`：裁剪过期记录
- 周期过滤口径：`today` / `Nd` / `all`，与 db.py 的 `_period_where` 一致

## 5. 网络层

### 5.1 OpenCodeApi（移植 opencode_api.py）

- `http.createHttp()` 实现 GET 请求，带 Cookie/`X-Server-Id`/`X-Server-Instance`/UA/Origin/Referer 头
- `_server_call(server_id, args, referer_path, token)`：构造 `https://opencode.ai/_server?id=...&args=...`
- 配额：抓取 `https://opencode.ai/workspace/{ws}/go` 的 HTML，正则解析 `rollingUsage`/`weeklyUsage`/`monthlyUsage` 的 `usagePercent` + `resetInSec`（兼容字段顺序两种格式）
- 工作区：`fetch_workspace_refs` / `resolve_workspace_id`（支持 `wrk_` 直用 / 名称匹配 / 默认第一个）
- 用量记录：`fetch_usage_page`（每页 50 条，兼容 GET 无空格 / POST 带空格两种序列化格式），以 `usg_` 锚点切分解析 `model`/`inputTokens`/.../`cost`/`sessionID`/`plan`
- 错误处理：401/403 → AuthError（提示重新登录）；404 → 工作区不存在；网络错误重试 3 次（退避 0.5/1.5/3s）
- 汇率：`open.er-api.com/v6/latest/USD` → CNY，6 小时缓存，失败回退 7.2

### 5.2 SyncManager（移植 server.py sync_usage）

- 状态机：idle / quota / usage / done / error，进度（模式/页/新增数/消息）回调 UI
- 增量模式：最多 5 页；连续两批全部旧数据停止
- 全量模式：最多 2000 页；window_days 窗口边界裁剪（prune）
- 单飞守卫：同一时刻只允许一个同步任务；配额刷新独立、防重入、30s 缓存
- 同步完成后刷新 `usage_sync_state`
- 前台定时器自动增量同步（1/5/15/30 分钟，受 `auto_sync` 与 `sync_interval_sec` 控制）；应用启动时若已登录且库为空 → 自动全量同步

## 6. 登录流程（LoginPage）

- 页面内嵌 `Web` 组件，加载 `https://auth.opencode.ai/authorize?client_id=app&redirect_uri=https://opencode.ai/auth/callback&response_type=code&state={uuid}`
- `onUrlLoadIntercept` 拦截 URL；当进入 `https://opencode.ai/workspace/wrk_...` 时判定登录完成
- 用 `webview.WebCookieManager.getCookieSync('https://opencode.ai')` 读取 `auth` cookie 值
- 从 URL 提取 `wrk_[A-Za-z0-9]+` 作为工作区 ID 提示
- 保存 token → 关闭登录页 → 进入主界面 → 触发首次全量同步

## 7. UI 设计

### 7.1 导航

使用 ArkUI `Navigation` 组件作为页面壳，`NavDestination` 承载各功能页：

- 手机（窄屏）：`Navigation` 模式为标准模式，底部自定义 Tab 栏，5 个 Tab：首页 / 统计 / 记录 / 设置 / 关于
- 平板（宽屏 ≥840vp）：`Navigation` 模式为分栏模式，左侧固定导航栏，内容区单列/两栏复用参考布局
- 顶部标题栏：标题 + 同步指示 + 主题切换 + 刷新按钮

（不用 `Tabs`：鸿蒙 `Tabs` 的侧边栏样式定制受限，`Navigation` 原生支持响应式自适应布局。）

### 7.2 首页（DashboardPage）

- 时间范围切换：今天 / 近7天 / 近30天 / 全部
- 配额窗口：3 个进度条（5h Rolling / Weekly / Monthly），显示用量百分比 + 剩余比例 + 重置倒计时
- 用量概览 6 项：缓存命中率 / 命中量 / 总 Token / 请求数 / 费用 / 会话数
- 今日趋势：24 小时输入/输出分组柱状图
- 未登录时显示欢迎页（Logo + 功能简介 + 「立即登录」按钮）

### 7.3 用量统计（StatsPage）

- 顶部 4 个 KPI 卡（输入/输出/推理/成本，随范围变化）
- Token 构成 6 项：输入 / 输出 / 推理 / 缓存读 / 缓存写 / 会话数
- 模型用量：环形图 + 排行列表，维度切换（输入/输出/成本）
- 用量趋势：费用 / 请求 / 总 Token 三线折线图（近 30 天）

### 7.4 记录页（RecordsPage）

- 会话用量：表格（会话 / 最后使用 / 输入 / 输出 / 推理 / 请求 / 成本），分页（10 条/页）
- 使用记录：表格（时间 / 模型 / 输入 / 输出 / 推理 / 缓存读 / 费用），分页（50 条/页）+ 模型筛选下拉
- 费用显示遵循货币设置（CNY 换算 / USD 原值）

### 7.5 设置页（SettingsPage）

- 账户：登录状态 / 工作区 / 重新登录 / 退出登录（清空 token + 数据）
- 自动同步：开关 / 间隔（1/5/15/30 分钟）/ 范围（30/60/90/180/所有）/ 立即全量同步（显示进度）
- 外观：主题（亮/深）/ 货币（CNY/USD）/ 语言（中文/English）
- 数据：数据目录 / 同步记录（最近同步时间、总数、最早/最新记录）
- 软件更新：版本号 / 检查更新（打开 GitHub Releases 页）

### 7.6 关于页（AboutPage）

简介 / 功能列表 / 链接 / 致谢。

### 7.7 Canvas 图表组件

统一色板（亮/深色各一套，资源引用），随主题切换重绘：

- `BarChart`：今日 24h 输入/输出分组柱（支持日趋势多柱）
- `DonutChart`：模型 token 占比环形图（带图例/中心文本）
- `LineChart`：三线趋势（费用/请求/总 Token），双 Y 轴

### 7.8 国际化与主题

- `string.json` + `en_US` + `dark` 资源目录；默认跟随系统，可在设置中手动指定
- 文案全部沿用参考项目 `index.html` 的 `data-i18n` 内容

## 8. 错误处理

- HTTP 错误统一映射中文提示（AuthError → 重新登录引导；网络错误 → 重试提示）
- 同步错误持久化到 `usage_sync_state` 并在设置页展示
- 配额解析失败不影响仪表盘（返回空窗口 + 错误信息）
- 登录取消 / 窗口关闭 → 留在欢迎页

## 9. 测试

- 单元测试（`List.test.ets` / `LocalUnit.test.ets`）：Formatter 格式化、聚合查询口径、配额/用量正则解析、窗口边界裁剪
- Mock 配置（`entry/src/mock`）：示例用量数据，无账号调试 UI
- ohosTest：登录页 → 主界面跳转、Tab 切换冒烟

## 10. 不做（YAGNI）

- 系统托盘（鸿蒙无桌面托盘概念）
- 后台任务常驻同步（仅在应用前台用定时器；鸿蒙后台任务受限，不做 workScheduler 常驻）
- 应用内自动更新检查（保留「打开 GitHub Releases 页」）

## 11. 里程碑

1. 工程骨架 + 数据层（RDB/Preferences/仓储）+ Mock 数据可跑
2. 网络层 + 同步（OpenCodeApi/SyncManager）+ 登录页
3. 首页仪表盘 + Canvas 图表组件
4. 统计 / 记录 / 设置 / 关于页
5. 响应式（平板）+ 主题 + 国际化收尾 + 测试

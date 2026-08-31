# GoTally

**GoTally** — 原生 HarmonyOS（ArkTS）的 **OpenCode Go 用量统计面板**。

本地优先的用量仪表盘：配额窗口、Token 构成、模型排行、使用记录，打开即见。所有数据仅保存在本机，登录凭证只用于同步官方接口。

GoTally 由开源项目 [opencode-go-gauge](https://github.com/yphyphyph/opencode-go-gauge)（Python + pywebview）原生移植而来。

---

## 功能亮点

- **登录**：内置 WebView 打开 OpenCode 官方授权页，自动回填 token
- **配额窗口监控**：滚动 5 小时 / 每周 / 每月用量百分比与重置倒计时
- **首页概览**：缓存命中率、命中量、总 Token、请求数、费用、会话数 + 今日 24 小时输入/输出趋势
- **用量统计**：KPI 指标（总输入/未缓存输入/输出/推理/成本）、Token 构成（缓存读/缓存写）、模型用量排行与占比、30 天用量趋势（成本/请求/Token）
- **使用记录**：会话聚合 + 逐条明细，分页浏览，支持「今天 / 近7天 / 近30天 / 全部」周期筛选与按模型筛选；模型列点击可查看完整名称
- **自动同步**：增量/全量，同步间隔与历史窗口可配置
- **外观**：浅色 / 深色主题，人民币 / 美元费用显示（实时汇率），中文 / 英文双语
- **体验细节**：固定标题栏 + 顶部模糊、沉浸式布局适配系统安全区、数字单位本地化（中文万/亿，英文 k/M）

## 技术栈

- **语言/框架**：TypeScript（ArkTS）· ArkUI 声明式
- **机型**：手机 / 平板
- **API**：targetSdkVersion 6.1.1(24)，compatibleSdkVersion 6.1.0(23)
- **数据存储**：关系型数据库（RDB，`relationalStore`）存用量记录，`preferences` 存设置
- **UI 组件**：华为 HDS（`@kit.UIDesignKit` 的 HdsTabs 悬浮导航等）
- **网络**：`@kit.NetworkKit`
- **测试**：`@ohos/hypium` + `@ohos/hamock`（LocalUnit 单测）

## 项目结构

```
entry/src/main/ets/
├── entryability/          # Ability 入口（沉浸式布局、AppContext 注入）
├── pages/                 # Index / Dashboard / Stats / Records / Settings / About / Login
├── components/
│   ├── charts/            # BarChart / LineChart / DonutChart（Canvas 自绘）
│   └── ui/                # StatCard / Pager / QuotaProgress / SettingRow / SettingsCard
├── data/                  # UsageRepository / RdbHelper / SettingsStore / DataProvider / MockRepository
├── network/               # OpenCodeApi / SyncManager / UsageFetcher
├── model/                 # Stats / UsageRecord
├── common/
│   ├── utils/             # Formatter / TimeUtil / Locale
│   └── constants/         # Constants
entry/src/test/            # LocalUnit 单元测试
AppScope/                  # 应用级配置（app_name、icon）
```

## 环境要求

- DevEco Studio 6.x
- HarmonyOS SDK：API 24（6.1.1）+ API 23（6.1.0）兼容
- Node.js（DevEco 内置）

## 快速开始

**构建安装包**

```bash
hvigorw --mode module -p module=entry@default -p product=default -p requiredDeviceType=phone assembleHap
```

产物：`entry/build/default/outputs/default/entry-default-signed.hap`，用 DevEco Studio 部署到设备或模拟器。

**运行单元测试**（宿主机 LocalUnit）

```bash
hvigorw --mode module -p module=entry@default -p product=default -p buildMode=debug test
```

## 数据与隐私

- 用量数据仅保存在本机数据库 `gousage.db`，不对外上传
- 登录 token 仅用于向 OpenCode 官方接口发起同步请求
- 退出登录会清除本地 token 与全部用量数据

## 数据来源说明

GoTally 是一个**非官方客户端**：通过解析 OpenCode Go 官方 Dashboard / Usage 页面响应的嵌入数据（配额、用量记录）来获取信息。由于解析依赖页面结构，官方页面调整可能导致数据拉取失效，届时需更新解析逻辑。费用显示基于公开汇率接口换算。

## 常见问题

- **时间 / 筛选不对？** createdAt 统一规范化为 UTC ISO 并按设备本地时区展示，「今天/近7天/近30天」均以设备本地日期为准；历史异常格式数据会在启动时自动迁移修复。
- **首页同步后数据没刷新？** 已知问题：增量/全量同步完成后，首页概览可能不会自动刷新，切换一下「今天 / 近7天 / 近30天 / 全部」等周期筛选按钮即可触发重新加载并看到最新数据（统计页已在「同步完成自动刷新 + 中心/图例同源渲染」版本中修复；首页后续版本将一并改为自动刷新）。
- **需要登录吗？** 是——首次使用需用 OpenCode 账号授权登录，才能同步到你的用量数据；未登录时界面停留在欢迎页（开发环境可用 Mock 数据预览 UI）。

## License

本项目采用 [MIT](LICENSE) 协议，版权归 WingedFin1251 所有。项目数据由 [OpenCode](https://opencode.ai) 提供。

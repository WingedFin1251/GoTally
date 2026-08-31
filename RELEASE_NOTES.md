# GoTally v1.1.0

**稳定性与统计页修复版本** 🔧

## 更新内容

### 统计页（用量统计）
- **饼图彻底修复**：中心总数 / 图例分项 / 切片视觉三者同源同步；切换「今天 / 近7天 / 近30天 / 全部」与「输入 / 输出 / 成本」维度时，数值、占比（总和 100%）、视觉比例完全一致，不再交叉污染
- **趋势图修复并升级**：跟随周期筛选——「今天」显示 24 小时逐时趋势，「近7天 / 近30天 / 全部」显示逐日趋势；Token 与成本双 Y 轴（成本线不再贴底不可见）；图例按实际文字宽度排布、超宽自动换行不再重叠；右轴刻度取整消除浮点误差
- 同步完成后统计页自动刷新（无需手动切换筛选）

### 记录页
- 数据较少时不再“悬空居中”：空态提示、内容占满视口、单页时不显示分页控件
- 修复「共 {0} 条」模板未被替换的问题（现在正确显示“共 N 条”）
- “全部模型”下拉框与条数文案间距优化

### 布局与其它
- 全部页面顶部间距与标题栏高度精确对齐，消除多余空白
- 模型名截断时可点击查看全名
- 工程：清理全部 ArkTS 警告（异常处理 + 弃用 API 替换），构建零警告

---

# GoTally v1.0.0

**首个正式版本发布** 🎉

本地优先的 **OpenCode Go 用量统计面板**（HarmonyOS 原生 App，ArkTS / ArkUI 开发）。

GoTally 将配额窗口、Token 构成、模型排行与使用记录整理在同一处，打开即见；所有数据仅保存在本机，登录凭证只用于同步官方接口。

---

## ✨ 主要功能

- **OpenCode 登录**：内置浏览器打开官方授权页，自动回填 token
- **配额窗口监控**：滚动 5 小时 / 每周 / 每月用量百分比与重置倒计时
- **首页概览**：缓存命中率、命中量、总 Token、请求数、费用、会话数 + 今日 24 小时输入 / 输出趋势
- **用量统计**：KPI 指标（总输入 / 未缓存输入 / 输出 / 推理 / 成本）、Token 构成（缓存读 / 缓存写）、模型用量排行与占比、30 天用量趋势（成本 / 请求 / Token）
- **使用记录**：会话聚合 + 逐条明细，分页浏览；支持「今天 / 近 7 天 / 近 30 天 / 全部」周期筛选与按模型筛选
- **自动同步**：增量 / 全量同步，同步间隔（1 / 5 / 15 / 30 分钟）与历史窗口（30 / 60 / 90 / 180 天 / 全部）可配置；同步完成后状态自动刷新并弹出完成提示
- **外观与本地化**：浅色 / 深色主题；人民币 / 美元费用（实时汇率）；中文 / 英文双语界面
- **体验细节**：固定标题栏 + 顶部模糊、沉浸式布局适配系统安全区、数字单位本地化（中文 万 / 亿，英文 k / M）

## 📦 安装

- 下载附件 `entry-default-signed.hap`
- 使用 DevEco Studio 部署到设备，或通过 hdc 安装：

  ```
  hdc install entry-default-signed.hap
  ```

- 支持手机 / 平板，HarmonyOS API 23（6.1.0）及以上

## 🔒 数据与隐私

- 用量数据仅保存在本机数据库（`gousage.db`），不上传任何服务器
- 登录 token 仅用于向 OpenCode 官方接口发起同步请求
- 退出登录会清除本地 token 与全部用量数据

## 📝 已知说明

- GoTally 是**非官方客户端**：通过解析 OpenCode Go 官方 Dashboard / Usage 页面响应中的嵌入数据（配额、用量记录）获取信息；官方页面调整可能导致拉取失效，需后续更新解析逻辑
- 费用显示基于公开汇率接口换算，仅供参考
- 时间与「今天 / 近 7 天」筛选均以设备本地时区 / 日期为准

## 🙏 致谢

- 原生移植自开源项目 [opencode-go-gauge](https://github.com/yphyphyph/opencode-go-gauge)（Python + pywebview）
- 数据由 [OpenCode](https://opencode.ai) 提供

---

## English Summary

**GoTally v1.0.0 — initial release.** A local-first OpenCode Go usage panel for HarmonyOS.

Key features: OpenCode login (embedded browser), quota window monitoring (5h / weekly / monthly), home overview with cache hit rate & today's 24h trend, usage statistics (token breakdown, model ranking, 30-day trend), paginated usage records with period / model filters, auto sync (incremental & full, configurable interval and history window), light / dark theme, CNY / USD cost display with live rates, and Chinese / English UI.

Installation: download the `entry-default-signed.hap` attachment and install via DevEco Studio or `hdc install`. Requires HarmonyOS API 23+ (6.1.0), phone / tablet.

Privacy: all usage data stays on-device; the login token is only used to sync from the official OpenCode API.
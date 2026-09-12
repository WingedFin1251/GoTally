# GoTally v1.3.0

**数据可读性与交互升级** ✨

## 更新内容

### 新增
- **Key 名称列**：使用记录 / 会话用量两张列表新增「Key 名称」；同步时自动拉取工作区 API Key 名称（`/workspace/{id}/keys`）并本地缓存，名称取不到时回退显示 key 尾号
- **无会话记录按 Key 拆分**：没有会话归属的调用不再挤成一行「未归属」，而是按 Key 拆分为「未归属 · …key尾号」，来源一目了然
- **真正的「检查更新」**：优先请求 GitHub API 比对版本，网络抖动自动重试 3 次；失败时自动降级到 Releases Atom 订阅流（不受 API 限流）。发现新版本弹窗展示更新说明并可一键前往下载，失败时给出具体原因
- **版本号动态显示**：设置页 / 关于页版本号改为读取安装包信息（单一来源），不再硬编码，避免与实际安装版本不一致

### 优化
- **周期筛选改为官方胶囊分段控件**（HDS/ArkUI `SegmentButton`）：首页 / 用量统计 / 使用记录三页统一，带滑块式选中动画
- **使用记录、会话用量改为两行主次分离排布**：首行「会话 / 模型 + 费用」，次行「Key · 时间 / 请求数 + 输入 / 输出」；窄屏下模型名不再被挤压换行，去掉了密集的六列表头

### 修复
- **修复「近7天 / 近30天 + 指定模型」查不到数据**：筛选条件拼接时 SQL 参数顺序错位（周期参数被排到模型参数之前），导致该组合恒为空；已修正并新增 6 条回归单测锁定
- **修复冷启动闪现登录 / 欢迎页**：启动阶段预读登录态，判定完成前显示与系统启动闪屏一致的中性占位，不再“闪一下登录页”
- **修复登录页标题栏与状态栏重叠**：按系统避让区设置顶部内边距；授权页 WebView 改为占满剩余空间，加载指示改浮层（不再造成页面跳动）

### 工程
- 单元测试扩充至 **27 例**（新增筛选条件构造的 6 条回归用例），全部通过
- 构建保持 **0 错误 / 0 警告**

---

# GoTally v1.2.0

**界面质感与数据实时性升级** ✨

## 更新内容

### 沉浸式界面（新增）
- **沉浸光感（三档可调）**：设置 → 外观 新增「沉浸光感」（弱 / 均衡 / 强），实时作用于底部悬浮导航栏与顶部标题栏的系统材质通透度；切换即时生效、无需重启，并持久化保存
- **HDS 沉浸标题栏**：全部 5 个页面顶部标题栏升级为系统沉浸材质；内容滚入栏下时触发**渐变模糊**（0 → 20vp 内渐入），材质档位与「沉浸光感」联动
- **悬浮导航栏规格对齐**：56vp 栏高 / 22 图标 / 10.5 标签 / 选中 200ms 快出慢入过渡；跟随左右手设置；底部安全区（手势条）高度自适应
- **滚动联动**：向下滚动自动收起悬浮导航栏、向上滚动复位（HDS 滚动场景动画）
- **弹性回弹**：所有页面滚动到边缘时呈现弹簧回弹手感（内容不足一屏时同样生效）

### 数据实时性修复
- **修复「拉取数据完成后界面不刷新」**：此前必须手动切换「今天 / 近7天」等筛选才会更新——现在同步完成通知由数据层统一广播（无论停留在哪个页面、自动同步或手动全量同步），首页 / 统计页 / 记录页均会自动刷新
- 记录页新增同步完成自动刷新，并修复列表行复用导致数值不刷新的问题

### 工程
- 构建保持 **0 错误 / 0 警告**
- 引入官方 HDS（HarmonyOS Design System）组件：`HdsNavigation` / `HdsNavDestination` 沉浸标题栏、`HdsTabs` 悬浮导航栏

---

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
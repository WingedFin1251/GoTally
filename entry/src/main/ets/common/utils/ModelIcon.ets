// entry/src/main/ets/common/utils/ModelIcon.ets
/**
 * 模型图标映射（借鉴上游 opencode-go-gauge 的做法并修正其兜底）。
 *
 * 上游规则：取模型名第一段（按 `-` 切分）查表；查不到时 `hy*` 归 hy，
 * 其余一律回退 **deepseek** 图标 —— 这会把 claude / longcat 等显示成 deepseek 的
 * 品牌 logo（误导）。这里改为：查不到返回空键，由界面渲染「首字母徽章」。
 *
 * 另有主题差异：gpt / grok / mimo 的原版 logo 是单色（currentColor），
 * 深色背景下不可见，深色主题改用彩色版（`*_color`）。
 */
export class ModelIcon {
  /** 模型名首段 → 规范品牌键（别名归一，如 muse → meta）。 */
  private static readonly ALIAS: Map<string, string> = ModelIcon.buildAlias();

  /** 规范品牌键 → 资源名（resources/base/media/model_*.svg）。 */
  private static readonly RES: Map<string, string> = ModelIcon.buildRes();

  private static buildAlias(): Map<string, string> {
    const m = new Map<string, string>();
    const brands: string[] = ['deepseek', 'glm', 'gpt', 'grok', 'kimi', 'meta', 'mimo', 'minimax', 'qwen', 'hy'];
    for (const b of brands) {
      m.set(b, b);
    }
    m.set('muse', 'meta');
    return m;
  }

  private static buildRes(): Map<string, string> {
    const m = new Map<string, string>();
    const brands: string[] = ['deepseek', 'glm', 'gpt', 'grok', 'kimi', 'meta', 'mimo', 'minimax', 'qwen', 'hy'];
    for (const b of brands) {
      m.set(b, `model_${b}`);
    }
    return m;
  }

  /** 深色主题下需要换彩色版的键（原版是单色 logo）。 */
  private static readonly COLOR_VARIANTS: string[] = ['gpt', 'grok', 'mimo'];

  /** 模型名 → 品牌键（'' 表示未知，界面用首字母徽章兜底）。 */
  static keyOf(model: string): string {
    const s = model.trim().toLowerCase();
    if (s === '') {
      return '';
    }
    // 取第一段：`-` / `_` / `.` / 空格 都视为分隔符（deepseek-v4.1-flash → deepseek）
    let base = s;
    for (const sep of ['-', '_', '.', ' ', '/', ':']) {
      const i = base.indexOf(sep);
      if (i > 0) {
        base = base.substring(0, i);
      }
    }
    if (ModelIcon.ALIAS.has(base)) {
      return ModelIcon.ALIAS.get(base) as string;
    }
    // 「家族名 + 版本号」形态（qwen3 / glm5 / deepseek4 / grok5）：去掉末尾数字再匹配
    const stripped = base.replace(/[0-9]+$/, '');
    if (stripped !== base && ModelIcon.ALIAS.has(stripped)) {
      return ModelIcon.ALIAS.get(stripped) as string;
    }
    // 混元系列（hy2 / hy3 / hunyuan…）统一归 hy
    if (base.startsWith('hy') || base.startsWith('hunyuan')) {
      return 'hy';
    }
    return '';
  }

  /** 是否已知品牌（未知时界面画字母徽章）。 */
  static isKnown(model: string): boolean {
    return ModelIcon.keyOf(model) !== '';
  }

  /** 图标资源名（含主题适配）；未知模型返回空串。 */
  static resourceNameOf(model: string, dark: boolean): string {
    const key = ModelIcon.keyOf(model);
    if (key === '') {
      return '';
    }
    if (dark && ModelIcon.COLOR_VARIANTS.includes(key)) {
      return `model_${key}_color`;
    }
    return ModelIcon.RES.get(key) as string;
  }

  /** 未知模型的徽章文字：取首字母（最多 2 个，跳过数字段）。 */
  static initialsOf(model: string): string {
    const s = model.trim();
    if (s === '') {
      return '?';
    }
    const parts = s.split(/[-_.\s/]+/);
    let out = '';
    for (const p of parts) {
      if (p.length === 0) {
        continue;
      }
      const c = p.charAt(0).toUpperCase();
      if (c >= 'A' && c <= 'Z') {
        out += c;
        if (out.length >= 2) {
          break;
        }
      }
    }
    return out === '' ? s.charAt(0).toUpperCase() : out;
  }

  /** 未知模型的徽章底色：由模型名派生的稳定色（同一模型永远同色）。 */
  static colorOf(model: string): string {
    const palette: string[] = ['#4C8DFF', '#00B96B', '#FA8C16', '#EB2F96', '#722ED1', '#13C2C2', '#F5222D', '#A0D911'];
    let hash = 0;
    const s = model.trim().toLowerCase();
    for (let i = 0; i < s.length; i++) {
      hash = (hash * 31 + s.charCodeAt(i)) % 1000000007;
    }
    const idx = hash % palette.length;
    return palette[idx];
  }
}

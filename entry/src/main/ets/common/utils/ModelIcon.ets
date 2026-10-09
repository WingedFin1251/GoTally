// entry/src/main/ets/common/utils/ModelIcon.ets

/** 关键词 → 品牌键 的匹配规则。 */
interface IconRule {
  keyword: string;
  brand: string;
}

/**
 * 模型图标映射。
 *
 * 与上游 opencode-go-gauge 的差异：
 *  1. 上游只取模型名**第一段**查表，这里对**整个模型名**做关键词扫描
 *     （覆盖 llama-4-scout / mistral-large / sonar-pro / o3-mini / doubao-1.5 / phi-4 等）；
 *  2. 上游查不到时一律回退 deepseek 图标（会把 claude / longcat 显示成 DeepSeek 的
 *     logo），这里返回空键，由界面渲染「首字母徽章」；
 *  3. **浅色/深色两套图标**：单色 logo 的 SVG 没有 fill（默认黑）或用 currentColor，
 *     深色背景下不可见。运行时 `fillColor` 对无 fill 的 SVG 不生效，因此在构建期
 *     就生成两套文件（`_dark` 后缀，显式 fill：浅色主题 #1F1F1F / 深色主题 #E8EAED）。
 *
 * 资源：`resources/rawfile/model_icons/model_<brand>[_dark].svg`
 *  - 彩色品牌（deepseek / glm / hy / kimi / meta / minimax / qwen）：两主题共用
 *  - 单色品牌：浅色 + 深色两套
 * 来源：上游 opencode-go-gauge（MIT）与 Simple Icons（CC0）。
 */
export class ModelIcon {
  /** 全名关键词规则（顺序即优先级，越靠前越特异）。 */
  private static readonly RULES: IconRule[] = ModelIcon.buildRules();

  /** 单色品牌（有 `_dark` 变体）。 */
  private static readonly MONO: string[] = [
    'gpt', 'grok', 'mimo', 'claude', 'gemini', 'mistral', 'perplexity',
    'baidu', 'bytedance', 'microsoft', 'nvidia', 'huawei', 'tencentqq', 'alibabacloud',
  ];

  /** 规范品牌键集合。 */
  private static readonly BRANDS: string[] = [
    'deepseek', 'glm', 'hy', 'kimi', 'meta', 'minimax', 'qwen',
    'gpt', 'grok', 'mimo', 'claude', 'gemini', 'mistral', 'perplexity',
    'baidu', 'bytedance', 'microsoft', 'nvidia', 'huawei', 'tencentqq', 'alibabacloud',
  ];

  private static buildRules(): IconRule[] {
    const r: IconRule[] = [];
    const add = (keyword: string, brand: string): void => {
      r.push({ keyword: keyword, brand: brand });
    };
    // Claude / Anthropic
    add('claude', 'claude');
    add('anthropic', 'claude');
    // OpenAI 系
    add('chatgpt', 'gpt');
    add('gpt', 'gpt');
    add('codex', 'gpt');
    add('davinci', 'gpt');
    add('o1-', 'gpt');
    add('o3-', 'gpt');
    add('o4-', 'gpt');
    // Google
    add('gemini', 'gemini');
    add('googlegemini', 'gemini');
    add('palm', 'gemini');
    // xAI
    add('grok', 'grok');
    // DeepSeek
    add('deepseek', 'deepseek');
    // 阿里通义
    add('qwen', 'qwen');
    add('tongyi', 'qwen');
    add('bailian', 'qwen');
    add('alibaba', 'alibabacloud');
    // 智谱
    add('glm', 'glm');
    add('chatglm', 'glm');
    add('zhipu', 'glm');
    // 月之暗面
    add('kimi', 'kimi');
    add('moonshot', 'kimi');
    // MiniMax
    add('minimax', 'minimax');
    add('abab', 'minimax');
    // 小米
    add('mimo', 'mimo');
    // 腾讯混元
    add('hunyuan', 'hy');
    add('tencent', 'tencentqq');
    // Meta
    add('llama', 'meta');
    add('meta-', 'meta');
    add('muse', 'meta');
    // Mistral
    add('mistral', 'mistral');
    add('mixtral', 'mistral');
    add('codestral', 'mistral');
    add('magistral', 'mistral');
    add('devstral', 'mistral');
    // Perplexity
    add('sonar', 'perplexity');
    add('perplexity', 'perplexity');
    // 百度文心
    add('ernie', 'baidu');
    add('wenxin', 'baidu');
    // 字节豆包 / Seed
    add('doubao', 'bytedance');
    add('seed-', 'bytedance');
    add('bytedance', 'bytedance');
    // 微软 Phi
    add('phi-', 'microsoft');
    add('phi4', 'microsoft');
    // NVIDIA
    add('nemotron', 'nvidia');
    // 华为盘古
    add('panpan', 'huawei');
    add('pangu', 'huawei');
    return r;
  }

  /** 模型名 → 品牌键（'' 表示未知，界面用首字母徽章兜底）。 */
  static keyOf(model: string): string {
    const s = model.trim().toLowerCase();
    if (s === '') {
      return '';
    }
    for (const rule of ModelIcon.RULES) {
      if (s.includes(rule.keyword)) {
        return rule.brand;
      }
    }
    // 短关键词只按首段前缀匹配，避免误命中（hy2 / hy3 / hunyuan…）
    if (ModelIcon.firstSegment(s).startsWith('hy')) {
      return 'hy';
    }
    return '';
  }

  /** 是否已知品牌（未知时界面画字母徽章）。 */
  static isKnown(model: string): boolean {
    return ModelIcon.keyOf(model) !== '';
  }

  /** 该品牌是否为单色（有浅/深两套文件）。 */
  static isMono(model: string): boolean {
    return ModelIcon.MONO.includes(ModelIcon.keyOf(model));
  }

  /**
   * 图标文件路径（相对 `resources/rawfile`）；未知模型返回空串。
   * 单色品牌按主题选 `_dark` 变体。
   */
  static resourceNameOf(model: string, dark: boolean): string {
    const key = ModelIcon.keyOf(model);
    if (key === '') {
      return '';
    }
    const suffix = dark && ModelIcon.MONO.includes(key) ? '_dark' : '';
    return `model_icons/model_${key}${suffix}.svg`;
  }

  /** 已知品牌数量（关于页/设置页展示能力用）。 */
  static brandCount(): number {
    return ModelIcon.BRANDS.length;
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
    return palette[hash % palette.length];
  }

  /** 取第一段（`-` `_` `.` 空格 `/` `:` 视为分隔符）。 */
  private static firstSegment(s: string): string {
    let base = s;
    const seps: string[] = ['-', '_', '.', ' ', '/', ':'];
    for (const sep of seps) {
      const i = base.indexOf(sep);
      if (i > 0) {
        base = base.substring(0, i);
      }
    }
    return base;
  }
}

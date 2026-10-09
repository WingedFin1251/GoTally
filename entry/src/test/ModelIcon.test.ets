// entry/src/test/ModelIcon.test.ets
import { describe, it, expect } from '@ohos/hypium';
import { ModelIcon } from '../main/ets/common/utils/ModelIcon';

/**
 * 模型图标映射（回归测试）。
 *
 * 与上游 opencode-go-gauge 的差异：
 *  - 上游只取模型名**第一段**查表，且查不到一律回退 deepseek 图标（会把 claude /
 *    longcat 显示成 DeepSeek 的 logo）；
 *  - 这里对**整个模型名**做关键词扫描（覆盖 llama-4-scout / mistral-large / sonar-pro /
 *    o3-mini / doubao-1.5 / phi-4 这类家族名不在首段的命名），未知则返回空键走字母徽章。
 */
export default function modelIconTest() {
  describe('ModelIconTest', () => {
    it('maps_known_families_by_first_segment', 0, () => {
      expect(ModelIcon.keyOf('deepseek-v4.1-flash')).assertEqual('deepseek');
      expect(ModelIcon.keyOf('DeepSeek-V4-Flash')).assertEqual('deepseek');
      expect(ModelIcon.keyOf('glm-5.3')).assertEqual('glm');
      expect(ModelIcon.keyOf('gpt-5.6')).assertEqual('gpt');
      expect(ModelIcon.keyOf('grok-5')).assertEqual('grok');
      expect(ModelIcon.keyOf('kimi-k3')).assertEqual('kimi');
      expect(ModelIcon.keyOf('mimo-v2.5')).assertEqual('mimo');
      expect(ModelIcon.keyOf('minimax-m3')).assertEqual('minimax');
      expect(ModelIcon.keyOf('qwen3-max')).assertEqual('qwen');
      expect(ModelIcon.keyOf('muse-spark')).assertEqual('meta');
    });

    it('maps_by_keyword_anywhere_in_name', 0, () => {
      // 家族名不在首段的命名（上游会全部误判）
      expect(ModelIcon.keyOf('llama-4-scout')).assertEqual('meta');
      expect(ModelIcon.keyOf('meta-llama-3.3-70b')).assertEqual('meta');
      expect(ModelIcon.keyOf('mistral-large-2')).assertEqual('mistral');
      expect(ModelIcon.keyOf('codestral-2501')).assertEqual('mistral');
      expect(ModelIcon.keyOf('sonar-pro')).assertEqual('perplexity');
      expect(ModelIcon.keyOf('o3-mini')).assertEqual('gpt');
      expect(ModelIcon.keyOf('codex-mini-latest')).assertEqual('gpt');
      expect(ModelIcon.keyOf('ernie-4.5-turbo')).assertEqual('baidu');
      expect(ModelIcon.keyOf('doubao-1.5-pro')).assertEqual('bytedance');
      expect(ModelIcon.keyOf('phi-4-mini')).assertEqual('microsoft');
      expect(ModelIcon.keyOf('nemotron-4-340b')).assertEqual('nvidia');
      expect(ModelIcon.keyOf('pangu-5')).assertEqual('huawei');
      expect(ModelIcon.keyOf('chatglm3-6b')).assertEqual('glm');
      expect(ModelIcon.keyOf('moonshot-v1-128k')).assertEqual('kimi');
      expect(ModelIcon.keyOf('abab6.5s-chat')).assertEqual('minimax');
    });

    it('maps_claude_and_gemini', 0, () => {
      expect(ModelIcon.keyOf('claude-haiku-5-5')).assertEqual('claude');
      expect(ModelIcon.keyOf('claude-sonnet-4-5')).assertEqual('claude');
      expect(ModelIcon.keyOf('anthropic-claude')).assertEqual('claude');
      expect(ModelIcon.keyOf('gemini-3-pro')).assertEqual('gemini');
      expect(ModelIcon.keyOf('googlegemini-2')).assertEqual('gemini');
      expect(ModelIcon.resourceNameOf('claude-haiku-5-5', true)).assertEqual('model_icons/model_claude_dark.svg');
      expect(ModelIcon.resourceNameOf('claude-haiku-5-5', false)).assertEqual('model_icons/model_claude.svg');
      expect(ModelIcon.resourceNameOf('gemini-3-pro', true)).assertEqual('model_icons/model_gemini_dark.svg');
    });

    it('groups_hunyuan_prefixes', 0, () => {
      expect(ModelIcon.keyOf('hy3')).assertEqual('hy');
      expect(ModelIcon.keyOf('hy2-preview')).assertEqual('hy');
      expect(ModelIcon.keyOf('hunyuan-large')).assertEqual('hy');
      expect(ModelIcon.keyOf('tencent-hunyuan-pro')).assertEqual('hy');
    });

    it('unknown_family_is_empty_not_deepseek', 0, () => {
      // 上游会错误地回退成 deepseek 图标，这里必须是「未知」
      expect(ModelIcon.keyOf('longcat-2.5-preview-free')).assertEqual('');
      expect(ModelIcon.keyOf('command-r-plus')).assertEqual('');
      expect(ModelIcon.keyOf('nova-pro')).assertEqual('');
      expect(ModelIcon.isKnown('longcat-2.5-preview-free')).assertFalse();
      expect(ModelIcon.isKnown('deepseek-v4.1-flash')).assertTrue();
    });

    it('resource_name_and_tint_flags', 0, () => {
      expect(ModelIcon.resourceNameOf('deepseek-v4.1-flash', true)).assertEqual('model_icons/model_deepseek.svg');
      expect(ModelIcon.resourceNameOf('hy3', false)).assertEqual('model_icons/model_hy.svg');
      expect(ModelIcon.resourceNameOf('mistral-large', true)).assertEqual('model_icons/model_mistral_dark.svg');
      expect(ModelIcon.resourceNameOf('sonar-pro', false)).assertEqual('model_icons/model_perplexity.svg');
      // 单色图标需按主题上色（否则深色背景不可见）
      expect(ModelIcon.isMono('claude-haiku-5-5')).assertTrue();
      expect(ModelIcon.isMono('gpt-5.6')).assertTrue();
      expect(ModelIcon.isMono('mistral-large')).assertTrue();
      // 彩色品牌图标保持原色
      expect(ModelIcon.isMono('deepseek-v4.1-flash')).assertFalse();
      expect(ModelIcon.isMono('minimax-m3')).assertFalse();
      expect(ModelIcon.isMono('qwen3-max')).assertFalse();
      expect(ModelIcon.isMono('llama-4-scout')).assertFalse();
      // 未知模型没有资源名
      expect(ModelIcon.resourceNameOf('longcat-2.5-preview-free', true)).assertEqual('');
    });

    it('initials_badge_for_unknown_models', 0, () => {
      expect(ModelIcon.initialsOf('longcat-2.5-preview-free')).assertEqual('LP');
      expect(ModelIcon.initialsOf('command-r-plus')).assertEqual('CR');
      expect(ModelIcon.initialsOf('nova-pro')).assertEqual('NP');
      expect(ModelIcon.initialsOf('single')).assertEqual('S');
      expect(ModelIcon.initialsOf('')).assertEqual('?');
    });

    it('color_is_stable_per_model', 0, () => {
      expect(ModelIcon.colorOf('longcat-2.5-preview-free')).assertEqual(ModelIcon.colorOf('longcat-2.5-preview-free'));
      expect(ModelIcon.colorOf('nova-pro')).assertEqual(ModelIcon.colorOf('NOVA-PRO'));
      expect(ModelIcon.colorOf('nova-pro').startsWith('#')).assertTrue();
      expect(ModelIcon.brandCount() >= 20).assertTrue();
    });
  });
}


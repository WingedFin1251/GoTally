// entry/src/test/ModelIcon.test.ets
import { describe, it, expect } from '@ohos/hypium';
import { ModelIcon } from '../main/ets/common/utils/ModelIcon';

/**
 * 模型图标映射（回归测试）。
 *
 * 规则来自上游 opencode-go-gauge，但修正了它的兜底：上游查不到时一律回退
 * deepseek 图标（会把 claude / longcat 显示成 DeepSeek 的品牌 logo）。
 * 这里改为返回空键，由界面渲染「首字母徽章」。
 */
export default function modelIconTest() {
  describe('ModelIconTest', () => {
    it('maps_known_families_by_first_segment', 0, () => {
      expect(ModelIcon.keyOf('deepseek-v4.1-flash')).assertEqual('deepseek');
      expect(ModelIcon.keyOf('DeepSeek-V4-Flash')).assertEqual('deepseek');
      expect(ModelIcon.keyOf('deepseek-v4-flash')).assertEqual('deepseek');
      expect(ModelIcon.keyOf('glm-5.3')).assertEqual('glm');
      expect(ModelIcon.keyOf('gpt-5.6')).assertEqual('gpt');
      expect(ModelIcon.keyOf('grok-5')).assertEqual('grok');
      expect(ModelIcon.keyOf('kimi-k3')).assertEqual('kimi');
      expect(ModelIcon.keyOf('mimo-v2.5')).assertEqual('mimo');
      expect(ModelIcon.keyOf('minimax-m3')).assertEqual('minimax');
      expect(ModelIcon.keyOf('qwen3-max')).assertEqual('qwen');
      expect(ModelIcon.keyOf('muse-spark')).assertEqual('meta');
    });

    it('groups_hunyuan_prefixes', 0, () => {
      expect(ModelIcon.keyOf('hy3')).assertEqual('hy');
      expect(ModelIcon.keyOf('hy2-preview')).assertEqual('hy');
      expect(ModelIcon.keyOf('hunyuan-large')).assertEqual('hy');
    });

    it('unknown_family_is_empty_not_deepseek', 0, () => {
      // 上游会错误地回退成 deepseek 图标，这里必须是「未知」
      expect(ModelIcon.keyOf('claude-haiku-5-5')).assertEqual('');
      expect(ModelIcon.keyOf('longcat-2.5-preview-free')).assertEqual('');
      expect(ModelIcon.keyOf('gemini-3-pro')).assertEqual('');
      expect(ModelIcon.isKnown('claude-haiku-5-5')).assertFalse();
      expect(ModelIcon.isKnown('deepseek-v4.1-flash')).assertTrue();
    });

    it('resource_name_switches_for_dark_theme', 0, () => {
      // gpt/grok/mimo 原版是单色 logo，深色主题改用彩色版
      expect(ModelIcon.resourceNameOf('gpt-5.6', true)).assertEqual('model_gpt_color');
      expect(ModelIcon.resourceNameOf('gpt-5.6', false)).assertEqual('model_gpt');
      expect(ModelIcon.resourceNameOf('grok-5', true)).assertEqual('model_grok_color');
      expect(ModelIcon.resourceNameOf('mimo-v2.5', true)).assertEqual('model_mimo_color');
      // 彩色 logo 不区分主题
      expect(ModelIcon.resourceNameOf('deepseek-v4.1-flash', true)).assertEqual('model_deepseek');
      expect(ModelIcon.resourceNameOf('deepseek-v4.1-flash', false)).assertEqual('model_deepseek');
      expect(ModelIcon.resourceNameOf('hy3', true)).assertEqual('model_hy');
      // 未知模型没有资源名
      expect(ModelIcon.resourceNameOf('claude-haiku-5-5', true)).assertEqual('');
    });

    it('initials_badge_for_unknown_models', 0, () => {
      expect(ModelIcon.initialsOf('claude-haiku-5-5')).assertEqual('CH');
      // longcat-2.5-preview-free → Longcat Preview → 'LP'（数字段跳过）
      expect(ModelIcon.initialsOf('longcat-2.5-preview-free')).assertEqual('LP');
      expect(ModelIcon.initialsOf('gemini-3-pro')).assertEqual('GP');
      expect(ModelIcon.initialsOf('single')).assertEqual('S');
      expect(ModelIcon.initialsOf('')).assertEqual('?');
    });

    it('color_is_stable_per_model', 0, () => {
      expect(ModelIcon.colorOf('claude-haiku-5-5')).assertEqual(ModelIcon.colorOf('claude-haiku-5-5'));
      expect(ModelIcon.colorOf('longcat-2.5-preview-free')).assertEqual(ModelIcon.colorOf('LONGCAT-2.5-preview-free'));
      expect(ModelIcon.colorOf('claude-haiku-5-5').startsWith('#')).assertTrue();
    });
  });
}

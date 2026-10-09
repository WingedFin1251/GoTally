// entry/src/main/ets/components/ui/ModelIconView.ets
import { ModelIcon } from '../../common/utils/ModelIcon';

/**
 * 模型图标（品牌 SVG；未知模型退化为「首字母徽章」）。
 *
 * 用法：`ModelIconView({ model: 'deepseek-v4.1-flash', iconSize: 16, dark: true })`
 * 品牌资源见 `resources/base/media/model_*.svg`：多来自上游 opencode-go-gauge（MIT），
 * Claude / Gemini 取自 Simple Icons（CC0）。
 */
@Component
export struct ModelIconView {
  @Prop model: string = '';
  @Prop iconSize: number = 16;
  /** 深色主题：gpt/grok/mimo 用彩色版（原版单色在深色下不可见）。 */
  @Prop dark: boolean = true;

  build() {
    if (ModelIcon.isKnown(this.model)) {
      if (ModelIcon.needsTint(this.model)) {
        // 单色图标（claude / gemini）自身无颜色：按主题上色，否则深色背景看不见
        Image(this.iconSource())
          .width(this.iconSize)
          .height(this.iconSize)
          .objectFit(ImageFit.Contain)
          .fillColor(this.dark ? '#E8EAED' : '#1F1F1F')
          .draggable(false)
      } else {
        Image(this.iconSource())
          .width(this.iconSize)
          .height(this.iconSize)
          .objectFit(ImageFit.Contain)
          .draggable(false)
      }
    } else {
      Text(ModelIcon.initialsOf(this.model))
        .fontSize(this.iconSize * 0.55)
        .fontWeight(FontWeight.Bold)
        .fontColor(Color.White)
        .width(this.iconSize)
        .height(this.iconSize)
        .textAlign(TextAlign.Center)
        .borderRadius(this.iconSize * 0.28)
        .backgroundColor(ModelIcon.colorOf(this.model))
        .draggable(false)
    }
  }

  /** 品牌键 → 具体资源（`$r` 只能在这里按分支取，无法用字符串拼接）。 */
  private iconSource(): Resource {
    const key = ModelIcon.keyOf(this.model);
    const useColor = this.dark && (key === 'gpt' || key === 'grok' || key === 'mimo');
    if (key === 'deepseek') {
      return $r('app.media.model_deepseek');
    }
    if (key === 'glm') {
      return $r('app.media.model_glm');
    }
    if (key === 'gpt') {
      return useColor ? $r('app.media.model_gpt_color') : $r('app.media.model_gpt');
    }
    if (key === 'grok') {
      return useColor ? $r('app.media.model_grok_color') : $r('app.media.model_grok');
    }
    if (key === 'kimi') {
      return $r('app.media.model_kimi');
    }
    if (key === 'meta') {
      return $r('app.media.model_meta');
    }
    if (key === 'mimo') {
      return useColor ? $r('app.media.model_mimo_color') : $r('app.media.model_mimo');
    }
    if (key === 'minimax') {
      return $r('app.media.model_minimax');
    }
    if (key === 'qwen') {
      return $r('app.media.model_qwen');
    }
    if (key === 'claude') {
      return $r('app.media.model_claude');
    }
    if (key === 'gemini') {
      return $r('app.media.model_gemini');
    }
    return $r('app.media.model_hy');
  }
}


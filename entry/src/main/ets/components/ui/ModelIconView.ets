// entry/src/main/ets/components/ui/ModelIconView.ets
import { ModelIcon } from '../../common/utils/ModelIcon';

/**
 * 模型图标（品牌 SVG；未知模型退化为「首字母徽章」）。
 *
 * 用法：`ModelIconView({ model: 'deepseek-v4.1-flash', iconSize: 16, dark: true })`
 *
 * 单色 logo 的 SVG 默认是黑色（或用 currentColor），深色背景下不可见；运行时
 * `fillColor` 对「无 fill 属性」的 SVG 不生效，因此**预制两套文件**：
 *   - `model_<brand>.svg`       浅色主题（#1F1F1F）
 *   - `model_<brand>_dark.svg`  深色主题（#E8EAED）
 * 彩色品牌（deepseek / glm / hy / kimi / meta / minimax / qwen）两主题共用一套。
 *
 * 资源位置：`resources/rawfile/model_icons/`（用 `$rawfile` 动态取，新增图标无需改代码）
 * 来源：上游 opencode-go-gauge（MIT）、Simple Icons（CC0）
 */
@Component
export struct ModelIconView {
  @Prop model: string = '';
  @Prop iconSize: number = 16;
  /** 是否深色主题（决定单色图标用哪一套文件）。 */
  @Prop dark: boolean = true;

  build() {
    if (ModelIcon.isKnown(this.model)) {
      Image($rawfile(ModelIcon.resourceNameOf(this.model, this.dark)))
        .width(this.iconSize)
        .height(this.iconSize)
        .objectFit(ImageFit.Contain)
        .draggable(false)
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
}

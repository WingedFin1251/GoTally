// entry/src/main/ets/common/utils/NavTitleBar.ets
import { BlurStrategy, HdsNavigationTitleBarOptions, ScrollEffectType, hdsMaterial } from '@kit.UIDesignKit';
import { LengthMetrics } from '@kit.ArkUI';

/**
 * HDS 沉浸光感标题栏构建器（对齐参考项目 common/utils/NavTitleBar.ets）。
 *
 * 效果：
 * - 内容滚入栏下时触发「渐变模糊」（沉浸渐变模糊，0 → 20vp 内模糊渐入）
 * - 栏体走 IMMERSIVE 系统材质，档位跟随设置页的「沉浸光感」（0 弱 / 1 均衡 / 2 强）
 *
 * 用法：挂在 HdsNavDestination 上，并把页面 Scroller 绑定过去
 *   HdsNavigation() {
 *     HdsNavDestination() { 内容 }
 *       .titleBar(buildTitleBar($r('app.string.xxx')))
 *       .bindToScrollable([this.scroller])
 *   }
 *   .mode(NavigationMode.Stack).hideTitleBar(true).hideToolBar(true)
 *
 * 注意：内容区顶部需自行预留标题栏高度（56vp）+ 状态栏高度，否则首屏内容会被栏体压住。
 *
 * @param title 标题文案
 * @param glowLevel 沉浸光感档位（0 弱 / 1 均衡 / 2 强）。必须由页面的 @StorageProp('glowLevel')
 *        显式传入——这样档位变化会触发页面重建，标题栏材质即时更新；若在函数内直接读 AppStorage，
 *        页面不会因该值变化而重建，会出现「要重启应用才生效」的问题。
 */
export function buildTitleBar(title: ResourceStr, glowLevel: number): HdsNavigationTitleBarOptions {
  let level: hdsMaterial.MaterialLevel = hdsMaterial.MaterialLevel.ADAPTIVE;
  if (glowLevel === 0) {
    level = hdsMaterial.MaterialLevel.GENTLE;
  } else if (glowLevel === 2) {
    level = hdsMaterial.MaterialLevel.EXQUISITE;
  }
  // 标题/图标颜色用资源色，随深浅色主题自动适配
  const titleColor: Resource = $r('app.color.text_primary');
  return {
    content: {
      title: {
        mainTitle: title
      }
    },
    avoidLayoutSafeArea: true,
    style: {
      originalStyle: {
        contentStyle: {
          titleStyle: { mainTitleColor: titleColor },
          backIconStyle: { iconColor: titleColor },
          menuStyle: { iconColor: titleColor }
        }
      },
      scrollEffectStyle: {
        contentStyle: {
          titleStyle: { mainTitleColor: titleColor },
          backIconStyle: { iconColor: titleColor },
          menuStyle: { iconColor: titleColor }
        }
      },
      scrollEffectOpts: {
        enableScrollEffect: true,
        scrollEffectType: ScrollEffectType.IMMERSIVE_GRADIENT_BLUR,
        blurEffectiveStartOffset: LengthMetrics.vp(0),
        blurEffectiveEndOffset: LengthMetrics.vp(20)
      },
      blurStrategy: BlurStrategy.ENABLE,
      systemMaterialEffect: {
        materialType: hdsMaterial.MaterialType.IMMERSIVE,
        materialLevel: level
      }
    }
  };
}
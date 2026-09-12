// entry/src/main/ets/pages/AboutPage.ets
import { common } from '@kit.AbilityKit';
import { HdsNavigation, HdsNavDestination } from '@kit.UIDesignKit';
import { buildTitleBar } from '../common/utils/NavTitleBar';

@Component
export struct AboutPage {
  @StorageProp('statusBarHeight') statusBarHeight: number = 0;
  @StorageProp('navIndicatorHeight') navIndicatorHeight: number = 0;
  /** 沉浸光感档位：响应式依赖，改设置后标题栏材质即时更新。 */
  @StorageProp('glowLevel') glowLevel: number = 1;
  /** 页面滚动控制器：绑定给 HDS 标题栏，驱动「内容滚入栏下渐变模糊」。 */
  private scroller: Scroller = new Scroller();
  /** 滚动联动：向下滚隐藏悬浮导航栏、向上滚显示（由 Index 播放 HDS 滚动动画）。 */
  onNavChanged?: (hide: boolean) => void;
  private scrollHidden: boolean = false;

  /** 滚动联动：向下滚隐藏悬浮导航栏，向上滚显示。 */
  private handleNavScroll(offset: number): void {
    if (offset > 0 && !this.scrollHidden) {
      this.scrollHidden = true;
      if (this.onNavChanged !== undefined) { this.onNavChanged(true); }
    } else if (offset < 0 && this.scrollHidden) {
      this.scrollHidden = false;
      if (this.onNavChanged !== undefined) { this.onNavChanged(false); }
    }
  }

  build() {
    // HDS 沉浸光感标题栏（对齐参考项目）：内容滚入栏下触发渐变模糊，材质档位跟随「沉浸光感」设置
    HdsNavigation() {
      HdsNavDestination() {
        Stack({ alignContent: Alignment.Top }) {
      // 滚动内容：可滚到固定标题栏下方（标题栏模糊蒙版保证可读性）
          Scroll(this.scroller) {
        Column({ space: 12 }) {
          // 应用标识头部：图标 + 名称 + 版本
          Column({ space: 8 }) {
            Image($r('app.media.startIcon'))
              .width(72)
              .height(72)
              .borderRadius(18)
              .objectFit(ImageFit.Cover)
            Text('GoTally')
              .fontSize(22)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary'))
            Text('v1.1.0')
              .fontSize(12)
              .fontColor($r('app.color.text_muted'))
          }
          .width('100%')
          .alignItems(HorizontalAlign.Center)
          .padding({ top: 20, bottom: 20 })
          .borderRadius(12)
          .backgroundColor($r('app.color.bg_card'))

          // 简介
          Column({ space: 8 }) {
            Text($r('app.string.about_intro')).fontSize(15).fontWeight(FontWeight.Bold).width('100%')
            Text($r('app.string.intro_text')).fontSize(13).fontColor($r('app.color.text_secondary')).lineHeight(20)
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding(12)
          .borderRadius(12)
          .backgroundColor($r('app.color.bg_card'))

          // 功能
          Column({ space: 10 }) {
            Text($r('app.string.about_features')).fontSize(15).fontWeight(FontWeight.Bold).width('100%')
            Row({ space: 8 }) {
              Text('✓').fontSize(13).fontWeight(FontWeight.Bold).fontColor($r('app.color.accent'))
              Text($r('app.string.feat_1')).fontSize(13).fontColor($r('app.color.text_secondary')).layoutWeight(1).textAlign(TextAlign.Start)
            }.width('100%').alignItems(VerticalAlign.Top)
            Row({ space: 8 }) {
              Text('✓').fontSize(13).fontWeight(FontWeight.Bold).fontColor($r('app.color.accent'))
              Text($r('app.string.feat_2')).fontSize(13).fontColor($r('app.color.text_secondary')).layoutWeight(1).textAlign(TextAlign.Start)
            }.width('100%').alignItems(VerticalAlign.Top)
            Row({ space: 8 }) {
              Text('✓').fontSize(13).fontWeight(FontWeight.Bold).fontColor($r('app.color.accent'))
              Text($r('app.string.feat_3')).fontSize(13).fontColor($r('app.color.text_secondary')).layoutWeight(1).textAlign(TextAlign.Start)
            }.width('100%').alignItems(VerticalAlign.Top)
            Row({ space: 8 }) {
              Text('✓').fontSize(13).fontWeight(FontWeight.Bold).fontColor($r('app.color.accent'))
              Text($r('app.string.feat_4')).fontSize(13).fontColor($r('app.color.text_secondary')).layoutWeight(1).textAlign(TextAlign.Start)
            }.width('100%').alignItems(VerticalAlign.Top)
            Row({ space: 8 }) {
              Text('✓').fontSize(13).fontWeight(FontWeight.Bold).fontColor($r('app.color.accent'))
              Text($r('app.string.feat_5')).fontSize(13).fontColor($r('app.color.text_secondary')).layoutWeight(1).textAlign(TextAlign.Start)
            }.width('100%').alignItems(VerticalAlign.Top)
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding(12)
          .borderRadius(12)
          .backgroundColor($r('app.color.bg_card'))

          // 链接
          Column({ space: 8 }) {
            Text($r('app.string.about_links')).fontSize(15).fontWeight(FontWeight.Bold).width('100%')
            Row({ space: 8 }) {
              Text('GitHub').fontSize(13).fontColor($r('app.color.text_primary'))
              Text('github.com/WingedFin1251/GoTally')
                .fontSize(13)
                .fontColor($r('app.color.accent'))
                .layoutWeight(1)
                .textAlign(TextAlign.End)
            }
            .width('100%')
            .onClick(() => {
              const lctx = this.getUIContext().getHostContext();
              if (lctx !== undefined) {
                (lctx as common.UIAbilityContext).openLink('https://github.com/WingedFin1251/GoTally');
              }
            })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding(12)
          .borderRadius(12)
          .backgroundColor($r('app.color.bg_card'))

          // 页脚
          Text($r('app.string.page_foot'))
            .fontSize(11)
            .fontColor($r('app.color.text_muted'))
            .width('100%')
            .textAlign(TextAlign.Center)
            .margin({ top: 4, bottom: 8 })
        }
        .width('100%')
        .justifyContent(FlexAlign.Start)
        .alignItems(HorizontalAlign.Start)
        .padding({ left: 12, right: 12, top: this.statusBarHeight + 60, bottom: 96 })
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.bg_page'))
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
      .onScrollFrameBegin((offset: number) => {
        this.handleNavScroll(offset);
        return { offsetRemain: offset };
      })

    }
    .width('100%')
    .height('100%')
      }
      .titleBar(buildTitleBar($r('app.string.about_title'), this.glowLevel))
      .hideBackButton(true)
      .bindToScrollable([this.scroller])
    }
    .mode(NavigationMode.Stack)
    .hideTitleBar(true)
    .hideToolBar(true)
    .width('100%')
    .height('100%')
  }
}

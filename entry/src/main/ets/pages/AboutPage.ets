// entry/src/main/ets/pages/AboutPage.ets
import { common } from '@kit.AbilityKit';

@Component
export struct AboutPage {
  @StorageProp('statusBarHeight') statusBarHeight: number = 0;
  @StorageProp('navIndicatorHeight') navIndicatorHeight: number = 0;

  build() {
    Stack({ alignContent: Alignment.Top }) {
      // 滚动内容：可滚到固定标题栏下方（标题栏模糊蒙版保证可读性）
      Scroll() {
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
            Text('v1.0.0')
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
        .padding({ left: 12, right: 12, top: this.statusBarHeight + 52, bottom: 96 })
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.bg_page'))
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
      .scrollBar(BarState.Off)

      // 固定标题栏：顶部让出状态栏（不与通知栏重叠），背景模糊
      Column() {
        Row() {
          Text($r('app.string.about_title')).fontSize(18).fontWeight(FontWeight.Bold)
          Blank()
        }
        .width('100%')
      }
      .width('100%')
      .padding({ left: 12, right: 12, top: 12 + this.statusBarHeight, bottom: 10 })
      .backgroundBlurStyle(BlurStyle.Regular)
    }
    .width('100%')
    .height('100%')
  }
}

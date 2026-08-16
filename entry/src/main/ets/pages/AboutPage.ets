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
          Column({ space: 8 }) {
            Text($r('app.string.about_intro')).fontSize(15).fontWeight(FontWeight.Bold).width('100%')
            Text($r('app.string.intro_text')).fontSize(13).fontColor($r('app.color.text_secondary')).lineHeight(20)
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding(12)
          .borderRadius(12)
          .backgroundColor($r('app.color.bg_card'))

          Column({ space: 8 }) {
            Text($r('app.string.about_features')).fontSize(15).fontWeight(FontWeight.Bold).width('100%')
            Row() { Text('· ').fontSize(13); Text($r('app.string.feat_1')).fontSize(13).fontColor($r('app.color.text_secondary')) }
            Row() { Text('· ').fontSize(13); Text($r('app.string.feat_2')).fontSize(13).fontColor($r('app.color.text_secondary')) }
            Row() { Text('· ').fontSize(13); Text($r('app.string.feat_3')).fontSize(13).fontColor($r('app.color.text_secondary')) }
            Row() { Text('· ').fontSize(13); Text($r('app.string.feat_4')).fontSize(13).fontColor($r('app.color.text_secondary')) }
            Row() { Text('· ').fontSize(13); Text($r('app.string.feat_5')).fontSize(13).fontColor($r('app.color.text_secondary')) }
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding(12)
          .borderRadius(12)
          .backgroundColor($r('app.color.bg_card'))

          Column({ space: 8 }) {
            Text($r('app.string.about_links')).fontSize(15).fontWeight(FontWeight.Bold).width('100%')
            Text('GitHub: github.com/yphyphyph/opencode-go-gauge')
              .fontSize(13)
              .fontColor($r('app.color.accent'))
              .onClick(() => {
                (getContext(this) as common.UIAbilityContext).openLink('https://github.com/yphyphyph/opencode-go-gauge');
              })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding(12)
          .borderRadius(12)
          .backgroundColor($r('app.color.bg_card'))

          Text($r('app.string.page_foot'))
            .fontSize(11)
            .fontColor($r('app.color.text_muted'))
            .margin({ top: 8 })
        }
        .justifyContent(FlexAlign.Start)
        .alignItems(HorizontalAlign.Start)
        .padding({ left: 12, right: 12, top: this.statusBarHeight + 64, bottom: 96 })
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
      .backgroundBlurStyle(BlurStyle.COMPONENT_REGULAR)
    }
    .width('100%')
    .height('100%')
  }
}

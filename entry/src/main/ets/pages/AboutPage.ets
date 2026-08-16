// entry/src/main/ets/pages/AboutPage.ets
import { promptAction } from '@kit.ArkUI';

@Component
export struct AboutPage {
  build() {
    Scroll() {
      Column({ space: 12 }) {
        Row() {
          Text($r('app.string.about_title')).fontSize(18).fontWeight(FontWeight.Bold)
          Blank()
        }
        .width('100%')

        Column({ space: 8 }) {
          Text($r('app.string.about_intro')).fontSize(15).fontWeight(FontWeight.Bold).width('100%')
          Text($r('app.string.intro_text')).fontSize(13).fontColor($r('app.color.text_secondary')).lineHeight(20)
        }
        .width('100%')
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
        .padding(12)
        .borderRadius(12)
        .backgroundColor($r('app.color.bg_card'))

        Column({ space: 8 }) {
          Text($r('app.string.about_links')).fontSize(15).fontWeight(FontWeight.Bold).width('100%')
          Text('GitHub: github.com/yphyphyph/opencode-go-gauge')
            .fontSize(13)
            .fontColor($r('app.color.accent'))
            .onClick(() => {
              promptAction.openUrl('https://github.com/yphyphyph/opencode-go-gauge');
            })
        }
        .width('100%')
        .padding(12)
        .borderRadius(12)
        .backgroundColor($r('app.color.bg_card'))

        Text($r('app.string.page_foot'))
          .fontSize(11)
          .fontColor($r('app.color.text_muted'))
          .margin({ top: 8 })
      }
      .padding(12)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.bg_page'))
    .scrollBar(BarState.Off)
  }
}

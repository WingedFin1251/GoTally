// entry/src/main/ets/components/ui/StatCard.ets
@Component
export struct StatCard {
  // ResourceStr = string | Resource，兼容直接传 $r() 资源与计算出的字符串
  @Prop title: ResourceStr = '';
  @Prop value: ResourceStr = '';
  @Prop sub: ResourceStr = '';
  @Prop accent: boolean = false;

  build() {
    Column({ space: 4 }) {
      Text(this.title)
        .fontSize(12)
        .fontColor($r('app.color.text_muted'))
      Text(this.value)
        .fontSize(this.accent ? 22 : 18)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.accent ? $r('app.color.accent') : $r('app.color.text_primary'))
      if (this.sub !== '') {
        Text(this.sub)
          .fontSize(11)
          .fontColor($r('app.color.text_muted'))
      }
    }
    .width('100%')
    .padding(12)
    .borderRadius(12)
    .backgroundColor($r('app.color.bg_card'))
    .alignItems(HorizontalAlign.Start)
  }
}

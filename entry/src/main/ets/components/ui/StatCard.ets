// entry/src/main/ets/components/ui/StatCard.ets
@Component
export struct StatCard {
  // ResourceStr = string | Resource，兼容直接传 $r() 资源与计算出的字符串
  @Prop title: ResourceStr = '';
  @Prop value: ResourceStr = '';
  @Prop sub: ResourceStr = '';
  @Prop accent: boolean = false;

  private valueLen(): number {
    return typeof this.value === 'string' ? this.value.length : 0;
  }

  private valueFont(): number {
    const len = this.valueLen();
    if (this.accent) {
      return len > 10 ? 16 : 22;
    }
    return len > 14 ? 14 : 18;
  }

  build() {
    Column({ space: 4 }) {
      Text(this.title)
        .fontSize(12)
        .fontColor($r('app.color.text_muted'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Text(this.value)
        .fontSize(this.valueFont())
        .fontWeight(FontWeight.Bold)
        .fontColor(this.accent ? $r('app.color.accent') : $r('app.color.text_primary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      if (this.sub !== '') {
        Text(this.sub)
          .fontSize(11)
          .fontColor($r('app.color.text_muted'))
          .maxLines(1)
      }
    }
    .width('100%')
    .constraintSize({ minHeight: 88 })
    .padding(12)
    .borderRadius(12)
    .backgroundColor($r('app.color.bg_card'))
    .alignItems(HorizontalAlign.Start)
    .justifyContent(FlexAlign.Center)
  }
}

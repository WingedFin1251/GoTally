// entry/src/main/ets/components/ui/Pager.ets
@Component
export struct Pager {
  @Prop page: number = 1;
  @Prop totalPages: number = 1;
  onPrev: () => void = () => {};
  onNext: () => void = () => {};

  build() {
    Row({ space: 10 }) {
      Button($r('app.string.prev'))
        .fontSize(12)
        .height(30)
        .backgroundColor(this.page > 1 ? $r('app.color.accent') : $r('app.color.divider'))
        .fontColor(this.page > 1 ? Color.White : $r('app.color.text_muted'))
        .enabled(this.page > 1)
        .onClick(() => this.onPrev())
      Text(`${this.page} / ${Math.max(1, this.totalPages)}`)
        .fontSize(12)
        .fontColor($r('app.color.text_muted'))
      Button($r('app.string.next'))
        .fontSize(12)
        .height(30)
        .backgroundColor(this.page < this.totalPages ? $r('app.color.accent') : $r('app.color.divider'))
        .fontColor(this.page < this.totalPages ? Color.White : $r('app.color.text_muted'))
        .enabled(this.page < this.totalPages)
        .onClick(() => this.onNext())
    }
    .width('100%')
    .justifyContent(FlexAlign.Center)
  }
}

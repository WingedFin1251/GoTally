// entry/src/main/ets/components/ui/QuotaProgress.ets
@Component
export struct QuotaProgress {
  @Prop label: string = '';
  @Prop percent: number = 0;
  @Prop remainingText: string = '';
  @Prop resetText: string = '';
  /** 金额明细（如 "$3.23 / $12.00"）；仅控制台接口提供，为空则隐藏。 */
  @Prop amountText: string = '';

  build() {
    Column({ space: 6 }) {
      Row() {
        Text(this.label).fontSize(13).fontColor($r('app.color.text_primary'))
        Blank()
        if (this.amountText !== '') {
          Text(this.amountText).fontSize(11).fontColor($r('app.color.text_muted')).margin({ right: 8 })
        }
        Text(`${this.percent.toFixed(1)}%`).fontSize(13).fontWeight(FontWeight.Bold)
      }
      .width('100%')

      Progress({ value: this.percent, total: 100, type: ProgressType.Linear })
        .width('100%')
        .color($r('app.color.accent'))
        .backgroundColor($r('app.color.quota_track'))
        .height(8)

      Row() {
        Text(`剩余 ${this.remainingText}`).fontSize(11).fontColor($r('app.color.text_muted'))
        Blank()
        Text(`重置 ${this.resetText}`).fontSize(11).fontColor($r('app.color.text_muted'))
      }
      .width('100%')
    }
    .width('100%')
    .padding(14)
    .borderRadius(12)
    .backgroundColor($r('app.color.bg_card'))
  }
}

// entry/src/main/ets/components/ui/SettingsCard.ets
@Component
export struct SettingsCard {
  @Prop title: ResourceStr = '';
  @BuilderParam content: () => void;

  build() {
    Column({ space: 2 }) {
      Text(this.title).fontSize(15).fontWeight(FontWeight.Bold).width('100%')
      this.content()
    }
    .width('100%')
    .padding(12)
    .borderRadius(12)
    .backgroundColor($r('app.color.bg_card'))
  }
}

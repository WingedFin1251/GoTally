// entry/src/main/ets/components/ui/SettingRow.ets
@Component
export struct SettingRow {
  // ResourceStr = string | Resource，兼容 $r() 资源与计算字符串
  @Prop title: ResourceStr = '';
  @Prop desc: ResourceStr = '';
  @BuilderParam content: () => void;

  build() {
    Row({ space: 10 }) {
      Column({ space: 2 }) {
        Text(this.title).fontSize(14).fontColor($r('app.color.text_primary'))
        if (this.desc !== '') {
          Text(this.desc).fontSize(11).fontColor($r('app.color.text_muted'))
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      this.content()
    }
    .width('100%')
    .padding({ top: 10, bottom: 10 })
  }
}

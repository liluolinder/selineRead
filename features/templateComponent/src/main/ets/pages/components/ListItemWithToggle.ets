import { LengthMetrics } from "@kit.ArkUI"

@ComponentV2
export struct ListItemWithToggle {
  @Param symbol: Resource | undefined = undefined
  @Param symbol1: Resource | undefined = undefined
  @Param message: ResourceStr = ''
  @Param toggleMessage: ResourceStr = ''
  @Param checked: boolean = false
  @Param type: ToggleType = ToggleType.Switch
  @Param tip:string|undefined = undefined
  @Local enable: boolean = this.checked
  @Param ensureMessage: ResourceStr | undefined = undefined
  @Event onChange: (checked: boolean) => void
  @Local showTip: boolean = false

  build() {
    Row({ space: 10 }) {
      Flex({
        justifyContent: FlexAlign.SpaceBetween,
        alignItems: ItemAlign.Center,
        space: { main: LengthMetrics.vp(10) }
      }) {
        Row({ space: 10 }) {
         if (this.symbol){
           SymbolGlyph(this.symbol)
             .fontSize(22)
             .fontColor([$r('sys.color.font')])
             .symbolEffect(new ReplaceSymbolEffect(EffectScope.WHOLE), Number(this.enable))
         }
         if (this.message){
           Text(this.message)
             .fontSize(17)
             .fontWeight(FontWeight.Medium)
             .maxLines(1)
             .textOverflow({ overflow: TextOverflow.MARQUEE })
             .fontColor($r('sys.color.font'))
         }

          if (this.tip) {
            SymbolGlyph($r('sys.symbol.questionmark_circle'))
              .fontSize(20)
              .fontColor([$r('sys.color.font')])
              .onClick(() => {
                this.showTip = true
              })
              .bindPopup(this.showTip!!, {
                message: this.tip
              })
          }

        }.layoutWeight(1)

        Toggle({ type: this.type, isOn: this.enable }) {
          if (this.type == ToggleType.Button) {
            Text(this.toggleMessage)
              .width('94%')
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.MARQUEE })
              .textAlign(TextAlign.Center)
          }
        }
        .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
        .onChange((checked: boolean) => {
          if (this.ensureMessage && checked) {
            this.getUIContext().showAlertDialog({
              title: this.message,
              message: this.ensureMessage,
              alignment: DialogAlignment.Center,
              primaryButton: {
                value: '知道了',
                fontColor: (AppStorage.get('themeColor') as string[])[AppStorage.get('currentColorMode') as number],
                action: () => {
                }
              },
              cornerRadius: 20,
              backgroundBlurStyle: BlurStyle.COMPONENT_THIN,
            })
          }
          this.enable = checked
          this.onChange(checked)
        })
        .selectedColor(this.type == ToggleType.Button?$r('sys.color.ohos_toggle_bg'): $r('[color].color.linder_blue'))
        .width (50)
        .height(30);
      }.align(Alignment.Center)

    }
    .height(55)
    .borderRadius(20)
    .padding({
      right: 15,
      left: 15,
      top: 10,
      bottom: 10
    })
  }
}
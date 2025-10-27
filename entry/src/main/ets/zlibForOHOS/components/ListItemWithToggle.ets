@ComponentV2
export struct ListItemWithToggle {
    @Param symbol: Resource | undefined = undefined
    @Param symbol1: Resource | undefined = undefined
    @Param message: ResourceStr = ''
    @Param checked: boolean = false
    @Local enable: boolean = this.checked
    @Param ensureMessage: ResourceStr | undefined = undefined
    @Event onChange: (checked: boolean) => void

    build() {
        Row() {
            Flex({ justifyContent: FlexAlign.SpaceBetween, alignItems: ItemAlign.Center }) {
                Row({ space: 10 }) {
                    SymbolGlyph(this.enable && this.symbol1 ? this.symbol1 : this.symbol)
                        .fontSize(22)
                        .fontColor([$r('sys.color.font')])
                        .symbolEffect(new ReplaceSymbolEffect(EffectScope.WHOLE), Number(this.enable))
                    Text(this.message)
                        .fontSize(17)
                        .fontWeight(FontWeight.Medium)
                        .maxLines(1)
                        .textOverflow({ overflow: TextOverflow.MARQUEE })
                        .layoutWeight(1)
                }.layoutWeight(1)

                Toggle({ type: ToggleType.Switch, isOn: this.enable })
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
                    .selectedColor($r('app.color.sweet_blue'))
                    .width(45)
                    .height(27);
            }.align(Alignment.Center)

        }.backgroundColor($r('sys.color.comp_background_list_card'))
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
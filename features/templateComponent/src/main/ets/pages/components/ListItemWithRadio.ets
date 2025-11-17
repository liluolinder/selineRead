@ComponentV2
export struct ListItemWithRadio {
  @Param symbol: Resource | undefined = undefined
  @Param symbol1: Resource | undefined = undefined
  @Param message: ResourceStr = ''
  @Param checked: boolean = false
  @Param index:number = -1
  @Param group:string = ''
  @Local enable: boolean = this.checked
  @Event onChange: (checked: boolean,index:number) => void

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

        Radio({ value:(this.message??'').toString(), group: this.group, })
          .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
            .checked($$this.enable)
          .onChange((checked: boolean) => {
            this.enable = checked
            this.onChange(checked,this.index)
          })
          .width(45)
          .height(27);
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
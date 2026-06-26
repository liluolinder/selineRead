@ComponentV2
export struct ListItemWithSelect {
  @Param symbol: Resource | undefined = undefined
  @Param message: ResourceStr = ''
  @Param selectArray:Array<SelectOption> = []
  @Param select:number = 0
  @Event onSelect:(index: number, value: string)=>void

  build() {
    Row({ space: 10 }) {
      Flex({
        justifyContent: FlexAlign.SpaceBetween,
        alignItems: ItemAlign.Center,
      }) {
        Row({ space: 10 }) {
         if (this.symbol)
         {
           SymbolGlyph( this.symbol)
             .fontSize(22)
             .symbolEffect(new ReplaceSymbolEffect(EffectScope.WHOLE))
         }

          Text(this.message)
            .fontSize(17)
            .fontWeight(FontWeight.Medium)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.MARQUEE })
            .layoutWeight(1)
        }.layoutWeight(1)

        Select(this.selectArray)
          .selected(this.select)
          .value(this.selectArray[this.select].value)
          .onSelect((index: number, value: string) => {
              this.onSelect(index, value)
          })
          .layoutWeight(1)
          .width(140)
      }
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
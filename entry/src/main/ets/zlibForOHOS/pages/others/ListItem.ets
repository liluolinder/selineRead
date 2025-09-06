@ComponentV2
export struct SettingsClickItem {
  @Param symbol: Resource | undefined = undefined
  @Param image: Resource | undefined = undefined
  @Param message: ResourceStr = ''
  @Param isVip: boolean = false
  @Param showArrow: boolean = true
  @Param isEnabled: boolean = true
  @Event onPress: () => void
  @Event onLongPress: () => void

  build() {
    Button({ type: ButtonType.Normal, stateEffect: true }) {

      Flex({ justifyContent: FlexAlign.SpaceBetween, alignItems: ItemAlign.Center }) {
        Row({ space: 10 }) {
          if (this.symbol) {
            SymbolGlyph(this.symbol)
              .fontSize(22)
              .fontColor([$r('sys.color.font')])
          }
          if (this.image) {

            Image(this.image)
              .size({ width: 30, height: 30 })
              .borderRadius(10)
              .draggable(false)
              .objectFit(ImageFit.Cover)
          }
          Text(this.message)
            .fontSize(17)
            .fontWeight(FontWeight.Medium)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.MARQUEE })
            .layoutWeight(1)
        }.layoutWeight(1)

        if (this.showArrow) {
          SymbolGlyph($r('sys.symbol.chevron_right'))
            .fontSize(22)
            .fontColor([$r('sys.color.font')])
            .margin(5)
            .fontWeight(FontWeight.Medium)
        }

      }.align(Alignment.Center)

    }
    .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.95 })
    .onClick(() => {
      this.onPress()

    })
    .gesture(LongPressGesture().onAction(() => {
      this.onLongPress()
    }))
    .backgroundColor($r('sys.color.comp_background_list_card'))
    .height(55)
    .borderRadius(20)
    .padding({
      right: 15,
      left: 15,
      top: 10,
      bottom: 10
    })
    .enabled(this.isEnabled)
  }
}

@ComponentV2
export struct ListItemWithText {
  @Param symbol: Resource | undefined = undefined
  @Param image: Resource | undefined = undefined
  @Param leftMessage: ResourceStr = ''
  @Param rightMessage: ResourceStr = ''
  @Param isEnabled: boolean = true
  @Param borderRadiusNum: number = 20
  @Event onPress: () => void
  @Event onLongPress: () => void

  build() {
    Button({ type: ButtonType.Normal, stateEffect: true }) {
      Flex({ justifyContent: FlexAlign.SpaceBetween, alignItems: ItemAlign.Center }) {
        Row({ space: 10 }) {
          if (this.symbol) {
            SymbolGlyph(this.symbol)
              .fontSize(22)
              .fontColor([$r('sys.color.font')])
          }
          if (this.image) {

            Image(this.image)
              .size({ width: 30, height: 30 })
              .borderRadius(10)
              .draggable(false)
              .objectFit(ImageFit.Cover)
          }
          Text(this.leftMessage)
            .fontSize(17)
            .fontWeight(FontWeight.Medium)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.MARQUEE })
            .layoutWeight(1)
        }.layoutWeight(1)

        Text(this.rightMessage)
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.MARQUEE })
          .layoutWeight(1)
          .textAlign(TextAlign.End)

      }.align(Alignment.Center)

    }
    .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.95 })
    .gesture(LongPressGesture().onAction(() => {
      this.onLongPress()
    }))
    .backgroundColor($r('sys.color.comp_background_list_card'))
    .height(55)
    .borderRadius(this.borderRadiusNum)
    .padding({
      right: 15,
      left: 15,
      top: 10,
      bottom: 10
    })
    .enabled(this.isEnabled)

  }
}
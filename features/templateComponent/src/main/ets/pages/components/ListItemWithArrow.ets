@ComponentV2
export struct ListItemWithArrow {
  @Param symbol: Resource | undefined = undefined
  @Param image: Resource | undefined = undefined
  @Param message: ResourceStr = ''
  @Param isVip: boolean = false
  @Param showArrow: boolean = true
  @Param isEnabled: boolean = true
  @Param isLarge: boolean = true
  @Param hasBackground: boolean = false
  @Param isHighlight: boolean = false
  @Param arrowDir:'up'|'down'|'right'|'left' ='left'

  changeArrowDir():ResourceStr{
    switch (this.arrowDir){
      case 'up':
        return  $r('sys.symbol.chevron_up')
      case 'down':
        return  $r('sys.symbol.chevron_down')
      case 'right':
        return  $r('sys.symbol.chevron_right')
      case 'left':
        return  $r('sys.symbol.chevron_left')
    }
  }

  build() {
    Button({ type: ButtonType.Normal, stateEffect: true }) {
      if (this.isLarge) {
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

        }
        .align(Alignment.Center)
        .backgroundColor(this.isHighlight ? $r('[color].color.linder_blue') : Color.Transparent)
        .borderRadius(18)
        .animation({ duration: 150 })
        .padding({
          right: 15,
          left: 15,
          top: 10,
          bottom: 10
        })
      } else {
        Stack() {
          if (this.symbol) {
            SymbolGlyph(this.symbol)
              .fontSize(22)
              .fontColor([$r('sys.color.font')]).geometryTransition(this.message+'message', {follow: true})

          }
          if (this.image) {
            Image(this.image)
              .size({ width: 30, height: 30 })
              .borderRadius(10)
              .draggable(false)
              .objectFit(ImageFit.Cover)

          }
        }
        .width('100%')
        .height('100%')
        .backgroundColor(this.isHighlight ? $r('[color].color.linder_blue') : Color.Transparent)
        .borderRadius(18)
        .animation({ duration: 150 })
      }

    }
    .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.95 })
    .height(this.isLarge ? 55 : 'auto')
    .width('100%')
    .aspectRatio(this.isLarge ? null : 1)
    .borderRadius(20)
    .enabled(this.isEnabled)
    .padding(2)
    .backgroundColor(Color.Transparent)

  }
}
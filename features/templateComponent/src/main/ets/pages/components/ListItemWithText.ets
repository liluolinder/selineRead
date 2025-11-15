@ComponentV2
export struct ListItemWithText {
    @Param symbol: Resource | undefined = undefined
    @Param image: Resource | undefined = undefined
    @Param leftMessage: ResourceStr = ''
    @Param rightMessage: ResourceStr = ''
    @Param isEnabled: boolean = true
    @Param borderRadiusNum: number = 20

    build() {
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

        }
        .align(Alignment.Center)
        .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.95 })
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
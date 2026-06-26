import { curves, LengthMetrics } from "@kit.ArkUI"


@ComponentV2
export struct ListItemWithInput {
  @Param symbol: Resource | undefined = undefined
  @Param image: Resource | undefined = undefined
  @Param message: ResourceStr = ''
  @Param isEnabled: boolean = true
  @Param placeholder: ResourceStr = ''
  @Param text: ResourceStr = ''
  @Param animationDelayIndex: number = 0
  @Event returnFunc: (returnText: string) => void;
  @Event onchange: (returnText: string) => void;

  build() {
    Row({ space: 10 }) {
      Flex({
        justifyContent: FlexAlign.SpaceBetween,
        alignItems: ItemAlign.Center,
        space: { main: LengthMetrics.vp(10) }
      }) {
        Row({ space: 10 }) {
          if (this.symbol) {
            SymbolGlyph(this.symbol)
              .fontSize(22)
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

        TextInput({ placeholder: this.placeholder, text: this.text })
          .layoutWeight(1)
          .width(140)
          .onSubmit((enterKey: EnterKeyType, event: SubmitEvent) => {
            this.returnFunc(event.text)
          })
          .onChange((value: string, previewText: PreviewText, options: TextChangeOptions)=>{
            this.onchange(value)
          })
          .textAlign(TextAlign.End)
      }
      .align(Alignment.Center)
      .enabled(this.isEnabled)
    }.height(55)
    .borderRadius(20)
    .padding({
      right: 15,
      left: 15,
      top: 10,
      bottom: 10
    })

  }
}
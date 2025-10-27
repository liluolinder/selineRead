import { curves } from "@kit.ArkUI"


@ComponentV2
export struct ListItemWithInput {
    @Param symbol: Resource | undefined = undefined
    @Param image: Resource | undefined = undefined
    @Param message: ResourceStr = ''
    @Param isEnabled: boolean = true
    @Param placeholder: ResourceStr = ''
    @Param animationDelayIndex: number = 0
    @Event returnFunc: (returnText: string) => void;

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
                Text(this.message)
                    .fontSize(17)
                    .fontWeight(FontWeight.Medium)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.MARQUEE })
                    .layoutWeight(1)
            }.layoutWeight(1)

            TextInput({ placeholder: this.placeholder })
                .layoutWeight(1)
                .width(140)
                .onChange((value: string) => {
                    this.returnFunc(value)
                })
                .backgroundColor('#00000000')
                .textAlign(TextAlign.End)

        }
        .align(Alignment.Center)
        .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.95 })
        .height(55)
        .borderRadius(20)
        .padding({
            right: 15,
            left: 15,
            top: 10,
            bottom: 10
        })
        .enabled(this.isEnabled)
        .borderRadius($r('sys.float.corner_radius_level12'))
        .transition(TransitionEffect.OPACITY.animation({ duration: 200, curve: Curve.Ease })
            .combine(TransitionEffect.translate({ x: 0, y: 20 })
                .combine(TransitionEffect.asymmetric(TransitionEffect.move(TransitionEdge.BOTTOM),
                    TransitionEffect.move(TransitionEdge.BOTTOM)))
                .animation({ curve: curves.responsiveSpringMotion(0.5, 0.85), delay: 120 * this.animationDelayIndex })))
    }
}
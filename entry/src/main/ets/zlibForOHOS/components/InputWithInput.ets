import { curves, LengthMetrics } from "@kit.ArkUI"


@ComponentV2
export struct InputWithInput {
    @Param isEnabled: boolean = true
    @Param leftPlaceholder: ResourceStr = ''
    @Param leftText: ResourceStr = ''
    @Param rightPlaceholder: ResourceStr = ''
    @Param rightText: ResourceStr = ''
    @Param animationDelayIndex: number = 0
    @Event leftReturnFunc: (returnText: string) => void;
    @Event rightReturnFunc: (returnText: string) => void;

    build() {

        Flex({
            justifyContent: FlexAlign.SpaceBetween,
            alignItems: ItemAlign.Center,
            space: { main: LengthMetrics.px(10) }
        }) {
            TextInput({ placeholder: this.leftPlaceholder, text: this.leftText })
                .layoutWeight(1)
                .width(140)
                .borderRadius(10)
                .onChange((value: string) => {
                    this.leftReturnFunc(value)
                })
                .backgroundColor($r('sys.color.comp_background_list_card'))

            TextInput({ placeholder: this.rightPlaceholder, text: this.rightText })
                .layoutWeight(1)
                .width(140)
                .borderRadius(10)
                .onChange((value: string) => {
                    this.rightReturnFunc(value)
                })
                .backgroundColor($r('sys.color.comp_background_list_card'))
        }
        .align(Alignment.Center)
        .height(48)
        .padding({
            right: 8,
            left: 8,
            top: 5,
            bottom: 5
        })
        .enabled(this.isEnabled)
    }
}
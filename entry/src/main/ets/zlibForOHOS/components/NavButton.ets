import { backgroundBlurModifier } from "../../main/ets/models/classes/backGroundEffect"

@ComponentV2
export struct NavButton{
  @Param @Require symbol: Resource
  @Param symbolSize: number = 22

  build() {
    Button({stateEffect: true, type: ButtonType.Circle}){
      SymbolGlyph(this.symbol).fontSize(this.symbolSize).fontColor([$r('sys.color.font')]).opacity(0.8)
    }.size({width: 40, height: 40})
    .backgroundColor(Color.Transparent)
    .attributeModifier(backgroundBlurModifier)
  }
}
import { backgroundBlurModifier } from "../../main/ets/models/classes/backGroundEffect"

@ComponentV2
export struct RoundButton{
  @Param @Require symbol: Resource
  @Param symbolSize: number = 22
  @Param hasShadow: boolean = true
  @Param buttonSize: number = 40

  build() {
    Button({stateEffect: true}){
      SymbolGlyph(this.symbol).fontSize(this.symbolSize).fontColor([$r('sys.color.font')]).opacity(0.9)
    }.size({width: this.buttonSize, height: this.buttonSize})
    .backgroundColor(Color.Transparent)
    .clickEffect({level: ClickEffectLevel.LIGHT, scale: 0.9})
    .attributeModifier(backgroundBlurModifier)
    .shadow({
      color: $r('app.color.shadow_color'),
      radius: this.hasShadow? 35: 0
    })
  }
}
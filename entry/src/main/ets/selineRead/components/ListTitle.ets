import { I_ListTitle } from "../models/interfaces/I_ListTitle"

@ComponentV2
export struct ListTitle {
  @Require @Param item: I_ListTitle
  @Local showTip: boolean = false

  build() {
    Row({ space: 5 }) {
      Text(this.item.title)
        .fontWeight(FontWeight.Bold)
      if (this.item.tip) {
        SymbolGlyph($r('sys.symbol.questionmark_circle'))
          .fontSize(20)
          .onClick(() => {
            this.showTip = true
          })
          .bindPopup(this.showTip!!, {
            message: this.item.tip
          })
      }
    }.width('100%')
  }
}
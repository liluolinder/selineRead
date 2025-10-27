@ComponentV2
export struct PlayingMenuItem {
  @Param symbol: Resource | undefined = undefined
  @Param message: ResourceStr | undefined = undefined
  @Param currentSelected: number = 0
  @Param isEnabled: boolean = true
  @Param list: ResourceStr[] = []
  @Event onSelected: (index: number) => void
  private scroller = new ListScroller()

  aboutToAppear(): void {
    setTimeout(()=>{
      this.scroller.scrollToIndex(this.currentSelected, false, ScrollAlign.CENTER)
    })
  }

  build() {
    Column({ space: 10 }) {
      Row({ space: 10 }) {
        SymbolGlyph(this.symbol)
          .fontSize(22)
          .fontColor([$r('sys.color.font')])
        Text(this.message)
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.MARQUEE })
          .layoutWeight(1)
      }

      List({ space: 10, scroller: this.scroller }) {
        ForEach(this.list, (item: string, index: number) => {
          ListItem() {
            Button({ type: ButtonType.Normal, stateEffect: true }) {
              Text(item)
                .fontSize(15)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.MARQUEE })
                .fontColor($r('sys.color.font'))
            }
            .enabled(this.isEnabled)
            .padding({ left: 12, right: 12 })
            .onClick(() => {
              this.scroller.scrollToIndex(index, true, ScrollAlign.CENTER)
              this.onSelected(index)
            })
            .height(45)
            .constraintSize({ maxWidth: '50%' })
            .borderRadius(10)
            .backgroundColor(this.currentSelected == index ? $r('app.color.list_item_background_highlight') :
              $r('sys.color.comp_background_secondary'))
            .animation({ duration: 150, curve: Curve.Ease })
          }
        })
      }
      .fadingEdge(true)
      .chainAnimation(true)
      .scrollBar(BarState.Off)
      .listDirection(Axis.Horizontal)
      .height(45)
    }
    .alignItems(HorizontalAlign.Start)
    .backgroundColor($r('sys.color.comp_background_list_card'))
    .borderRadius(20)
    .padding(15)
  }
}
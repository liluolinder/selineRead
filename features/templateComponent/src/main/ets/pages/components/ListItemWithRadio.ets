@ComponentV2
export struct ListItemWithRadio {
  @Param image: ResourceStr | undefined = undefined
  @Param message: ResourceStr = ''
  @Param messageColor:Resource|Color = $r('sys.color.font')
  @Param subMessage: ResourceStr = ''
  @Param subMessageColor:Resource|Color =$r('sys.color.font')
  @Param checked: boolean = false
  @Param index:number = -1
  @Param group:string = ''
  @Event onChange: (checked: boolean,index:number) => void

  build() {
    Row() {
      Flex({ justifyContent: FlexAlign.SpaceBetween, alignItems: ItemAlign.Center }) {
        Row({ space: 10 }) {

          if (this.image) {
            Image(this.image)
              .size({ width: 30, height: 30 })
              .borderRadius(10)
              .draggable(false)
              .objectFit(ImageFit.Cover)
          }
            Column({space:5}){
              Text(this.message)
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.MARQUEE })
                .width('100%')
            if (this.subMessage != ''){
              Text(this.subMessage)
                .fontSize(12)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.MARQUEE })
                .width('100%')
            }
            }.layoutWeight(1)
          .justifyContent(FlexAlign.Start)
        }.layoutWeight(1)

        Radio({ value:(this.message??'').toString(), group: this.group, })
          .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
          .checked($$this.checked)
          .onChange((checked: boolean) => {
            this.onChange(checked,this.index)
          })
          .height(20);
      }.align(Alignment.Center)

    }
    .height(55)
    .borderRadius(20)
    .padding({
      right: 15,
      left: 15,
      top: 10,
      bottom: 10
    })
  }
}
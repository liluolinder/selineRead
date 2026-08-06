import { curves, uiMaterial } from "@kit.ArkUI"
import { BasicDataSource, LFileKit, XAnimation, XContext } from "commonpackage"
import { BookArk } from "libohos_app_cangjie_entry.bookSource.so"
import { __BookSource__, __System__, __UI__ } from "../../commons/shareDatas"
import { FileKit } from "../../models/classes/FileKit"
import { loadingNewDialog } from "../../components/LoadingNewDialog"

@ObservedV2
export class BookSourceHomeData {
  @Trace inSearchMode: boolean = false
  @Trace canGetMore: boolean = true
  @Trace errorText: string = ''
  @Trace bookArray:BasicDataSource<BookArk> =
    new BasicDataSource<BookArk>()
  searchWord: string = ''
}

export const __BSHome__ = new BookSourceHomeData()


@ComponentV2
export struct BookSourceHome {

  @Local sourceIndex:number = 0
  @Local searchIndex:number = 1

  @Monitor("sourceIndex")
  onSourceIndexChange(){
    __BSHome__.bookArray.clearData()
    this.searchIndex = 1
  }

  aboutToAppear(): void {
    __BSHome__.bookArray.clearData()
    __BookSource__.parsers=[]
    FileKit.getBookSourceParser()
  }


  build() {
    Stack({ alignContent: Alignment.Top }) {
      Row({ space: 10 }) {

      if (!__BSHome__.inSearchMode && __BookSource__.parsers.length!=0 && __BookSource__.parsersSelection.length!=0){
        Select(__BookSource__.parsersSelection)
          .width("30%")
          .selected(this.sourceIndex!!)
          .value(__BookSource__.parsersSelection[this.sourceIndex].value)
      }

        Search({ value: __BSHome__.searchWord, })
          .searchButton(__BSHome__.inSearchMode ? $r('app.string.search') : undefined)
          .layoutWeight(1)
          .width(__BSHome__.inSearchMode ? '100%' : "60%")
          .focusable(__BSHome__.inSearchMode)
          .backgroundColor($r('app.color.start_window_background_blur'))
          .systemMaterial(new uiMaterial.ImmersiveMaterial({
            style: uiMaterial.ImmersiveStyle.REGULAR,
            interactive: true,
            lightEffect: { color: undefined },
          }))
          .useEffect(true)
          .onSubmit((value: string) => {
            XAnimation.runWithAnimation(() => {
              __BSHome__.inSearchMode = false
            })
            if (value != '') {
              __BSHome__.bookArray.clearData()
              __BSHome__.searchWord = value
              __BSHome__.canGetMore = false
              this.searchIndex = 1
              let parser = __BookSource__.parsers[this.sourceIndex]
              console.log(`meow:${parser.supportsPage||parser.supportsOffset}`)
              parser.search(value, parser.supportsPage||parser.supportsOffset? 1 :undefined,(books)=>{
                if (parser.supportsPage||parser.supportsOffset) {
                  this.searchIndex ++
                }
                if (books.length==0) {
                  XContext.alterDialogWithTwoButton({
                    title:"提示",
                    message:"返回值为空"
                  })
                }else {
                  books.forEach((ii)=>{
                    __BSHome__.bookArray.pushData(ii)
                  })
                }
                __BSHome__.canGetMore = true
              }, (err)=>{
                __BSHome__.canGetMore = true
                XContext.alterDialogWithTwoButton({
                  title:"错误",
                  message:err
                })
              })
            }

          })
          .onChange((value: string) => {
            if (value == '' || value == undefined) {
              XAnimation.runWithAnimation(() => {
                __BSHome__.searchWord = ''
              })
            } else {
              __BSHome__.searchWord = value
            }
          })
          .onTouch(() => {
            if (__BookSource__.parsers.length!=0) {
              XAnimation.runWithAnimation(() => {
                __BSHome__.inSearchMode = true
              })
            }else{
              XContext.alterDialogWithTwoButton({
                title: "Tips",
                message:"书源为空 不支持搜索"
              })
            }
          })
      }
      .zIndex(1)
      .justifyContent(FlexAlign.End)
      .width('100%')
      .padding({ top: Math.max(__System__.topRectHeight, 16), left: 16, right: 16 })
      .transition(XAnimation.getAnimation('up'))
      .zIndex(114514)

      Column() {
          if (__BSHome__.bookArray.totalCount()==0){
            if (!__BSHome__.canGetMore) {
              Column({ space: 10 }) {
                LoadingProgress()
                  .height(75)
                Text($r('app.string.Tip_GettingBookNow'))
                  .fontSize(22)
                  .fontWeight(FontWeight.Medium)
                  .textAlign(TextAlign.Center)
              }
              .height('100%')
              .justifyContent(FlexAlign.Center)
              .width('100%')
            } else {
              Text("请先搜索")
                .fontSize(24)
                .fontWeight(FontWeight.Medium)
            }
          }else{
            List({ space: 20 }) {
              LazyForEach(__BSHome__.bookArray, (item: BookArk) => {
                ListItem() {
                  BSHomeBookCover({data:item})
                }
                .width('100%')
                .onClick(()=>{
                  __UI__.mainPageStack.pushPathByName("BSBookInfo", item )
                })
                .transition(TransitionEffect.OPACITY
                  .combine(TransitionEffect.scale({ x: 0.5, y: 0.5 }))
                  .animation({ curve: curves.springMotion(0.5, 0.7) }))
              }, (item: BookArk, index: number) => JSON.stringify(item) + JSON.stringify(index))
            }
            .contentStartOffset(Math.max(__System__.topRectHeight, 16) + 64)
            .contentEndOffset(Math.max(__System__.bottomRectHeight,16) + 80)
            .alignSelf(ItemAlign.Center)
            .align(Alignment.Center)
            .edgeEffect(EdgeEffect.Spring)
            .lanes(2, 20)
            .height('100%')
            .width('100%')
            .padding({ left: 16, right: 16 })
            .onReachEnd(()=>{
              let parser = __BookSource__.parsers[this.sourceIndex]
              if (__BSHome__.searchWord != '' && (parser.supportsPage||parser.supportsOffset)) {
                __BSHome__.canGetMore = false
                parser.search(__BSHome__.searchWord, parser.supportsPage||parser.supportsOffset?this.searchIndex:undefined,(books)=>{
                  if (parser.supportsPage||parser.supportsOffset) {
                    this.searchIndex ++
                  }
                  if (books.length==0) {
                    XContext.alterDialogWithTwoButton({
                      title:"提示",
                      message:"返回值为空"
                    })
                  }else {
                    books.forEach((ii)=>{
                      __BSHome__.bookArray.pushData(ii)
                    })
                  }
                  __BSHome__.canGetMore = true
                }, (err)=>{
                  __BSHome__.canGetMore = true
                  XContext.alterDialogWithTwoButton({
                    title:"错误",
                    message:err
                  })
                })
              }
            })
          }
      }.size({ width: '100%', height: '100%' })
      .justifyContent(FlexAlign.Center)

      if (__BSHome__.inSearchMode) {
        Column()
          .size({ width: '100%', height: '100%' })
          .blur(50)
          .onClick(() => {
            XAnimation.runWithAnimation(() => {
              __BSHome__.inSearchMode = false
            })
          })
      }

    }.size({ width: '100%', height: '100%' })
  }
}

@ComponentV2
export struct BSHomeBookCover {
  @Param @Require data: BookArk
  @Param defaultImg: ResourceStr = $r('app.media.default_cover')
  @Param haveShadow: boolean = true
  @Param imageFit: ImageFit = ImageFit.Auto

  build() {
    Column({ space: 10 }) {
      Image(this.data.coverUrl ?? this.defaultImg)
        .alt(this.defaultImg)
        .transition(TransitionEffect.OPACITY)
        .objectFit(this.imageFit)
        .aspectRatio(3 / 4)
        .autoResize(true)
        .draggable(false)
        .clip(true)
        .borderRadius(15)
        .shadow({
          radius: 25,
          color: Color.Gray,
          offsetX: 0,
          offsetY: 10
        })

      Column({ space: 2 }) {
        Text(this.data.name)
          .fontSize(16)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.MARQUEE })
          .fontWeight(FontWeight.Medium)
          .width('100%')
        Text((this.data.author))
          .fontSize(12)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .opacity(0.6)
          .width('100%')
      }.alignItems(HorizontalAlign.Start)
    } .borderRadius(20)
    .padding(16)
    .backgroundColor($r('sys.color.comp_background_list_card'))
  }
}
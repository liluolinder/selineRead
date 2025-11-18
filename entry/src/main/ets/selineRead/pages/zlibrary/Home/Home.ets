import { curves, LengthMetrics, UIUtils } from "@kit.ArkUI"
import { BasicDataSource, XAnimation, XContext, XPreferencesManager } from "commonpackage"
import { min_width } from "../../../commons/commonItem"
import { __System__, __UI__ } from "../../../commons/shareDatas"
import { I_BookDetailedInfo, I_BookInfo } from "../../../models/interfaces/I_BookInfo"
import { http } from "@kit.NetworkKit"
import { zlibClient } from "../../../../zlibrary/zlibClient"
import { it } from "@ohos/hypium"
import { loadingDialog, loadingNewDialog } from "../../../components/LoadingNewDialog"
import { resourceManager } from "@kit.LocalizationKit"
import { I_searchBook } from "../../../../zlibrary/interface/I_SearchInfo"
import { I_SearchHistory } from "../../../models/interfaces/I_SearchHistory"


@ObservedV2
export class HomeData {
  @Trace inSearchMode: boolean = false
  @Trace canGetMore: boolean = false
  @Trace recommendBookIndex: number = 1
  @Trace searchBookIndex: number = 1
  @Trace errorText:string = ''

  req = http.createHttp()

  recommendBookArray: BasicDataSource<I_BookInfo> =
    new BasicDataSource<I_BookInfo>()

  searchBookArray: BasicDataSource<I_searchBook> =
    new BasicDataSource<I_searchBook>()

  @Trace searchHistory:I_SearchHistory[]=[]

}

export const __Home__ = new HomeData()

@ComponentV2
export struct Home {
  @Local TileColumnNumber: number = -1
  @Local columnNumber: number = 0
  @Local isOpenBook:boolean = false
  @Local recommendOrSearch:number = 0
  @Local searchWord:string =''
  
  build() {
    Stack({ alignContent: Alignment.Top }) {
      Row({ space: 10 }) {
        Search({ value: this.searchWord })
          .width(__Home__.inSearchMode ? '100%' : "45%")
          .focusable(__Home__.inSearchMode)
          .backgroundColor($r('app.color.start_window_background_blur'))
          .enableKeyboardOnFocus(this.recommendOrSearch==1)
          .backdropBlur(100)
          .useEffect(true)
          .layoutWeight(1)
          .onSubmit((value: string) => {
            XAnimation.runWithAnimation(() => {
              __Home__.inSearchMode = false
            })
            if (value != '') {
              this.recommendOrSearch = 1
              __Home__.req = http.createHttp()
              __Home__.searchBookArray.clearData()
              zlibClient.searchBook(__Home__.req,this.searchWord,__Home__.searchBookIndex).then((res) => {
                if (res[0] == 1) {
                  __Home__.recommendBookIndex ++
                  (JSON.parse(res[1]) as I_searchBook[]).forEach((item) => {
                    __Home__.searchBookArray.pushData(item)
                  })
                  __Home__.errorText = ''
                }else {
                  __Home__.errorText = res[1]
                }
                XAnimation.runWithAnimation(()=>{
                  __Home__.canGetMore = true
                })
              })
              __Home__.searchHistory =
                __Home__.searchHistory.filter((item: I_SearchHistory) => item.value != value)
              __Home__.searchHistory.unshift({ value: value, time: Date.parse(new Date().toString()) })
              XPreferencesManager.putPreferencesValue("selineRead", 'zlibSearchHistory',
                JSON.stringify( __Home__.searchHistory))
            }
          })
          .onChange((value: string) => {
            if (value == '' || value == undefined) {
              XAnimation.runWithAnimation(() => {
                this.searchWord = ''
                this.recommendOrSearch = 0
              })
            }else {
              this.searchWord = value
            }
          })
          .onTouch(() => {
            XAnimation.runWithAnimation(() => {
              __Home__.inSearchMode = true
            })
          })
      }
      .zIndex(1)
      .justifyContent(FlexAlign.End)
      .width('100%')
      .padding({ top: Math.max(__System__.topRectHeight, 16), left: 16, right: 16 })
      .transition(XAnimation.getAnimation('up'))
      .zIndex(114514)

      if ((this.recommendOrSearch == 0 && __Home__.recommendBookArray.totalCount() == 0) || ((this.recommendOrSearch == 1 && __Home__.searchBookArray.totalCount() == 0)))
      {
        Column({space:10}){
          LoadingProgress()
            .height(75)
          Text(__Home__.errorText == ''?$r('app.string.Tip_GettingBookNow'):XContext.getStringFromResource($r('app.string.Tip_GettingError'))+'\n'+__Home__.errorText)
            .fontSize(22)
            .fontWeight(FontWeight.Medium)
            .textAlign(TextAlign.Center)
        } .height('100%')
        .justifyContent(FlexAlign.Center)
        .width('100%')
      }else {
        List({space:20}) {
          if (this.recommendOrSearch == 0) {
            LazyForEach(__Home__.recommendBookArray, (item: I_BookInfo) => {
              ListItem() {
                HomeBookCover({data:item, type:0})
              }
              .onClick(async ()=>{
                if (!this.isOpenBook) {
                  XAnimation.runWithAnimation(()=>{
                    this.isOpenBook = true
                  })
                  let req = http.createHttp()
                  await zlibClient.getBookInfo(req,item.url).then((res)=>{
                    if (res[0]==1) {
                      __Home__.errorText = ''
                      let bookInfo:I_BookDetailedInfo = JSON.parse(res[1]) as I_BookDetailedInfo
                      bookInfo.bookID = item.id
                      bookInfo.href = item.url
                      __UI__.mainPageStack.pushPathByName("bookInfoPage",bookInfo)
                    }else {
                      __Home__.errorText = res[1]
                    }
                  })
                  XAnimation.runWithAnimation(()=>{
                    this.isOpenBook = false
                  })
                }
              })
              .width('100%')
              .borderRadius(20)
              .padding(16)
              .backgroundColor($r('sys.color.comp_background_list_card'))
              .transition(TransitionEffect.OPACITY
                .combine(TransitionEffect.scale({ x: 0.5, y: 0.5 }))
                .animation({ curve: curves.springMotion(0.5, 0.7) }))
            },(item: I_BookInfo) => JSON.stringify(item))
          }else {
            LazyForEach(__Home__.searchBookArray, (item: I_searchBook) => {
              ListItem() {
                HomeBookCover({data:item, type:1})
              }
              .onClick(async ()=>{
                if (!this.isOpenBook) {
                  XAnimation.runWithAnimation(()=>{
                    this.isOpenBook = true
                  })
                  let req = http.createHttp()
                  await zlibClient.getBookInfo(req,item.href).then((res)=>{
                    if (res[0]==1) {
                      __Home__.errorText = ''
                      let bookInfo:I_BookDetailedInfo = JSON.parse(res[1]) as I_BookDetailedInfo
                      bookInfo.bookID = Number(item.id)
                      bookInfo.href = item.href
                      __UI__.mainPageStack.pushPathByName("bookInfoPage",bookInfo)
                    }else {
                      __Home__.errorText = res[1]
                    }
                  })
                  XAnimation.runWithAnimation(()=>{
                    this.isOpenBook = false
                  })
                }
              })
              .width('100%')
              .borderRadius(20)
              .padding(16)
              .backgroundColor($r('sys.color.comp_background_list_card'))
              .transition(TransitionEffect.OPACITY
                .combine(TransitionEffect.scale({ x: 0.5, y: 0.5 }))
                .animation({ curve: curves.springMotion(0.5, 0.7) }))
            },(item: I_BookInfo) => JSON.stringify(item))
          }
        }
        .onAreaChange((_, newValue) => {
          XAnimation.runWithAnimation(() => {
            this.TileColumnNumber = Math.max(Math.ceil(new Number(newValue.width).valueOf() / 240), 2)
          }, this.TileColumnNumber > 0)
        })
        .onReachEnd( () => {
          __Home__.req = http.createHttp()
          if (__Home__.canGetMore) {
            XAnimation.runWithAnimation(()=>{
              __Home__.canGetMore = false
            })
            if (this.recommendOrSearch == 0) {
              zlibClient.getRecommendBook(__Home__.req, __Home__.recommendBookIndex).then((res) => {
                if (res[0] == 1) {
                  __Home__.recommendBookIndex ++
                  (JSON.parse(res[1]) as I_BookInfo[]).forEach((item) => {
                    __Home__.recommendBookArray.pushData(item)
                  })
                  __Home__.errorText = ''
                }else {
                  __Home__.errorText = res[1]
                }
                XAnimation.runWithAnimation(()=>{
                  __Home__.canGetMore = true
                })
              })
            }else {
              zlibClient.searchBook(__Home__.req,this.searchWord,__Home__.searchBookIndex).then((res) => {
                if (res[0] == 1) {
                  __Home__.recommendBookIndex ++
                  (JSON.parse(res[1]) as I_searchBook[]).forEach((item) => {
                    __Home__.searchBookArray.pushData(item)
                  })
                  __Home__.errorText = ''
                }else {
                  __Home__.errorText = res[1]
                }
                XAnimation.runWithAnimation(()=>{
                  __Home__.canGetMore = true
                })
              })

            }
          }
        })
        .contentStartOffset(Math.max(__System__.topRectHeight,16)+64)
        .alignSelf(ItemAlign.Center)
        .align(Alignment.Center)
        .edgeEffect(EdgeEffect.Spring)
        .lanes(this.TileColumnNumber,20)
        .height('100%')
        .width('100%')
        .padding({ left: 16, right: 16 })
      }

      if (__Home__.errorText != '' && __Home__.recommendBookArray.dataArray.length != 0) {
        Stack() {
          Column({ space: 10 }) {
            LoadingProgress().size({ width: 100, height: 100 })
            Text(XContext.getStringFromResource($r('app.string.Tip_GettingError'))+'\n'+__Home__.errorText).fontSize(20).fontWeight(FontWeight.Medium).textAlign(TextAlign.Center)
            Button('知道了')
              .backgroundColor($r('sys.color.button_background_color_transparent'))
              .fontColor($r('sys.color.font'))
              .padding({left:32,right:32})
              .onClick(()=>{
                __Home__.errorText = ''
              })
          }.borderRadius(20).padding(20).backgroundColor($r('app.color.start_window_background_blur')).backdropBlur(100)
        }
        .size({ width: '100%', height: '100%' })
        .padding(16)
        .backgroundColor($r('sys.color.comp_background_tertiary'))
        .transition(TransitionEffect.OPACITY.animation({ curve: Curve.Ease, duration: 300 }))
        .zIndex(114514)
      }

      if (this.isOpenBook)
      {
        loadingDialog()
      }

      if (!__Home__.canGetMore)
      {
        loadingNewDialog()
      }

      if (__Home__.inSearchMode) {
        Column()
          .size({ width: '100%', height: '100%' })
         .blur(50)
          .onClick(() => {
            XAnimation.runWithAnimation(() => {
              __Home__.inSearchMode = false
            })
          })
      }


      if (__Home__.inSearchMode) {
        Scroll() {
          Flex({ wrap: FlexWrap.Wrap, space: { main: LengthMetrics.vp(10), cross: LengthMetrics.vp(10) } }) {
            ForEach(__Home__.searchHistory, (item: I_SearchHistory) => {
              Button() {
                Row({ space: 10 }) {
                  Text(item.value.slice(0, 8) + (item.value.length > 8 ? '...' : '')).maxLines(1).fontSize(14)
                  Button() {
                    SymbolGlyph($r('sys.symbol.xmark')).fontColor([$r('sys.color.font')]).fontSize(15)
                  }.padding(5)
                  .backgroundColor(Color.Transparent)
                  .onClick(() => {
                    XAnimation.runWithAnimation(() => __Home__.searchHistory =
                      __Home__.searchHistory.filter((itemA: I_SearchHistory) => itemA.value != item.value))
                    XPreferencesManager.putPreferencesValue("selineRead", 'zlibSearchHistory',
                      JSON.stringify(__Home__.searchHistory))
                  })
                }
              }
              .padding({
                left: 10,
                right: 10,
                top: 5,
                bottom: 5
              })
              .backgroundColor($r('app.color.start_window_background_blur'))
              .onClick(() => {
                __Home__.searchBookIndex = 1
                this.searchWord = item.value
                __Home__.req = http.createHttp()
                __Home__.searchBookArray.clearData()
                zlibClient.searchBook(__Home__.req,this.searchWord,__Home__.searchBookIndex).then((res) => {
                  if (res[0] == 1) {
                    __Home__.recommendBookIndex ++
                    (JSON.parse(res[1]) as I_searchBook[]).forEach((item) => {
                      __Home__.searchBookArray.pushData(item)
                    })
                    __Home__.errorText = ''
                  }else {
                    __Home__.errorText = res[1]
                  }
                  XAnimation.runWithAnimation(()=>{
                    __Home__.canGetMore = true
                  })
                })
                XAnimation.runWithAnimation(() => {
                  this.recommendOrSearch = 1
                  __Home__.inSearchMode = false
                })
                __Home__.searchHistory =
                  __Home__.searchHistory.filter((itemA: I_SearchHistory) => itemA.value != item.value)
                __Home__.searchHistory.unshift({ value: item.value, time: Date.parse(new Date().toString()) })
                XPreferencesManager.putPreferencesValue("selineRead", 'zlibSearchHistory',
                  JSON.stringify( __Home__.searchHistory))
                console.log( JSON.stringify( __Home__.searchHistory))
              })
            })

            if (__Home__.searchHistory.length > 0) {
              Button() {
                SymbolGlyph($r('sys.symbol.trash')).fontColor([$r('sys.color.font')]).fontSize(15)
              }
              .padding(9)
              .backgroundColor($r('app.color.start_window_background_blur'))
              .onClick(() => {
                XAnimation.runWithAnimation(() => __Home__.searchHistory = [])
                XPreferencesManager.putPreferencesValue("selineRead", 'zlibSearchHistory',
                  JSON.stringify(__Home__.searchHistory))
              })
            }
          }.padding({ bottom: 10 })
        }
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
        .transition(XAnimation.getAnimation('bottom'))
        .margin({
          top: __System__.topRectHeight + 60,
          left: 16,
          right: 16,
        })
        .zIndex(114513)
      }
    }.size({ width: '100%', height: '100%' })
  }
}




@ComponentV2
export struct HomeBookCover {
  @Param @Require data: I_BookInfo | I_searchBook
  @Param defaultImg: ResourceStr = $r('app.media.default_cover')
  @Param haveShadow: boolean = true
  @Param imageFit: ImageFit = ImageFit.Auto
  @Param type:number = 0
  @Local private isFinish: boolean = false

  build() {
    Column({ space: 10 }) {
      Stack() {
        Image((this.type == 0?(this.data as I_BookInfo).cover:(this.data as I_searchBook).image) ?? this.defaultImg)
          .transition(TransitionEffect.OPACITY)
          .objectFit(this.imageFit)
          .aspectRatio(2/3)
          .autoResize(true)
          .onComplete((res) => {
            if(res?.width && res?.width > 0 && res?.height && res?.height > 0) this.isFinish = true
          })
        if(!this.isFinish){
          Image(this.defaultImg)
            .transition(TransitionEffect.OPACITY.animation({duration: 150, curve: Curve.Ease}))
            .objectFit(this.imageFit)
            .aspectRatio(2/3)
            .autoResize(true)
        }
      }.aspectRatio(2/3)
      .clip(true)
      .borderRadius(15)
      .shadow({
        radius: 25,
        color: Color.Gray,
        offsetX: 0,
        offsetY: 10
      })

      Column({ space: 2 }) {
        Text(this.data.title)
          .fontSize(16)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.MARQUEE }).fontWeight(FontWeight.Medium)
          .width('100%')
        Text((this.type == 0?(this.data as I_BookInfo).author:(this.data as I_searchBook).writer))
          .fontSize(12)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis }).opacity(0.6)
          .width('100%')
      }.alignItems(HorizontalAlign.Start)
    }

  }
}


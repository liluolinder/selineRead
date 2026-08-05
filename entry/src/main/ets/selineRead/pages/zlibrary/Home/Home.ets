import { curves, LengthMetrics, uiMaterial, } from '@kit.ArkUI'
import { BasicDataSource, XAnimation, XContext, XPreferencesManager } from 'commonpackage'
import { __Setting__, __System__, __UI__, __ZlibUser__ } from '../../../commons/shareDatas'
import { http } from '@kit.NetworkKit'
import { loadingDialog, loadingNewDialog } from '../../../components/LoadingNewDialog'
import { I_SearchHistory } from '../../../models/interfaces/I_SearchHistory'
import { ZlibBookInfoBriefArk } from 'libohos_app_cangjie_entry.zlib4cj.so'
import { I_BookInfoParam } from '../../../models/interfaces/I_BookInfoParam'


@ObservedV2
export class ZlibHomeData {
  @Trace inSearchMode: boolean = false
  @Trace canGetMore: boolean = false
  @Trace recommendBookIndex: number = 1
  @Trace searchBookIndex: number = 1
  @Trace errorText: string = ''
  @Trace recommendOrSearch: number = 0
  @Trace searchWord: string = ''
  @Trace recommendBookArray: BasicDataSource<ZlibBookInfoBriefArk> =
    new BasicDataSource<ZlibBookInfoBriefArk>()
  @Trace searchBookArray: BasicDataSource<ZlibBookInfoBriefArk> =
    new BasicDataSource<ZlibBookInfoBriefArk>()
  @Trace searchHistory: I_SearchHistory[] = []
  @Trace showType:number = 0  //0为瀑布 1为列表

  @Trace TileColumnNumber: number = -1
  
  listWidth:Length = 0

  @Monitor("showType")
  changeColumnNumber(){
    XAnimation.runWithAnimation(() => {
      if (__ZlibHome__.showType == 0) {
        __ZlibHome__.TileColumnNumber = Math.max(Math.ceil(new Number(this.listWidth).valueOf() / 240), 2)
      }else {
        __ZlibHome__.TileColumnNumber = Math.max(Math.ceil(new Number(this.listWidth).valueOf() / 380), 1)
      }

    }, __ZlibHome__.TileColumnNumber > 0)
  }
}

export const __ZlibHome__ = new ZlibHomeData()

@ComponentV2
export struct ZlibHome {
  private openBook(item:ZlibBookInfoBriefArk){
    console.log(`meow   id:${item.id}   hash:${item.hash}`)
    let param:I_BookInfoParam = {
      type: 0,
      data:item
    }
    __UI__.mainPageStack.pushPathByName("bookInfoPage", param )
  }

  build() {
    Stack({ alignContent: Alignment.Top }) {
      Row({ space: 10 }) {
        Button({ type: ButtonType.Circle }) {
          SymbolGlyph(__ZlibHome__.showType == 0 ? $r('sys.symbol.square_grid_2x2') : $r('sys.symbol.list_bullet_square'))
            .fontSize(24)
            .fontColor([$r('sys.color.font_secondary')])
        }
        .width(40)
        .height(40)
        .backgroundColor($r('app.color.start_window_background_blur'))
        .systemMaterial(new uiMaterial.ImmersiveMaterial({
          style: uiMaterial.ImmersiveStyle.REGULAR,
          interactive:true,
          lightEffect: { color: undefined },
        }))
        .useEffect(true)
        .onClick(() => {
          XAnimation.runWithAnimation(()=>{
            __ZlibHome__.showType = __ZlibHome__.showType == 0 ? 1 :0
            XPreferencesManager.putPreferencesValue('selineRead', "showType", __ZlibHome__.showType)
          })
        })
        .visibility(__ZlibHome__.inSearchMode ? Visibility.None : Visibility.Visible)

        Search({ value: __ZlibHome__.searchWord, })
          .searchButton(__ZlibHome__.inSearchMode ? $r('app.string.search') : undefined)
          // .width(__Home__.inSearchMode ? '100%' : "45%")
          .layoutWeight(1)
          .focusable(__ZlibHome__.inSearchMode)
          .backgroundColor($r('app.color.start_window_background_blur'))
          .enableKeyboardOnFocus(__ZlibHome__.recommendOrSearch == 1)
          .systemMaterial(new uiMaterial.ImmersiveMaterial({
            style: uiMaterial.ImmersiveStyle.REGULAR,
            interactive:true,
            lightEffect: { color: undefined },
          }))
          .useEffect(true)
          .onSubmit((value: string) => {
            XAnimation.runWithAnimation(() => {
              __ZlibHome__.inSearchMode = false
            })
            if (value != '') {
              __ZlibHome__.recommendOrSearch = 1
              __ZlibHome__.searchBookArray.clearData()
              __ZlibHome__.searchWord = value
              __ZlibHome__.searchBookIndex = 1
              __ZlibUser__.zlibClient.search((__ZlibHome__.searchWord), __ZlibHome__.searchBookIndex,(books)=>{
                console.log(JSON.stringify(books))
                if (books.length!=0) {
                  __ZlibHome__.searchBookIndex++
                 books.forEach((book)=>{
                   __ZlibHome__.searchBookArray.pushData(book)
                 })

                }else {
                  __ZlibHome__.errorText = '返回值空'
                }

                XAnimation.runWithAnimation(() => {
                  __ZlibHome__.canGetMore = true
                })
              },(error)=>{
                console.log(error)
                __ZlibHome__.errorText = error
              })

              __ZlibHome__.searchHistory =
                __ZlibHome__.searchHistory.filter((item: I_SearchHistory) => item.value != value)
              __ZlibHome__.searchHistory.unshift({ value: value, time: Date.parse(new Date().toString()) })
              XPreferencesManager.putPreferencesValue("selineRead", 'zlibSearchHistory',
                JSON.stringify(__ZlibHome__.searchHistory))
            }
          })
          .onChange((value: string) => {
            if (value == '' || value == undefined) {
              XAnimation.runWithAnimation(() => {
                __ZlibHome__.searchWord = ''
                __ZlibHome__.recommendOrSearch = 0
              })
            } else {
              __ZlibHome__.searchWord = value
            }
          })
          .onTouch(() => {
            XAnimation.runWithAnimation(() => {
              __ZlibHome__.inSearchMode = true
            })
          })


      }
      .zIndex(1)
      .justifyContent(FlexAlign.End)
      .width('100%')
      .padding({ top: Math.max(__System__.topRectHeight, 16), left: 16, right: 16 })
      .transition(XAnimation.getAnimation('up'))
      .zIndex(114514)

      if ((__ZlibHome__.recommendOrSearch == 0 && __ZlibHome__.recommendBookArray.totalCount() == 0) ||
        ((__ZlibHome__.recommendOrSearch == 1 && __ZlibHome__.searchBookArray.totalCount() == 0))) {
        Column({ space: 10 }) {
          LoadingProgress()
            .height(75)
          Text(__ZlibHome__.errorText == '' ? $r('app.string.Tip_GettingBookNow') :
            XContext.getStringFromResource($r('app.string.Tip_GettingError')) + '\n' + __ZlibHome__.errorText)
            .fontSize(22)
            .fontWeight(FontWeight.Medium)
            .textAlign(TextAlign.Center)
        }.height('100%')
        .justifyContent(FlexAlign.Center)
        .width('100%')
      } else {
        List({ space: 20 }) {
          if (__ZlibHome__.recommendOrSearch == 0) {
            LazyForEach(__ZlibHome__.recommendBookArray, (item: ZlibBookInfoBriefArk) => {
              ListItem() {
                if (__ZlibHome__.showType == 0) {
                  HomeBookCover({ data: item })
                }else {
                  HomeListBookCover({ data: item })
                }
              }
              .onClick(async () => {
                  this.openBook(item)
              })
              .width('100%')
              .transition(TransitionEffect.OPACITY
                .combine(TransitionEffect.scale({ x: 0.5, y: 0.5 }))
                .animation({ curve: curves.springMotion(0.5, 0.7) }))
            }, (item: ZlibBookInfoBriefArk, index: number) => JSON.stringify(item) + JSON.stringify(index))
          } else {
            LazyForEach(__ZlibHome__.searchBookArray, (item: ZlibBookInfoBriefArk) => {
              ListItem() {
                if (__ZlibHome__.showType == 0) {
                  HomeBookCover({ data: item })
                }else {
                  HomeListBookCover({ data: item })
                }
              }
              .onClick(async () => {
                this.openBook(item)
              })
              .width('100%')
              .transition(TransitionEffect.OPACITY
                .combine(TransitionEffect.scale({ x: 0.5, y: 0.5 }))
                .animation({ curve: curves.springMotion(0.5, 0.7) }))
            }, (item: ZlibBookInfoBriefArk, index: number) => JSON.stringify(item) + JSON.stringify(index))
          }
        }
        .onAreaChange((_, newValue) => {
          __ZlibHome__.listWidth = newValue.width
          XAnimation.runWithAnimation(() => {
            if (__ZlibHome__.showType == 0) {
              __ZlibHome__.TileColumnNumber = Math.max(Math.ceil(new Number(newValue.width).valueOf() / 240), 2)
            }else {
              __ZlibHome__.TileColumnNumber = Math.max(Math.ceil(new Number(newValue.width).valueOf() / 380), 1)
            }

          }, __ZlibHome__.TileColumnNumber > 0)
        })
        .onReachEnd(() => {
          if (__ZlibHome__.canGetMore) {
            if (__ZlibHome__.recommendOrSearch == 1) {
              XAnimation.runWithAnimation(() => {
                __ZlibHome__.canGetMore = false
              })

              __ZlibUser__.zlibClient.search((__ZlibHome__.searchWord), __ZlibHome__.searchBookIndex,(books)=>{

                if (books.length!=0) {
                  __ZlibHome__.searchBookIndex ++
                  books.forEach((book)=>{
                    __ZlibHome__.searchBookArray.pushData(book)
                  })

                }else {
                  __ZlibHome__.errorText = '返回值空'
                }

                XAnimation.runWithAnimation(() => {
                  __ZlibHome__.canGetMore = true
                })
              },(error)=>{
                __ZlibHome__.errorText = error
              })

            }
          }
        })
        .contentStartOffset(Math.max(__System__.topRectHeight, 16) + 64)
        .contentEndOffset(Math.max(__System__.bottomRectHeight,16) + 80)
        .alignSelf(ItemAlign.Center)
        .align(Alignment.Center)
        .edgeEffect(EdgeEffect.Spring)
        .lanes(__ZlibHome__.TileColumnNumber, 20)
        .height('100%')
        .width('100%')
        .padding({ left: 16, right: 16 })
      }

      if (__ZlibHome__.errorText != '' && __ZlibHome__.recommendBookArray.dataArray.length != 0) {
        Stack() {
          Column({ space: 10 }) {
            LoadingProgress().size({ width: 100, height: 100 })
            Text(XContext.getStringFromResource($r('app.string.Tip_GettingError')) + '\n' + __ZlibHome__.errorText)
              .fontSize(20)
              .fontWeight(FontWeight.Medium)
              .textAlign(TextAlign.Center)
            Button('知道了')
              .backgroundColor($r('sys.color.button_background_color_transparent'))
              .fontColor($r('sys.color.font'))
              .padding({ left: 32, right: 32 })
              .onClick(() => {
                __ZlibHome__.errorText = ''
              })
          }.borderRadius(20).padding(20).backgroundColor($r('app.color.start_window_background_blur')).backdropBlur(100)
        }
        .size({ width: '100%', height: '100%' })
        .padding(16)
        .backgroundColor($r('sys.color.comp_background_tertiary'))
        .transition(TransitionEffect.OPACITY.animation({ curve: Curve.Ease, duration: 300 }))
        .zIndex(114514)
      }

      if (!__ZlibHome__.canGetMore) {
        loadingNewDialog()
      }


      if (__ZlibHome__.inSearchMode) {
        Column()
          .size({ width: '100%', height: '100%' })
          .blur(50)
          .onClick(() => {
            XAnimation.runWithAnimation(() => {
              __ZlibHome__.inSearchMode = false
            })
          })
      }

      if (__ZlibHome__.inSearchMode) {
        Scroll() {
          Flex({ wrap: FlexWrap.Wrap, space: { main: LengthMetrics.vp(10), cross: LengthMetrics.vp(10) } }) {
            ForEach(__ZlibHome__.searchHistory, (item: I_SearchHistory) => {
              Button() {
                Row({ space: 10 }) {
                  Text(item.value.slice(0, 8) + (item.value.length > 8 ? '...' : '')).maxLines(1).fontSize(14)
                  Button() {
                    SymbolGlyph($r('sys.symbol.xmark')).fontColor([$r('sys.color.font')]).fontSize(15)
                  }.padding(5)
                  .backgroundColor(Color.Transparent)
                  .onClick(() => {
                    XAnimation.runWithAnimation(() => __ZlibHome__.searchHistory =
                      __ZlibHome__.searchHistory.filter((itemA: I_SearchHistory) => itemA.value != item.value))
                    XPreferencesManager.putPreferencesValue("selineRead", 'zlibSearchHistory',
                      JSON.stringify(__ZlibHome__.searchHistory))
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
                __ZlibHome__.searchWord = item.value
                __ZlibHome__.searchBookArray.clearData()
                __ZlibHome__.searchBookIndex = 1

                __ZlibUser__.zlibClient.search((__ZlibHome__.searchWord), __ZlibHome__.searchBookIndex,(books)=>{

                  if (books.length!=0) {
                    __ZlibHome__.searchBookIndex++
                    books.forEach((book)=>{
                      __ZlibHome__.searchBookArray.pushData(book)
                    })

                  }else {
                    __ZlibHome__.errorText = '返回值空'
                  }

                  XAnimation.runWithAnimation(() => {
                    __ZlibHome__.canGetMore = true
                  })
                },(error)=>{
                  __ZlibHome__.errorText = error
                })

                XAnimation.runWithAnimation(() => {
                  __ZlibHome__.recommendOrSearch = 1
                  __ZlibHome__.inSearchMode = false
                })
                __ZlibHome__.searchHistory =
                  __ZlibHome__.searchHistory.filter((itemA: I_SearchHistory) => itemA.value != item.value)
                __ZlibHome__.searchHistory.unshift({ value: item.value, time: Date.parse(new Date().toString()) })
                XPreferencesManager.putPreferencesValue("selineRead", 'zlibSearchHistory',
                  JSON.stringify(__ZlibHome__.searchHistory))
              })
              .systemMaterial(new uiMaterial.ImmersiveMaterial({
                style: uiMaterial.ImmersiveStyle.REGULAR,
                interactive:true,
                lightEffect: { color: undefined },
                applyShadow:false
              }))
            })

            if (__ZlibHome__.searchHistory.length > 0) {
              Button() {
                SymbolGlyph($r('sys.symbol.trash')).fontColor([$r('sys.color.font')]).fontSize(15)
              }
              .padding(9)
              .backgroundColor($r('app.color.start_window_background_blur'))
              .systemMaterial(new uiMaterial.ImmersiveMaterial({
                style: uiMaterial.ImmersiveStyle.REGULAR,
                interactive:true,
                lightEffect: { color: undefined },
                applyShadow:false
              }))
              .onClick(() => {
                XAnimation.runWithAnimation(() => __ZlibHome__.searchHistory = [])
                XPreferencesManager.putPreferencesValue("selineRead", 'zlibSearchHistory',
                  JSON.stringify(__ZlibHome__.searchHistory))
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
  @Param @Require data: ZlibBookInfoBriefArk
  @Param defaultImg: ResourceStr = $r('app.media.default_cover')
  @Param haveShadow: boolean = true
  @Param imageFit: ImageFit = ImageFit.Auto
  @Local private isFinish: boolean = false

  build() {
    Column({ space: 10 }) {
      Stack() {
        Image(this.data.cover ?? this.defaultImg)
          .transition(TransitionEffect.OPACITY)
          .objectFit(this.imageFit)
          .aspectRatio(2 / 3)
          .autoResize(true)
          .draggable(false)
          .onComplete((res) => {
            if (res?.width && res?.width > 0 && res?.height && res?.height > 0) {
              this.isFinish = true
            }
          })
        if (!this.isFinish) {
          Image(this.defaultImg)
            .transition(TransitionEffect.OPACITY.animation({ duration: 150, curve: Curve.Ease }))
            .objectFit(this.imageFit)
            .aspectRatio(2 / 3)
            .autoResize(true)
            .draggable(false)
        }
      }.aspectRatio(2 / 3)
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

@ComponentV2
export struct HomeListBookCover{
  @Param @Require data: ZlibBookInfoBriefArk
  @Param defaultImg: ResourceStr = $r('app.media.default_cover')
  @Param haveShadow: boolean = true
  @Param imageFit: ImageFit = ImageFit.Auto
  @Local private isFinish: boolean = false

  build() {
    Row({ space: 10 }){
      Stack() {
        Image(this.data.cover ?? this.defaultImg)
          .transition(TransitionEffect.OPACITY)
          .objectFit(this.imageFit)
          .aspectRatio(2 / 3)
          .autoResize(true)
          .draggable(false)
          .onComplete((res) => {
            if (res?.width && res?.width > 0 && res?.height && res?.height > 0) {
              this.isFinish = true
            }
          })
        if (!this.isFinish) {
          Image(this.defaultImg)
            .transition(TransitionEffect.OPACITY.animation({ duration: 150, curve: Curve.Ease }))
            .objectFit(this.imageFit)
            .aspectRatio(2 / 3)
            .autoResize(true)
            .draggable(false)
        }
      }.aspectRatio(2 / 3)
      .clip(true)
      .shadow({
        radius: 25,
        color: Color.Gray,
        offsetX: 0,
        offsetY: 10
      })

      Column({ space: 5 }) {
        Text(this.data.title)
          .fontWeight(FontWeight.Medium)
          .fontSize(16)
          .width('100%')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.MARQUEE })

        Text(this.data.author)
          .fontWeight(FontWeight.Normal)
          .fontSize(14)
          .width('100%')
          .maxLines(1)
          .opacity(0.8)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }.height('100%')
      .layoutWeight(1)
    }.height(120)
    .width('100%')
    .borderRadius(20)
    .padding(16)
    .backgroundColor($r('sys.color.comp_background_list_card'))
  }
}

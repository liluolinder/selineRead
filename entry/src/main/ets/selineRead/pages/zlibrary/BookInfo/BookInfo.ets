import { XAnimation, XContext } from 'commonpackage'
import { __System__ } from '../../../commons/shareDatas'
import { __CustomBackgroundData__ } from '../../../components/CustomBackground'
import { DividerTmp } from '../../../models/classes/DividerTmp'
import { SymbolGlyphModifier } from '@kit.ArkUI'
import { min_width } from '../../../commons/commonItem'
import { BigImage } from '../../../components/BigImage'
import { ListItemWithText } from 'templatecomponent'
import { download, ZlibBookInfoArk } from 'libohos_app_cangjie_entry.so'
import url from '@ohos.url'

@Builder
export function BookInfoBuilder() {
  BookInfo()
}

@ComponentV2
export struct BookInfo {
  pageInfos: NavPathStack = new NavPathStack()
  @Local errorText: string = ''
  @Local bookInfo: ZlibBookInfoArk | undefined = undefined
  @Local isShowDownloadMenu: boolean = false
  @Local egDivider: DividerTmp = new DividerTmp(0.5, 10, 10, '#ffd6d4d4')
  @Local pageWidth: number = -1
  @Local isViewingBigImage: boolean = false
  @Local pageOpacity: number = 0
  @Local showComment: boolean = false
  @Local showOnlineRead: boolean = false
  @Local isOpening: boolean = false
  @Local isFlashing: boolean = false
  recommendPage: number = 1
  commitPage: number = 1

  /*  @Builder
    commentPageBuilder() {
      Column() {
        List({ space: 10 }) {
          LazyForEach(zlibClient.bookCommentArray, (item: I_BookComment) => {
            ListItem() {
              Column({ space: 6 }) {
                Row({ space: 6 }) {
                  if (item.user.avatar.length == 0) {
                    Stack() {
                      SymbolGlyph($r('sys.symbol.person')).fontColor([$r('sys.color.font')]).fontSize(16)
                    }
                    .size({ width: 24, height: 24 })
                    .backgroundColor($r('sys.color.comp_background_gray'))
                    .borderRadius('50%')
                    .opacity(0.7)
                  } else {
                    Image(item.user.avatar).size({ width: 24, height: 24 }).borderRadius('50%').clip(true)
                  }
                  Text(item.user.name).fontSize(18).fontWeight(FontWeight.Medium).opacity(0.8)
                }

                Text(item.text).fontSize(17)
                Text(item.date).width('100%').textAlign(TextAlign.End).fontSize(10).opacity(0.5)
              }.alignItems(HorizontalAlign.Start).width('100%')
            }
            .width('100%')
            .padding({
              left: 15,
              right: 15,
              top: 10,
              bottom: 10
            })
            .transition(TransitionEffect.OPACITY
              .combine(TransitionEffect.scale({ x: 0.5, y: 0.5 }))
              .animation({ curve: curves.springMotion(0.5, 0.7) }))
            .backgroundColor($r('sys.color.comp_background_list_card'))
            .borderRadius(20)
          })
        }
        .onScrollStart(()=>{
          setTimeout(()=>{
            __UI__.hideBars()
          }, 50)
        })
        .layoutWeight(1)
        .contentEndOffset(16)
        .chainAnimation(true)
        .clip(true)
        .borderRadius({ topLeft: 20, topRight: 20 })
        .margin({ left: 16, right: 16 })
        .scrollBar(BarState.Off)
        .onReachEnd(() => {
          zlibClient.getBookCommit(this.bookInfo?.bookID?.toString()!, this.commitPage + 1).then((get) => {
            if (get) {
              this.commitPage++
            }
          })
        })
      }.size({ width: '100%', height: '100%' })
    }*/

  build() {
    NavDestination() {
      if (this.isViewingBigImage) {
        BigImage({
          image: this.bookInfo?.cover
        })
          .zIndex(114514)
      } else {
        Stack() {
          Scroll() {
            Column() {
              List({ space: 10 }) {
                ListItem() {
                  Row({ space: 20 }) {
                    BookCover({ data: this.bookInfo?.cover })
                      .transition(TransitionEffect.OPACITY)
                      .geometryTransition('image')
                      .size({ height: 160, width: 116 })
                      .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
                      .onClick(() => {
                        XAnimation.runWithAnimation(() => this.isViewingBigImage = true, true, 0.4, 0.85)
                      })

                    Column({ space: 5 }) {
                      Text(this.bookInfo?.title)
                        .fontWeight(FontWeight.Bold)
                        .fontSize(24)
                        .maxLines(3)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                      Text(this.bookInfo?.author)
                      .maxLines(3)
                      .fontSize(18)
                      .opacity(0.6)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })

                    }.alignItems(HorizontalAlign.Start).layoutWeight(1)

                  }.padding(16).justifyContent(FlexAlign.SpaceBetween).width('100%')

                }
                .backgroundColor(__CustomBackgroundData__.customBackground && __System__.windowWidth > min_width ?
                $r('app.color.start_window_background_blur') : $r('sys.color.comp_background_list_card'))
                .backdropBlur(__CustomBackgroundData__.customBackground && __System__.windowWidth > min_width ? 100 :
                  undefined)
                .useEffect(true)
                .size({ width: '100%', height: 200 })
                .borderRadius(20)
                .transition(XAnimation.getAnimation('bottom', 50))

                ListItem() {
                  Stack({ alignContent: Alignment.Top }) {
                    Scroll() {
                      Row() {
                        Text(this.bookInfo?.description == '' ? '暂无简介' :
                        this.bookInfo?.description
                          .replaceAll("&lt;br&gt;", "")
                          .replaceAll("&lt;p&gt;", "")
                          .replaceAll("&lt;/p&gt;", "")
                        )
                          .fontWeight(FontWeight.Normal)
                          .fontSize(16)
                          .size({ width: '100%' })
                      }.size({ width: '100%' })

                    }
                    .edgeEffect(EdgeEffect.Spring)
                    .scrollBar(BarState.Off)
                    .fadingEdge(true)
                  }.constraintSize({ maxHeight: 200, minHeight: this.pageWidth > min_width ? 200 : 0 }).padding(16)
                }
                .borderRadius(20)
                .backgroundColor(__CustomBackgroundData__.customBackground && __System__.windowWidth > min_width ?
                $r('app.color.start_window_background_blur') : $r('sys.color.comp_background_list_card'))
                .backdropBlur(__CustomBackgroundData__.customBackground && __System__.windowWidth > min_width ? 100 :
                  undefined)
                .useEffect(true)
                .width('100%')
                .transition(XAnimation.getAnimation('bottom', 100))

                ListItemGroup() {
                  ListItemWithText({
                    leftMessage: $r('app.string.Text_Rate'),
                    rightMessage: this.bookInfo?.interestScore
                  })

                  ListItemWithText({
                    leftMessage: $r('app.string.Text_Language'),
                    rightMessage: this.bookInfo?.language
                  })

                  ListItemWithText({
                    leftMessage: 'ISBN',
                    rightMessage: this.bookInfo?.identifier == '' ? '???' : this.bookInfo?.identifier
                  })

                  ListItemWithText({
                    leftMessage: $r('app.string.Text_Publisher'),
                    rightMessage: this.bookInfo?.publisher == '' ? '???' : this.bookInfo?.publisher
                  })

                  ListItemWithText({
                    leftMessage: $r('app.string.Text_PublishYear'),
                    rightMessage: this.bookInfo?.year?.toString() ?? '???'
                  })

                  ListItemWithText({
                    leftMessage: $r('app.string.Text_TotalPage'),
                    rightMessage: this.bookInfo?.pages! <= 0 ? '???' : this.bookInfo?.pages.toString()
                  })


                }
                .transition(XAnimation.getAnimation('bottom', 150))
                .borderRadius(20)
                .backgroundColor(__CustomBackgroundData__.customBackground && __System__.windowWidth > min_width ?
                $r('app.color.start_window_background_blur') : $r('sys.color.comp_background_list_card'))
                .backdropBlur(__CustomBackgroundData__.customBackground && __System__.windowWidth > min_width ? 100 :
                  undefined)
                .useEffect(true)
                .size({ height: '48', width: '100%' })
                .divider(this.egDivider)


                ListItem() {
                  Button({ type: ButtonType.Normal, stateEffect: true }) {
                    Text('在线阅读')
                  }
                  .height(55)
                  .borderRadius(20)
                  .backgroundColor(__CustomBackgroundData__.customBackground && __System__.windowWidth > min_width ?
                  $r('app.color.start_window_background_blur') : $r('sys.color.comp_background_list_card'))
                  .backdropBlur(__CustomBackgroundData__.customBackground && __System__.windowWidth > min_width ? 100 :
                    undefined)
                  .useEffect(true)
                  .width('100%')
                  .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
                  .onClick(async () => {
                    /* this.pageInfos.pop(true)*/
                    // if (__User__.isLoginZlib && (zlibClient.cookie!='' || zlibClient.cookie!= undefined )) {
                    //   __UI__.HomePageStack.pushPathByName('onlineReaderPage', this.bookInfo?.readUrl, true)
                    // }else {
                    //   promptAction.showToast({ message: `请先登录`, duration: 2000 })
                    // }
                  })
                }
                .transition(XAnimation.getAnimation('bottom', 200))

                ListItem() {
                  Button({ type: ButtonType.Normal, stateEffect: true }) {
                    Text(this.bookInfo?.extension + '   ' + this.bookInfo?.filesizeString)
                  }
                  .height(55)
                  .borderRadius(20)
                  .backgroundColor(__CustomBackgroundData__.customBackground && __System__.windowWidth > min_width ?
                  $r('app.color.start_window_background_blur') : $r('sys.color.comp_background_list_card'))
                  .backdropBlur(__CustomBackgroundData__.customBackground && __System__.windowWidth > min_width ? 100 :
                    undefined)
                  .useEffect(true)
                  .width('100%')
                  .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
                  .onClick(() => {
                    // if (this.bookInfo?.extension == 'TXT' || this.bookInfo?.extension == 'txt'){
                    //   XContext.alterDialogWithTwoButton({
                    //     title: '致歉',
                    //     message:'由于TXT文件特殊性, 通知栏与下载管理页面均无法显示下载进度, 请耐心等待下载',
                    //     cancelCallBack: (): void => {
                    //     },
                    //     confirmCallBack: (): void => {
                    //     }
                    //   })
                    // }

                    this.bookInfo?.getDownloadInfo('bsrv=f1010f9db44398249b1cf2172ad4c2fd; c_token=6E975C44D2DD903138F67D90BD87C787DC3FAEA341044; siteLanguage=zh; remix_userkey=13f69d3b981cc9d2aa1907afbe23c7cf; remix_userid=41080408; selectedSiteMode=books; redirects_count=%7B%22auth%22%3A1%2C%22hide-auth-params%22%3A1%7D',
                      async (res)=>{
                      XContext.toast(res)
                        console.log(res)

                      download(encodeURI(res), await XContext.getDownloadFolderPath())
                    },(error)=>{
                      XContext.toast(error)
                    })

                    // zlibClient.getBookDownloadUrl(this.bookInfo!).then((res)=>{
                    //   if (res[0]==0) {
                    //     this.errorText = res[1]
                    //   }
                    // })

                  })
                }
                .transition(XAnimation.getAnimation('bottom', 250))
              }
              .scrollBar(BarState.Off)
              .contentEndOffset(Math.max(__System__.bottomRectHeight, 16))
              .lanes(this.pageWidth > min_width ? 2 : 1, 10)
              .borderRadius({ topLeft: 20, topRight: 20 })
              .clip(true)
              .margin({
                left: Math.max(16, __System__.leftRectHeight),
                right: Math.max(16, __System__.rightRectHeight)
              })
              .chainAnimation(true)
              .nestedScroll({
                scrollForward: NestedScrollMode.SELF_FIRST,
                scrollBackward: NestedScrollMode.PARENT_FIRST
              })
            }
          }
          .height('100%')
          .align(Alignment.Top)
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.Spring)
          .borderRadius({ topLeft: 20, topRight: 20 })
          .clip(true)


          if (this.errorText != '') {
            Stack() {
              Column({ space: 10 }) {
                LoadingProgress().size({ width: 100, height: 100 })
                Text(XContext.getStringFromResource($r('app.string.Tip_GettingError')) + '\n' + this.errorText)
                  .fontSize(20)
                  .fontWeight(FontWeight.Medium)
                  .textAlign(TextAlign.Center)
                Button('知道了')
                  .backgroundColor($r('sys.color.button_background_color_transparent'))
                  .fontColor($r('sys.color.font'))
                  .padding({ left: 32, right: 32 })
                  .onClick(() => {
                    this.errorText = ''
                  })
              }
              .borderRadius(20)
              .padding(20)
              .backgroundColor($r('app.color.start_window_background_blur'))
              .backdropBlur(100)
            }
            .size({ width: '100%', height: '100%' })
            .padding(16)
            .backgroundColor($r('sys.color.comp_background_tertiary'))
            .transition(TransitionEffect.OPACITY.animation({ curve: Curve.Ease, duration: 300 }))
            .zIndex(114514)
          }

        }
      }
    }
    .menus([
      {
        value: '分享',
        symbolIcon: new SymbolGlyphModifier($r('sys.symbol.share')),
        action: () => {

        }
      },
      {
        value: '评论',
        symbolIcon: new SymbolGlyphModifier($r('sys.symbol.ellipsis_bubble')),
        action: () => {
          // promptAction.showToast({ message: `尝试获取`, duration: 2000 })
          // zlibClient.bookCommentArray.clearData()
          // this.commitPage = 1
          // zlibClient.getBookCommit(this.bookInfo?.bookID?.toString()!, this.commitPage).then((get) => {
          //   if (get) {
          //     this.showComment = true
          //   } else {
          //     promptAction.showToast({ message: `获取失败`, duration: 2000 })
          //   }
          // })

        }
      }
    ])
    // .bindSheet($$this.showComment, this.commentPageBuilder(), {
    //   preferType: SheetType.CENTER,
    //   height: SheetSize.LARGE,
    //   title: { title: '评论' }
    // })
    .size({ width: '100%', height: '100%' })
    .backgroundColor(__CustomBackgroundData__.customBackground && __System__.windowWidth > min_width ?
    Color.Transparent : $r('sys.color.comp_background_gray'))
    .padding({ top: __System__.topRectHeight })
    .title(this.bookInfo?.title)
    .onReady((context: NavDestinationContext) => {
      this.pageInfos = context.pathStack
      this.bookInfo = context.pathInfo.param as ZlibBookInfoArk
    })
    .opacity(this.pageOpacity)
    .onShown(() => {
      animateToImmediately({ duration: 500, curve: Curve.Ease }, () => {
        this.pageOpacity = 1
      })
    })
    .onWillHide(() => {
      animateToImmediately({ duration: 300, curve: Curve.Ease }, () => {
        this.pageOpacity = 0
      })
    })

    .onBackPressed(() => {
      if (this.isViewingBigImage) {
        XAnimation.runWithAnimation(() => this.isViewingBigImage = false, true, 0.4, 0.85)
        return true
      }
      return false
    })
  }
}


@ComponentV2
export struct BookCover {
  @Param @Require data: ResourceStr | undefined
  @Param haveShadow: boolean = true
  @Param imageFit: ImageFit = ImageFit.Contain
  @Local private isFinish: boolean = false

  build() {
    Stack() {
      Image($r('app.media.default_cover'))
        .aspectRatio(0.71)
        .visibility(this.isFinish ? Visibility.None : Visibility.Visible)
        .animation({ duration: 100 })
        .draggable(false)
        .objectFit(ImageFit.Cover)
      Image(this.data ?? $r('app.media.default_cover'))
        .visibility(this.isFinish ? Visibility.Visible : Visibility.Hidden)
        .animation({ duration: 100 })
        .draggable(false)
        .objectFit(this.imageFit)
        .onComplete(() => {
          this.isFinish = true
        })
    }
    .reuseId(this.data?.toString())
    .shadow({
      radius: this.haveShadow ? 25 : 0,
      color: Color.Gray,
      offsetX: 0,
      offsetY: 10
    })
  }
}

import { LNotificationManager, XAnimation, XContext } from 'commonpackage'
import { __Download__, __Setting__, __System__, __ZlibUser__ } from '../../../commons/shareDatas'
import { __CustomBackgroundData__ } from '../../../components/CustomBackground'
import { DividerTmp } from '../../../models/classes/DividerTmp'
import { SymbolGlyphModifier } from '@kit.ArkUI'
import { min_width } from '../../../commons/commonItem'
import { BigImage } from '../../../components/BigImage'
import { ListItemWithText } from 'templatecomponent'

import url from '@ohos.url'
import { BackgroundUtil } from '../../../models/classes/BackgroundRunningManager'
import { DownloadInfo, DownloadStatus } from '../../../models/classes/DownloadInfo'
import { RelationStoreManager } from '../../../models/classes/DataBase'
import { relationalStore } from '@kit.ArkData'
import { shareBook } from '../../../models/utils/ShareBook'
import { ZlibBookInfoArk } from 'libohos_app_cangjie_entry.zlib4cj.so'

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
                    BackgroundUtil.startContinuousTask()
                    this.bookInfo?.getDownloadInfo(__ZlibUser__.cookie,
                      async (res) => {
                        let bookName = url.URL.parseURL(res).params.get('filename')
                        let id = __ZlibUser__.notificationID++
                        let time = new Date()
                        let downloadItem: DownloadInfo = new DownloadInfo()
                        downloadItem.fileName = bookName!
                        downloadItem.fileImage = this.bookInfo?.cover!
                        downloadItem.status = DownloadStatus.Idle
                        downloadItem.bookAuthor = this.bookInfo?.author!
                        downloadItem.bookHref = this.bookInfo?.href ?? ''
                        downloadItem.bookId = this.bookInfo?.id!
                        downloadItem.downloadTime = time.toISOString()
                        downloadItem.downLoadTask = undefined
                        //写入下载管理器
                        __Download__.downloadArray.pushUnshiftData(downloadItem)
                        //插入数据库
                        await RelationStoreManager.addValue(__ZlibUser__.dataBase, 'ZlibDownloadTable', {
                          BookID: this.bookInfo?.id!,
                          BookHref: this.bookInfo?.href ?? '',
                          BookName: bookName!,
                          BookAuthor: this.bookInfo?.author!,
                          BookPublisher: this.bookInfo?.publisher!,
                          BookImage: this.bookInfo?.cover!,
                          BookDownLoadTime: time.toISOString(),
                          HaveDownload: 0
                        })
                        __ZlibUser__.downloadManageCJ?.createTask(bookName, encodeURI(res), bookName,
                          (task) => {
                            downloadItem.downLoadTask = task
                            task.setStartCallback(() => {
                              XContext.toast(`开始下载喵(^~^)`)
                              downloadItem.status = DownloadStatus.Starting
                            })
                              .setErrorCallback((error) => {
                                let predicates = new relationalStore.RdbPredicates('ZlibDownloadTable');
                                predicates.equalTo('BookName', bookName)
                                  .equalTo("BookID", this.bookInfo?.id ?? 0)
                                  .equalTo("BookDownLoadTime", time.toISOString())
                                RelationStoreManager.updateValue(__ZlibUser__.dataBase, predicates, {
                                  BookID: this.bookInfo?.id!,
                                  BookHref: this.bookInfo?.href ?? '',
                                  BookName: bookName!,
                                  BookAuthor: this.bookInfo?.author!,
                                  BookPublisher: this.bookInfo?.publisher!,
                                  BookImage: this.bookInfo?.cover!,
                                  BookDownLoadTime: time.toISOString(),
                                  HaveDownload: 2
                                })
                                console.log(`下载失败${error}`,2000)
                                downloadItem.status = DownloadStatus.Failed
                                this.errorText = error
                                LNotificationManager.pushNotificationWithProgress(id, 100, '下载失败', bookName!)
                              })
                              .setCompleteCallback(async ()=>{
                                downloadItem.progress = 100
                                let predicates = new relationalStore.RdbPredicates('ZlibDownloadTable');
                                predicates.equalTo('BookName', bookName)
                                  .equalTo("BookID", this.bookInfo?.id ?? 0)
                                  .equalTo("BookDownLoadTime", time.toISOString())
                                RelationStoreManager.updateValue(__ZlibUser__.dataBase, predicates, {
                                  BookID: this.bookInfo?.id!,
                                  BookHref: this.bookInfo?.href ?? '',
                                  BookName: bookName!,
                                  BookAuthor: this.bookInfo?.author!,
                                  BookPublisher: this.bookInfo?.publisher!,
                                  BookImage: this.bookInfo?.cover!,
                                  BookDownLoadTime: time.toISOString(),
                                  HaveDownload: 1
                                })
                                downloadItem.status = DownloadStatus.Complete
                                LNotificationManager.pushNotificationWithProgress(id, 100, '下载完成', bookName!)
                                console.log(`下载完成`)
                                if (__Setting__.shareAfterDownload) {
                                  shareBook(`${await XContext.getDownloadFolderPath()}/${bookName}`)
                                }
                              })
                              .setProgressCallback((hasDownload, total, speed) => {
                                if (downloadItem.status != DownloadStatus.Downloading) {
                                  downloadItem.status = DownloadStatus.Downloading
                                }
                                console.log(`已下载${hasDownload},共${total},当前速度${speed}`)
                                let progress = Math.trunc(hasDownload / total * 10000) / 100
                                downloadItem.progress = progress
                                  LNotificationManager.pushNotificationWithProgress(id, progress, `正在下载${progress}%`,
                                  bookName!)
                              })
                            task.start()
                          }, (error) => {
                            this.errorText = error
                            console.log(error)
                          })
                      }, (error) => {
                        this.errorText = error
                        XContext.toast(error)
                      })


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
        value: '收藏',
        symbolIcon: new SymbolGlyphModifier(this.bookInfo?.isUserSavedBook||this.bookInfo?.dataSaved ?$r('sys.symbol.heart_fill'):$r('sys.symbol.heart')),
        action: () => {
          console.log(`meow:${this.bookInfo?.isUserSavedBook}`)

        }
      }
    ])

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

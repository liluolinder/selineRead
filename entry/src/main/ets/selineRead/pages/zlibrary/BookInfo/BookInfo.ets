import { linderPixelMap, LNotificationManager, XAnimation, XContext } from 'commonpackage'
import { __Download__, __Setting__, __System__, __UI__, __ZlibUser__ } from '../../../commons/shareDatas'
import { __CustomBackgroundData__ } from '../../../components/CustomBackground'
import { DividerTmp } from '../../../models/classes/DividerTmp'
import { curves, CustomContentDialog, SelectOptions, SymbolGlyphModifier, uiMaterial } from '@kit.ArkUI'
import { min_width } from '../../../commons/commonItem'
import { BigImage } from '../../../components/BigImage'
import { ListItemWithText } from 'templatecomponent'
import url from '@ohos.url'
import { BackgroundUtil } from '../../../models/classes/BackgroundRunningManager'
import { DownloadInfo, DownloadStatus } from '../../../models/classes/DownloadInfo'
import { RelationStoreManager } from '../../../models/classes/DataBase'
import { relationalStore, uniformTypeDescriptor } from '@kit.ArkData'
import { shareBook } from '../../../models/utils/ShareBook'
import { ZlibBookInfoArk, ZlibBookInfoBriefArk } from 'libohos_app_cangjie_entry.zlib4cj.so'
import { harmonyShare, systemShare } from '@kit.ShareKit'
import { fileUri } from '@kit.CoreFileKit'
import { webview } from '@kit.ArkWeb'
import { __BookShelf__ } from '../../BookShelf/BookShelf'
import { QQbot, QQGroupInfoArk } from 'libohos_app_cangjie_entry.qqbot.so'
import { BookInfoSkeleton } from './BookInfoSkeleton'
import { SimilarBookSkeleton } from './SimilarBookSkeleton'
import { I_BookInfoParam } from '../../../models/interfaces/I_BookInfoParam'
import { HomeBookCover } from '../Home/Home'
import { HdsNavDestination, HdsNavigation } from '@hms.hds.hdsBaseComponent'
import { hdsMaterial } from '@kit.UIDesignKit'

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
  @Local isSaved: boolean = false
  @Local qqGroup: QQGroupInfoArk[] = []
  @Local qqNumber: string = ''
  @Local selectedGroupIndex: number = 0
  @Local qqIndex: number = 0
  @Local similarBook: ZlibBookInfoBriefArk[] = []
  @Local tileColumnNumber:number = 2
  recommendPage: number = 1
  webController: webview.WebviewController = new webview.WebviewController()
  private immersiveCallback = async (sharableTarget: harmonyShare.SharableTarget) => {
    const shareUrl: url.URL = url.URL.parseURL("linder://seline.book.read")
    shareUrl.params.append("hash", this.bookInfo?.hash)
    shareUrl.params.append("id", this.bookInfo?.id.toString())
    let shareData: systemShare.SharedData = new systemShare.SharedData({
      utd: uniformTypeDescriptor.UniformDataType.HYPERLINK,
      content: shareUrl.toString(),
      title: this.bookInfo?.title,
      description: '分享书籍给对方',
    });
    sharableTarget.share(shareData);
    // linderPixelMap.requestImage(this.bookInfo?.cover!).then((res) => {
    //   const path = XContext.getTempDir() + '/SelineRead_' + new Date().getTime().toString() + '.jpeg'
    //   linderPixelMap.savePixelMapToSandBox(res, path).then((res) => {
    //     if (res) {
    //       console.log(`meow:1231224451`)
    //       sharableTarget.updateShareData({
    //         thumbnailUri: fileUri.getUriFromPath(path)
    //       }).catch((error:BusinessError)=>{
    //         console.log(`meow:${error}`)
    //       })
    //     }
    //   })
    // })
  }
  send2QQDialog: CustomDialogController = new CustomDialogController({
    builder: CustomContentDialog({
      primaryTitle: '发送至QQ群',
      contentBuilder: () => {
        this.send2QQDialogBuilder();
      },
      buttons: [
        {
          value: '取消',
          buttonStyle: ButtonStyleMode.TEXTUAL,
          role: ButtonRole.ERROR,
        },
        {
          value: '确定',
          buttonStyle: ButtonStyleMode.TEXTUAL,
          action: () => {
            if (this.qqNumber != '' && this.qqGroup[this.selectedGroupIndex]) {
              this.bookInfo?.send2QQGroup(__ZlibUser__.cookie, this.qqNumber, this.qqGroup[this.selectedGroupIndex].id,
                (res) => {
                  XContext.toast(res)
                }, (error) => {
                  XContext.toast(error)
                })
            } else {
              XContext.toast('参数不合法')
            }
          }
        }
      ],
    }),
  });
  @Builder
  send2QQDialogBuilder() {
    Scroll() {
      Column({ space: 12 }) {
        Text('请输入您的QQ号以查询共同群组')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .opacity(0.6)
          .width('100%')

        TextInput({ placeholder: '例如：123456789' })
          .height(48)
          .borderRadius(12)
          .padding({ left: 12, right: 12 })
          .backgroundColor($r('sys.color.comp_background_tertiary'))
          .onSubmit((_, event) => {
            if (event.text.trim() == '') {
              XContext.toast('请输入QQ号')
              return
            }
            this.qqNumber = event.text
            this.selectedGroupIndex = 0
            let qqBot: QQbot = new QQbot()
            __ZlibUser__.qqbot.getCommonGroup(event.text, (items) => {
              this.qqGroup = items
              if (items.length == 0) {
                this.qqGroup = []
                XContext.toast('未找到共同群组')
              }
            }, (error) => {
              this.qqGroup = []
              XContext.toast(error)
            })
          })

        if (this.qqGroup.length > 0) {
          Text('请选择要发送到的群组')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .opacity(0.6)
            .width('100%')

          Select(this.qqGroup.map((item: QQGroupInfoArk, index: number) =>
          ({ value: item.name } as SelectOption)) as SelectOption[])
            .selected(this.selectedGroupIndex)
            .value(this.qqGroup[this.selectedGroupIndex]?.name ?? '选择群组')
            .height(48)
            .borderRadius(12)
            .padding({ left: 12, right: 12 })
            .backgroundColor($r('sys.color.comp_background_tertiary'))
            .onSelect((index: number) => {
              this.selectedGroupIndex = index
            })
        } else {
          Column({ space: 6 }) {
            Text('暂无共同群组')
              .fontSize(14)
              .opacity(0.4)
            Text('请在上方输入QQ号后按回车查询')
              .fontSize(12)
              .opacity(0.3)
          }
          .padding({ top: 16, bottom: 16 })
          .width('100%')
          .alignItems(HorizontalAlign.Center)
        }
      }
      .width('100%')
      .padding({
        left: 16,
        right: 16,
        top: 8,
        bottom: 8
      })
    }
    .contentEndOffset(16)
  }

  @Builder
  readOnline(){
    Column(){

      Row({space:10}){

        Button({ type: ButtonType.Circle }) {
          SymbolGlyph($r('sys.symbol.share'))
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
          XContext.getAbilityContext().startAbility({
            uri: this.bookInfo?.readOnlineUrl
          })
        })

        Button({ type: ButtonType.Circle }) {
          SymbolGlyph($r('sys.symbol.xmark'))
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
          this.showOnlineRead = false
        })
      }.justifyContent(FlexAlign.End)
      .width('100%')

      Web({ src: this.bookInfo?.readOnlineUrl, controller: this.webController })
        .size({width:'100%', height:'100%'})
        .domStorageAccess(true)
        .darkMode(WebDarkMode.Auto)
        .javaScriptAccess(true)
        .allowWindowOpenMethod(true)
        .onAppear(()=>{
          webview.WebCookieManager.configCookieSync(this.bookInfo?.readOnlineUrl, __ZlibUser__.cookie,false, false)
        })



    }.size({width:'100%', height:'100%'})
    .padding({ top: __System__.topRectHeight })
    .backgroundColor($r('sys.color.comp_background_gray'))
  }

  aboutToAppear(): void {
    harmonyShare.on('gesturesShare', this.immersiveCallback);
    harmonyShare.on('knockShare', this.immersiveCallback);
    if (__ZlibUser__.canSend2QQ) {
      __ZlibUser__.qqbot.getConfig((config)=>{
        console.log(`meow:${config.canPush2QQ}`)
        __ZlibUser__.canSend2QQ = config.canPush2QQ
      },(error)=>{
        console.log(`meow:${error}`)
        XContext.toast(error)
      })
    }
  }

  aboutToDisappear(): void {
    harmonyShare.off('gesturesShare', this.immersiveCallback);
    harmonyShare.off('knockShare', this.immersiveCallback);
  }


  build() {
    HdsNavDestination() {
      if (this.isViewingBigImage) {
        BigImage({
          image: this.bookInfo?.cover
        })
          .zIndex(114514)
      } else {
        Stack() {

          if (this.bookInfo == undefined && this.errorText == '') {
            BookInfoSkeleton()
              .transition(TransitionEffect.OPACITY.animation({ curve: Curve.Ease, duration: 300 }))
          } else {
            Scroll() {
              Column({space:20}) {
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
                      Row() {
                        if (this.bookInfo?.description == '' || this.bookInfo?.description == undefined) {
                          Text('暂无简介')
                            .fontSize(16)
                        } else {
                          Web({
                            src: `data:text/html;charset=utf-8,${encodeURIComponent(this.bookInfo?.description)}`,
                            controller: this.webController
                          })
                            .darkMode(WebDarkMode.Auto)
                            .forceDarkAccess(true)
                            .forceEnableZoom(false)
                            .nestedScroll({
                              scrollForward: NestedScrollMode.SELF_ONLY,
                              scrollBackward: NestedScrollMode.SELF_ONLY,
                            })
                            .defaultFontSize(16)
                            .minFontSize(16)
                            .defaultFixedFontSize(16)
                            .minLogicalFontSize(16)
                            .textAutosizing(true)

                        }
                      }.size({ width: '100%' })
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


                  if (__ZlibUser__.canSend2QQ){
                    ListItem() {
                      Button({ type: ButtonType.Normal, stateEffect: true }) {
                        Text('发送至QQ群')
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
                        this.selectedGroupIndex = 0
                        this.qqNumber = ''
                        this.qqGroup = []
                        this.send2QQDialog.open()
                      })
                    }
                    .transition(XAnimation.getAnimation('bottom', 200))
                  }

                  if (this.bookInfo?.readOnlineAvailable && this.bookInfo?.readOnlineUrl){
                    ListItem() {
                      Button({ type: ButtonType.Normal, stateEffect: true }) {
                        Text("在线阅读")
                      }
                      .height(55)
                      .borderRadius(20)
                      .backgroundColor(__CustomBackgroundData__.customBackground && __System__.windowWidth > min_width ?
                        $r('app.color.start_window_background_blur') : $r('sys.color.comp_background_list_card'))
                      .backdropBlur(
                        __CustomBackgroundData__.customBackground && __System__.windowWidth > min_width ? 100 :
                          undefined)
                      .useEffect(true)
                      .width('100%')
                      .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
                      .onClick(() => {
                        this.showOnlineRead = true
                        console.log(this.bookInfo?.readOnlineUrl)
                      })
                      .bindContentCover($$this.showOnlineRead, this.readOnline())
                    }
                    .transition(XAnimation.getAnimation('bottom', 200))
                  }

                  ListItem() {
                    Button({ type: ButtonType.Normal, stateEffect: true }) {
                      Text(this.bookInfo?.extension + '   ' + this.bookInfo?.filesizeString)
                    }
                    .height(55)
                    .borderRadius(20)
                    .backgroundColor(__CustomBackgroundData__.customBackground && __System__.windowWidth > min_width ?
                      $r('app.color.start_window_background_blur') : $r('sys.color.comp_background_list_card'))
                    .backdropBlur(
                      __CustomBackgroundData__.customBackground && __System__.windowWidth > min_width ? 100 :
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
                                  console.log(`下载失败${error}`, 2000)
                                  downloadItem.status = DownloadStatus.Failed
                                  this.errorText = error
                                  LNotificationManager.pushNotificationWithProgress(id, 100, '下载失败', bookName!)
                                })
                                .setCompleteCallback(async () => {
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
                                  LNotificationManager.pushNotificationWithProgress(id, progress,
                                    `正在下载${progress}%`,
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
                .lanes(this.pageWidth > min_width ? 2 : 1, 10)
                .borderRadius({ topLeft: 20, topRight: 20 })
                .clip(true)
                .margin({
                  left: Math.max(16, __System__.leftRectHeight),
                  right: Math.max(16, __System__.rightRectHeight)
                })
                .chainAnimation(true)
                .nestedScroll({
                  scrollForward: NestedScrollMode.PARALLEL,
                  scrollBackward: NestedScrollMode.PARALLEL
                })

                Row(){
                  Text("相似推荐")
                    .width('100%')
                    .fontSize(18)
                    .fontWeight(FontWeight.Medium)
                }.width('100%')
                .padding({left:16, right:16})

                if (this.similarBook.length > 0) {
                  List({ space: 10 }) {
                    ForEach(this.similarBook, (item: ZlibBookInfoBriefArk) => {
                      ListItem() {
                        HomeBookCover({ data: item })
                      }
                      .onClick(async () => {
                        let param:I_BookInfoParam = {
                          type: 0,
                          data:item
                        }
                        this.pageInfos.pushPathByName("bookInfoPage", param )
                      })
                      .width('100%')
                      .transition(TransitionEffect.OPACITY
                        .combine(TransitionEffect.scale({ x: 0.5, y: 0.5 }))
                        .animation({ curve: curves.springMotion(0.5, 0.7) }))
                    }, (item: ZlibBookInfoBriefArk, index: number) => JSON.stringify(item) + JSON.stringify(index))
                  } .nestedScroll({
                    scrollForward: NestedScrollMode.PARALLEL,
                    scrollBackward: NestedScrollMode.PARALLEL
                  })
                  .padding({left:16, right:16})
                  .contentEndOffset(Math.max(__System__.bottomRectHeight,16))
                  .width('100%')
                  .alignSelf(ItemAlign.Center)
                  .align(Alignment.Center)
                  .lanes(this.tileColumnNumber, 20)
                  .onAreaChange((_, newValue) => {
                    XAnimation.runWithAnimation(() => {
                      this.tileColumnNumber = Math.max(Math.ceil(new Number(newValue.width).valueOf() / 240), 2)

                    },  this.tileColumnNumber > 0)
                  })
                } else {
                  SimilarBookSkeleton()
                    .transition(TransitionEffect.OPACITY.animation({ curve: Curve.Ease, duration: 300 }))
                }
              }
            }
          }

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
    .size({ width: '100%', height: '100%' })
    .backgroundColor(__CustomBackgroundData__.customBackground && __System__.windowWidth > min_width ?
      Color.Transparent : $r('sys.color.comp_background_gray'))
    .padding({ top: __System__.topRectHeight })
    .onAreaChange((_, newValue) => {
      XAnimation.runWithAnimation(() => {
        this.pageWidth = newValue.width.valueOf() as number
      })
    })
    .titleBar({
      enableComponentSafeArea: true,
      content:{
        title:{
          mainTitle:this.bookInfo?.title ?? ''
        },
        menu:{
          value:[
            {
              content: {
                label: '分享',
                icon: new SymbolGlyphModifier($r('sys.symbol.share')).fontColor([$r('sys.color.font')]),
                isEnabled: true,
                action: () => {
                  if (this.bookInfo) {
                    let data: systemShare.SharedData = new systemShare.SharedData({
                      utd: uniformTypeDescriptor.UniformDataType.HYPERLINK,
                      content: this.bookInfo?.href,
                      title:this.bookInfo?.title??''
                    });
                    let controller: systemShare.ShareController = new systemShare.ShareController(data);
                    controller.show(XContext.getAbilityContext(), {});
                  }else {
                    XContext.toast("还在加载中")
                  }

                }
              }
            },
            {
              content: {
                label: '收藏',
                icon: new SymbolGlyphModifier(this.isSaved ?
                  $r('sys.symbol.heart_fill') : $r('sys.symbol.heart')).fontColor([$r('sys.color.font')]),
                action: () => {
                  if (__ZlibUser__.cookie != '') {
                    XContext.toast('正在请求中，请稍后')
                    if (this.isSaved) {
                      this.bookInfo!.unSaveBook(__ZlibUser__.cookie, (res) => {
                        if (res) {
                          this.bookInfo!.isUserSavedBook = false
                          this.bookInfo!.dataSaved = undefined
                          this.isSaved = false
                        }
                        XContext.toast(`取消收藏${res ? "成功" : "失败"}`)
                      }, (error) => {
                        this.errorText = error
                        XContext.toast(`取消收藏失败`)
                      })
                    } else {
                      this.bookInfo?.saveBook(__ZlibUser__.cookie, (res) => {
                        if (res) {
                          this.bookInfo!.isUserSavedBook = true
                          this.isSaved = true
                          XContext.toast(`收藏${res ? "成功" : "失败"}`)
                        }
                      }, (error) => {
                        this.errorText = error
                        XContext.toast(`收藏失败`)
                      })
                    }
                  } else {
                    this.errorText = '登录到您的账户'
                  }
                }
              }
            }
          ]
        }
      },
      style: {
        systemMaterialEffect: {
          materialType:hdsMaterial.MaterialType.IMMERSIVE,
          materialLevel: hdsMaterial.MaterialLevel.EXQUISITE
        },
        scrollEffectOpts: {
          enableScrollEffect: false,
        },
      }
    })
    .onReady((context: NavDestinationContext) => {
      this.pageInfos = context.pathStack
      let param = context.pathInfo.param as I_BookInfoParam
      if (param.type == 0) {
        let item = param.data as ZlibBookInfoBriefArk
        item.getDetailInfo(__ZlibUser__.cookie, (bookInfo) => {
          this.errorText = ''
          this.bookInfo = bookInfo
          this.isSaved = (this.bookInfo?.isUserSavedBook || this.bookInfo?.dataSaved) ? true : false
          this.bookInfo.getSimilarBook((books: ZlibBookInfoBriefArk[]) => {
            this.similarBook.push(...books)
          }, (error) => {
            XAnimation.runWithAnimation(() => {
              this.errorText = error
            })
          })
        }, (error) => {
          XAnimation.runWithAnimation(() => {
            this.errorText = error
          })
        })
      } else {
        this.bookInfo = param.data as ZlibBookInfoArk
        this.isSaved = (this.bookInfo?.isUserSavedBook || this.bookInfo?.dataSaved) ? true : false
        this.bookInfo.getSimilarBook((books: ZlibBookInfoBriefArk[]) => {
          this.similarBook.push(...books)
        }, (error) => {
          XAnimation.runWithAnimation(() => {
            this.errorText = error
          })
        })
      }
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

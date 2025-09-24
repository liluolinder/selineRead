/*
Copyright (c) 2025 琉离铟落linder
SelineRead is licensed under Mulan PSL v2.
You can use this software according to the terms and conditions of the Mulan
PSL v2.
You may obtain a copy of Mulan PSL v2 at:
         http://license.coscl.org.cn/MulanPSL2
THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY
KIND, EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO
NON-INFRINGEMENT, MERCHANTABILITY OR FIT FOR A PARTICULAR PURPOSE.
See the Mulan PSL v2 for more details.

Mulan Permissive Software License，Version 2

Mulan Permissive Software License，Version 2 (Mulan PSL v2)

January 2020 http://license.coscl.org.cn/MulanPSL2
 */

import { authorInfo, I_BookInfo } from "../../datas/interfaces/I_BookInfo"
import { ComposeListItem } from "@ohos.arkui.advanced.ComposeListItem"
import { zlibClient } from "../../datas/classes/zlib"
import { I_DownloadInfo } from "../../datas/interfaces/I_DownloadInfo"
import common from "@ohos.app.ability.common"
import { DividerTmp } from "../../datas/classes/DividerTmp"
import { minWidth, __CustomBackgroundData__, __System__, __UI__, __User__ } from "../../datas/classes/ShareDatas"
import { globlContext, globlUIContext } from "../../../entryability/EntryAbility"
import { curves, LengthUnit, promptAction, PromptAction, SymbolGlyphModifier } from "@kit.ArkUI"
import { XAnimation } from "../../datas/classes/XAnimation"
import { base64Encoding, setContinueState } from "../../utils/ToolsUtil"
import { BusinessError, request } from "@kit.BasicServicesKit"
import { fileUri } from "@kit.CoreFileKit"
import { photoAccessHelper } from "@kit.MediaLibraryKit"
import { I_BookComment } from "../../datas/interfaces/I_BookComment"
import { I_Terms } from "../../datas/interfaces/I_Terms"
import { I_RecommendBook } from "../../datas/interfaces/I_RecommendBook"
import { BookCover, loadingDialog, loadingNewDialog } from "../others/Builder"
import { zlibIndexShowMod } from "../../datas/enums/zlibIndexShowMod"
import { __zlibHomeData__ } from "../zlibHome/zlibHome"
import { uniformTypeDescriptor as utd } from '@kit.ArkData';
import { systemShare } from "@kit.ShareKit"
import { XContext } from "../../datas/classes/XContext"


@Builder
export function bookInfoPageBuilder() {
  bookInfoPage()
}

@ComponentV2
export struct bookInfoPage {
  @Local bookInfo: I_BookInfo | undefined = undefined
  @Local downloadInfoArray: I_DownloadInfo[] = []
  @Local isShowDownloadMenu: boolean = false
  pageInfos: NavPathStack = new NavPathStack()
  @Local egDivider: DividerTmp = new DividerTmp(0.5, 10, 10, '#ffd6d4d4')
  @Local pageWidth: number = -1
  @Local isViewingBigImage: boolean = false
  @Local pageOpacity: number = 0
  @Local showComment: boolean = false
  @Local showOnlineRead: boolean = false
  commitPage: number = 1
  @Local waterFlowColumnNumber: number = -1
  @Local isOpening: boolean = false
  @Local isFlashing: boolean = false
  recommendPage: number = 1

  @Builder
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
  }

  @Builder
  DownloadMenu() {
    Menu() {
      ForEach(this.downloadInfoArray, (item: I_DownloadInfo) => {
        MenuItem({ content: item.extension, labelInfo: item.filesizeString })
          .onClick(() => {
            zlibClient.getTrueDownloadBookUrl(this.getUIContext().getHostContext() as common.UIAbilityContext,
              item.href, this.bookInfo!)
          })
      })
    }
  }

  build() {
    NavDestination() {
      if (this.isViewingBigImage) {
        BigImage({
          image: this.bookInfo?.image
        })
          .zIndex(114514)
      } else {
        Stack(){
          Scroll(){
            Column(){
              List({ space: 10 }) {

                ListItem() {
                  Row({ space: 20 }) {
                    BookCover({data: this.bookInfo?.image})
                      .transition(TransitionEffect.OPACITY)
                      .geometryTransition('image')
                      .size({ height: 160, width: 116 })
                      .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
                      .onClick(() => {
                        XAnimation.runWithAnimation(() => this.isViewingBigImage = true, true, 0.4, 0.85)
                      })

                    Column({ space: 5 }) {
                      Text(this.bookInfo?.name)
                        .fontWeight(FontWeight.Bold)
                        .fontSize(24)
                        .maxLines(3)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                      Text() {
                        ForEach(this.bookInfo?.author, (item: authorInfo) => {
                          Span(item.name)
                          Span(' ')
                        })
                      }
                      .maxLines(3)
                      .fontSize(18)
                      .opacity(0.6)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })

                    }.alignItems(HorizontalAlign.Start).layoutWeight(1)

                  }.padding(16).justifyContent(FlexAlign.SpaceBetween).width('100%')

                }
                .backgroundColor(__CustomBackgroundData__.customBackground && __System__.windowWidth > minWidth ?
                $r('app.color.start_window_background_blur') : $r('sys.color.comp_background_list_card'))
                .backdropBlur(__CustomBackgroundData__.customBackground && __System__.windowWidth > minWidth ? 100 :
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
                  }.constraintSize({ maxHeight: 200, minHeight: this.pageWidth > minWidth ? 200 : 0 }).padding(16)
                }
                .borderRadius(20)
                .backgroundColor(__CustomBackgroundData__.customBackground && __System__.windowWidth > minWidth ?
                $r('app.color.start_window_background_blur') : $r('sys.color.comp_background_list_card'))
                .backdropBlur(__CustomBackgroundData__.customBackground && __System__.windowWidth > minWidth ? 100 :
                  undefined)
                .useEffect(true)
                .width('100%')
                .transition(XAnimation.getAnimation('bottom', 100))

                ListItemGroup() {

                  ComposeListItem({
                    contentItem: {
                      primaryText: '评分'
                    },
                    operateItem: {
                      text: this.bookInfo?.review.reviewRating.ratingValue
                    }
                  })

                  ComposeListItem({
                    contentItem: {
                      primaryText: '语言'
                    },
                    operateItem: {
                      text: this.bookInfo?.inLanguage.name
                    }
                  })

                  ComposeListItem({
                    contentItem: {
                      primaryText: 'ISBN'
                    },
                    operateItem: {
                      text: this.bookInfo?.isbn == '' ? '暂无' : this.bookInfo?.isbn
                    }
                  })

                  ComposeListItem({
                    contentItem: {
                      primaryText: '出版社'
                    },
                    operateItem: {
                      text: this.bookInfo?.publisher.name == '' ? '暂无' : this.bookInfo?.publisher.name
                    }
                  })

                  ComposeListItem({
                    contentItem: {
                      primaryText: '出版年份'
                    },
                    operateItem: {
                      text: this.bookInfo?.datePublished?.toString() ?? '暂无数据'
                    }
                  })

                  ComposeListItem({
                    contentItem: {
                      primaryText: '总页数'
                    },
                    operateItem: {
                      text: this.bookInfo?.numberOfPages! <= 0 ? '暂无数据' : this.bookInfo?.numberOfPages.toString()
                    }
                  })

                }
                .transition(XAnimation.getAnimation('bottom', 150))
                .borderRadius(20)
                .backgroundColor(__CustomBackgroundData__.customBackground && __System__.windowWidth > minWidth ?
                $r('app.color.start_window_background_blur') : $r('sys.color.comp_background_list_card'))
                .backdropBlur(__CustomBackgroundData__.customBackground && __System__.windowWidth > minWidth ? 100 :
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
                  .backgroundColor(__CustomBackgroundData__.customBackground && __System__.windowWidth > minWidth ?
                  $r('app.color.start_window_background_blur') : $r('sys.color.comp_background_list_card'))
                  .backdropBlur(__CustomBackgroundData__.customBackground && __System__.windowWidth > minWidth ? 100 :
                    undefined)
                  .useEffect(true)
                  .width('100%')
                  .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
                  .onClick(async () => {
                    /* this.pageInfos.pop(true)*/
                    if (__User__.isLoginZlib && (zlibClient.cookie!='' || zlibClient.cookie!= undefined )) {
                      __UI__.HomePageStack.pushPathByName('onlineReaderPage', this.bookInfo?.readUrl, true)
                    }else {
                      promptAction.showToast({ message: `请先登录`, duration: 2000 })
                    }
                  })
                }
                .transition(XAnimation.getAnimation('bottom', 200))

                ListItem() {
                  Button({ type: ButtonType.Normal, stateEffect: true }) {
                    Text(this.bookInfo?.firstDownloadInfo?.format + '   ' + this.bookInfo?.firstDownloadInfo?.size)
                  }
                  .height(55)
                  .borderRadius(20)
                  .backgroundColor(__CustomBackgroundData__.customBackground && __System__.windowWidth > minWidth ?
                  $r('app.color.start_window_background_blur') : $r('sys.color.comp_background_list_card'))
                  .backdropBlur(__CustomBackgroundData__.customBackground && __System__.windowWidth > minWidth ? 100 :
                    undefined)
                  .useEffect(true)
                  .width('100%')
                  .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
                  .onClick(() => {
                    zlibClient.getTrueDownloadBookUrl(this.getUIContext().getHostContext() as common.UIAbilityContext,
                      this.bookInfo?.firstDownloadUrl!, this.bookInfo!)
                  })
                }
                .transition(XAnimation.getAnimation('bottom', 250))

                ListItem() {
                  Button({ type: ButtonType.Normal, stateEffect: true }) {
                    Text('更多下载选项')
                  }
                  .height(55)
                  .borderRadius(20)
                  .backgroundColor(__CustomBackgroundData__.customBackground && __System__.windowWidth > minWidth ?
                  $r('app.color.start_window_background_blur') : $r('sys.color.comp_background_list_card'))
                  .backdropBlur(__CustomBackgroundData__.customBackground && __System__.windowWidth > minWidth ? 100 :
                    undefined)
                  .useEffect(true)
                  .width('100%')
                  .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
                  .bindMenu(this.isShowDownloadMenu, this.DownloadMenu, {
                    onDisappear: () => {
                      this.isShowDownloadMenu = false
                    }
                  })
                  .onClick(async () => {
                    await zlibClient.getBookDownloadsInfo(this.bookInfo?.bookID!).then((res) => {
                      if (res == undefined || res.length == 0) {
                        this.downloadInfoArray = [
                          {
                            id: 0,
                            extension: "暂无其他下载方式",
                            filesizeString: "",
                            href: ""
                          }
                        ]
                      } else {
                        this.downloadInfoArray = res
                      }
                      this.isShowDownloadMenu = true
                    })
                  })
                }
                .transition(XAnimation.getAnimation('bottom', 300))

              }
              .scrollBar(BarState.Off)
              .contentEndOffset(Math.max(__System__.bottomRectHeight, 16))
              .lanes(this.pageWidth > minWidth ? 2 : 1, 10)
              .borderRadius({topLeft: 20, topRight: 20})
              .clip(true)
              .margin({ left: Math.max(16, __System__.leftRectHeight), right: Math.max(16, __System__.rightRectHeight) })
              .chainAnimation(true)
              .nestedScroll({
                scrollForward: NestedScrollMode.SELF_FIRST,
                scrollBackward: NestedScrollMode.PARENT_FIRST
              })

              if((this.bookInfo?.terms?.length ?? 0) > 0){
                Column({space: 10}){
                  Stack({alignContent: Alignment.Start}){
                    Text('关键字').fontSize(20).fontWeight(FontWeight.Medium)
                  }.padding({top: 15, left: 16, right: 16}).width('100%')

                  List({space: 10}){
                    ForEach(this.bookInfo?.terms, (item: I_Terms)=>{
                      ListItem(){
                        Button({type: ButtonType.Normal}){
                          Text(item.term.charAt(0)).fontSize(20).fontWeight(FontWeight.Medium)
                        }.backgroundColor(Color.Transparent)
                        .padding({left: 15, right: 15, top: 10, bottom: 10})
                        .borderRadius(20)
                        .backgroundColor(__CustomBackgroundData__.customBackground && __System__.windowWidth > minWidth ?
                        $r('app.color.start_window_background_blur') : $r('sys.color.comp_background_list_card'))
                        .backdropBlur(__CustomBackgroundData__.customBackground && __System__.windowWidth > minWidth ? 100 :
                          undefined)
                        .useEffect(true)
                        .clickEffect({level: ClickEffectLevel.LIGHT, scale: 0.9})
                        .onClick(()=>{
                          zlibClient.searchTerms(item.term)
                          XAnimation.runWithAnimation(() => __zlibHomeData__.searchOrRecommend = zlibIndexShowMod.Search)
                          __zlibHomeData__.searchType = 1
                          __zlibHomeData__.searchWords = item.term
                          if(__System__.windowWidth < minWidth) this.pageInfos.pop()
                        })
                      }
                    })
                  }.listDirection(Axis.Horizontal)
                  .scrollBar(BarState.Off)
                  .padding({left: 16, right: 16})
                  .borderRadius(20)
                  .clip(true)
                }
                .transition(XAnimation.getAnimation('bottom', 400))


              }


              if((this.bookInfo?.recommendBooksArrayRelated?.totalCount() ?? 0) > 0){
                Stack({alignContent: Alignment.Start}){
                  Text('相关推荐').fontSize(20).fontWeight(FontWeight.Medium)
                }.padding({top: 20, left: 16, right: 16, bottom: 10}).width('100%')
                .transition(XAnimation.getAnimation('bottom', 500))

                WaterFlow() {

                  LazyForEach(this.bookInfo?.recommendBooksArrayRelated, (item: I_RecommendBook, index: number) => {
                    FlowItem() {
                      Column({ space: 20 }) {
                        BookCover({data: item.cover})

                        Column({ space: 2 }) {
                          Text(item.title)
                            .fontSize(16)
                            .maxLines(1)
                            .textOverflow({ overflow: TextOverflow.MARQUEE }).fontWeight(FontWeight.Medium)
                          Text(item.author)
                            .fontSize(12)
                            .maxLines(1)
                            .textOverflow({ overflow: TextOverflow.Ellipsis }).opacity(0.6)
                        }.alignItems(HorizontalAlign.Start)

                      }.alignItems(HorizontalAlign.Start)
                    }
                    .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.95 })
                    .padding(15)
                    .width('100%')
                    .backgroundColor(__CustomBackgroundData__.customBackground && __System__.windowWidth > minWidth ?
                    $r('app.color.start_window_background_blur') : $r('sys.color.comp_background_list_card'))
                    .backdropBlur(__CustomBackgroundData__.customBackground && __System__.windowWidth > minWidth ? 100 :
                      undefined)
                    .useEffect(true)
                    .borderRadius(15)
                    .transition(TransitionEffect.OPACITY
                      .combine(TransitionEffect.scale({ x: 0.5, y: 0.5 }))
                      .animation({ curve: curves.springMotion(0.5, 0.7) }))
                    .onClick(async () => {
                      this.isOpening = true
                      await zlibClient.getBookInfo(item.url).then((res) => {
                        if (res.name != '' && res.name != undefined) {
                          res.bookID = item.id
                          res.image = item.cover
                          res.href = item.url
                          setContinueState(true, 'book', JSON.stringify(item), '')
                          __UI__.HomePageStack.pushPathByName('bookInfoPage', res)
                        }
                        this.isOpening = false
                      })
                    })
                  }, (item: string) => item)
                }
                .transition(XAnimation.getAnimation('bottom', 500))
                .columnsTemplate(`repeat(${this.waterFlowColumnNumber},1fr)`)
                .alignSelf(ItemAlign.Center)
                .align(Alignment.Center)
                .edgeEffect(EdgeEffect.Spring)
                .height('100%')
                .columnsGap(10)
                .rowsGap(10)
                .borderRadius({topLeft: 15, topRight: 15})
                .clip(true)
                .margin({left: 16, right: 16})
                .onReachEnd(async () => {
                  this.isFlashing = true
                  await zlibClient.getRecommendBooksRelated(++this.recommendPage, this.bookInfo?.bookIDsRelated!).then((res:I_RecommendBook[])=>{
                    res.forEach((item)=>{
                      this.bookInfo?.recommendBooksArrayRelated?.pushData(item)
                    })
                  })
                  this.isFlashing = false
                })
                .nestedScroll({
                  scrollForward: NestedScrollMode.PARENT_FIRST,
                  scrollBackward: NestedScrollMode.SELF_FIRST
                })
              }
              }


          }.height('100%')
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.Spring)
          .borderRadius({topLeft: 20, topRight: 20})
          .clip(true)
          if(this.isOpening){
            loadingDialog()
          }
          if(this.isFlashing){
            loadingNewDialog()
          }
        }
        .onAreaChange((_, newValue) => {
          XAnimation.runWithAnimation(() => {
            this.waterFlowColumnNumber = Math.max(Math.ceil(new Number(newValue.width).valueOf() / 240), 2)
            this.pageWidth = new Number(newValue.width).valueOf()
          }, this.pageWidth > 0)

        })

      }


    }
    .menus([
      {
        value: '分享',
        symbolIcon: new SymbolGlyphModifier($r('sys.symbol.rectangle_and_arrowshape_turn_up_right')),
        action: () => {

          let shareData: systemShare.SharedData = new systemShare.SharedData({
            utd: utd.UniformDataType.TEXT,
            content: `向你分享一本好书,复制整条消息，打开Seline Read查看吧【${this.bookInfo?.bookID}/\\${this.bookInfo?.name}/\\${base64Encoding(this.bookInfo?.href)}】`,
            title: '分享书籍',
          });

          let controller: systemShare.ShareController = new systemShare.ShareController(shareData);
          controller.show(XContext.getAbilityContext(), {
            selectionMode: systemShare.SelectionMode.SINGLE,
            previewMode: systemShare.SharePreviewMode.DETAIL,
          }).then(() => {
            console.info('ShareController show success.');
          }).catch((error: BusinessError) => {
            console.error(`ShareController show error. code: ${error.code}, message: ${error.message}`);
          });

        }
      },
      {
        value: '评论',
        symbolIcon: new SymbolGlyphModifier($r('sys.symbol.ellipsis_bubble')),
        action: () => {
          promptAction.showToast({ message: `尝试获取`, duration: 2000 })
          zlibClient.bookCommentArray.clearData()
          this.commitPage = 1
          zlibClient.getBookCommit(this.bookInfo?.bookID?.toString()!, this.commitPage).then((get) => {
            if (get) {
              this.showComment = true
            } else {
              promptAction.showToast({ message: `获取失败`, duration: 2000 })
            }
          })

        }
      }
    ])
    .bindSheet($$this.showComment, this.commentPageBuilder(), {
      preferType: SheetType.CENTER,
      height: SheetSize.LARGE,
      title: { title: '评论' }
    })
    .size({ width: '100%', height: '100%' })
    .backgroundColor(__CustomBackgroundData__.customBackground && __System__.windowWidth > minWidth ?
    Color.Transparent : $r('sys.color.comp_background_gray'))
    .title(this.bookInfo?.name)
    .onReady((context: NavDestinationContext) => {
      this.pageInfos = context.pathStack
      this.bookInfo = context.pathInfo.param as I_BookInfo
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
    .padding({ top: __System__.topRectHeight })
    .onBackPressed(() => {
      if (this.isViewingBigImage) {
        XAnimation.runWithAnimation(() => this.isViewingBigImage = false, true, 0.4, 0.85)
        return true
      }
      setContinueState(false, 'home', '', '')
      return false
    })
  }
}


@ComponentV2
export struct BigImage {
  @Param image: ResourceStr = ''
  @Local areaWidth: number = 0
  @Local areaHeight: number = 0
  @Local zoom: number = 1
  @Local angle: number = 0
  @Local offsetX: number = 0
  @Local offsetY: number = 0
  startOffsetX: number = 0
  startOffsetY: number = 0
  startZoom: number = 0
  finger1startX: number = 0
  finger1startY: number = 0
  centerStartX: number = 0
  centerStartY: number = 0
  centerX: number = 0
  centerY: number = 0
  startDistant: number = 0
  type: number = 0
  lastZoom: number = 0
  speed: number = 0
  clicked: boolean = false

  build() {
    Stack({ alignContent: Alignment.BottomEnd }) {
      BookCover({data: this.image, haveShadow: false})
        .size({width: '100%', height: '100%'})
        .geometryTransition('image', {follow: true})
        .rotate({ z: 1, angle: this.angle })
        .offset({ x: this.offsetX, y: this.offsetY })
        .scale({ x: this.zoom, y: this.zoom })

      Stack() {
        SaveButton({
          icon: SaveIconStyle.FULL_FILLED,
          buttonType: ButtonType.Circle
        })
          .backgroundColor($r('app.color.start_window_background_blur'))
          .fontColor($r('sys.color.font'))
          .iconColor($r('sys.color.font'))
          .iconSize(20)
          .size({ width: 35, height: 35 })
          .onClick(async (event, result: SaveButtonOnClickResult) => {
            if (result == SaveButtonOnClickResult.SUCCESS) {
              promptAction.showToast({ message: '正在保存' })
              const path = globlContext.cacheDir + '/SelineRead_' + new Date().getTime().toString() + '.png'
              request.downloadFile(globlContext, {
                //替换下载地址
                url: this.image.toString(),
                //文件下载后保存的沙箱路径
                filePath: path,
                background: true
              }).then((downloadTask: request.DownloadTask) => {
                downloadTask.on('complete', async () => {
                  try {
                    let context: Context = this.getUIContext().getHostContext() as common.UIAbilityContext;
                    let phAccessHelper = photoAccessHelper.getPhotoAccessHelper(context);
                    // 需要确保fileUri对应的资源存在。
                    let uri = fileUri.getUriFromPath(path)
                    let assetChangeRequest: photoAccessHelper.MediaAssetChangeRequest =
                      photoAccessHelper.MediaAssetChangeRequest.createImageAssetRequest(context, uri);
                    await phAccessHelper.applyChanges(assetChangeRequest);
                    promptAction.showToast({ message: '已保存' })
                  } catch (err) {
                    promptAction.showToast({ message: '保存失败' })
                  }
                })
                downloadTask.on('fail', () => {
                  promptAction.showToast({ message: '保存失败' })
                })
              })

            } else {
              promptAction.showToast({ message: '保存失败' })
            }
          })
      }.margin(25)

    }
    .gesture(PanGesture().onActionStart((event) => {
      try {
        this.startOffsetX = this.offsetX
        this.startOffsetY = this.offsetY
        if (event.fingerList.length == 1 && this.type == 0) {
          this.type = 1
          this.finger1startX = event.fingerList[0].localX
          this.finger1startY = event.fingerList[0].localY
        } else if (event.fingerList.length == 2 && this.type == 0) {
          this.centerStartX = (event.fingerList[0].localX + event.fingerList[1].localX) / 2 - this.areaWidth / 2
          this.centerStartY = (event.fingerList[0].localY + event.fingerList[1].localY) / 2 - this.areaHeight / 2
          this.type = 2
          this.startDistant = Math.sqrt(Math.pow(event.fingerList[0].localX - event.fingerList[1].localX, 2) +
          Math.pow(event.fingerList[0].localY - event.fingerList[1].localY, 2))
          this.startZoom = this.zoom
          this.lastZoom = this.zoom
        }
      } catch {
      }
    })
      .onActionUpdate((event) => {
        try {
          if (event.fingerList.length == 1 && this.type == 1) {
            this.offsetX =
              this.startOffsetX + (event.fingerList[0].localX - this.finger1startX) * Math.sqrt(this.zoom)
            this.offsetY =
              this.startOffsetY + (event.fingerList[0].localY - this.finger1startY) * Math.sqrt(this.zoom)
          } else if (event.fingerList.length == 2 && this.type == 2) {
            this.centerX = (event.fingerList[0].localX + event.fingerList[1].localX) / 2 - this.areaWidth / 2
            this.centerY = (event.fingerList[0].localY + event.fingerList[1].localY) / 2 - this.areaHeight / 2
            this.zoom = Math.min(Math.max(this.startZoom +
              (Math.sqrt(Math.pow(event.fingerList[0].localX - event.fingerList[1].localX, 2) +
              Math.pow(event.fingerList[0].localY - event.fingerList[1].localY, 2)) - this.startDistant) *
                (0.002 + Math.sqrt(this.zoom) * 0.004), 0.6), 3.5)
            this.startOffsetX += (this.lastZoom - this.zoom) * (this.centerX - this.offsetX) / this.zoom
            this.startOffsetY += (this.lastZoom - this.zoom) * (this.centerY - this.offsetY) / this.zoom
            this.offsetX = this.startOffsetX + (this.centerX - this.centerStartX) * Math.sqrt(this.zoom)
            this.offsetY = this.startOffsetY + (this.centerY - this.centerStartY) * Math.sqrt(this.zoom)
            this.lastZoom = this.zoom
          }
        } catch {
        }
      })
      .onActionEnd(() => {
        if (this.type == 2) {
          if (this.zoom < 0.7) {
            XAnimation.runWithAnimation(() => {
              this.zoom = 0.7
              this.startOffsetX += (this.lastZoom - this.zoom) * (this.centerX - this.offsetX) / this.zoom
              this.startOffsetY += (this.lastZoom - this.zoom) * (this.centerY - this.offsetY) / this.zoom
              this.offsetX = this.startOffsetX + (this.centerX - this.centerStartX) * Math.sqrt(this.zoom)
              this.offsetY = this.startOffsetY + (this.centerY - this.centerStartY) * Math.sqrt(this.zoom)
            })
          }
          if (this.zoom > 3) {
            XAnimation.runWithAnimation(() => {
              this.zoom = 3
              this.startOffsetX += (this.lastZoom - this.zoom) * (this.centerX - this.offsetX) / this.zoom
              this.startOffsetY += (this.lastZoom - this.zoom) * (this.centerY - this.offsetY) / this.zoom
              this.offsetX = this.startOffsetX + (this.centerX - this.centerStartX) * Math.sqrt(this.zoom)
              this.offsetY = this.startOffsetY + (this.centerY - this.centerStartY) * Math.sqrt(this.zoom)
            })
          }
        }
        this.type = 0
      })
    )
    .onAxisEvent((event) => {
      if (event.action == AxisAction.BEGIN) {
        this.startZoom = this.zoom
        this.type = 3
      }
      if (event.action == AxisAction.UPDATE) {
        animateToImmediately({ duration: 100, curve: Curve.Ease }, () => this.zoom =
          Math.min(Math.max(this.startZoom - (event.axisVertical ?? 0) * (0.003 + Math.sqrt(this.zoom) * 0.003), 0.6),
            3.5))
      }
      if (event.action == AxisAction.END || event.action == AxisAction.CANCEL) {
        if (this.zoom < 0.7) {
          XAnimation.runWithAnimation(() => this.zoom = 0.7)
        }
        if (this.zoom > 3) {
          XAnimation.runWithAnimation(() => this.zoom = 3)
        }
        this.type = 0
      }
    })
    .onClick((event) => {
      if (this.clicked) {
        if (this.zoom == 1) {
          this.centerX = event.x - this.areaWidth / 2
          this.centerY = event.y - this.areaHeight / 2
          this.lastZoom = this.zoom
          XAnimation.runWithAnimation(() => {
            this.zoom = 1.75
            this.offsetX += (this.lastZoom - this.zoom) * (this.centerX - this.offsetX) * this.zoom
            this.offsetY += (this.lastZoom - this.zoom) * (this.centerY - this.offsetY) * this.zoom
          })
        } else {
          XAnimation.runWithAnimation(() => {
            this.zoom = 1
            this.offsetX = 0
            this.offsetY = 0
          })
        }
      } else {
        this.clicked = true
        setTimeout(() => this.clicked = false, 200)
      }
    })
    .size({ width: '100%', height: '100%' })
    .onAreaChange((_, newValue) => {
      this.areaWidth = new Number(newValue.width).valueOf()
      this.areaHeight = new Number(newValue.height).valueOf()
    })
  }
}
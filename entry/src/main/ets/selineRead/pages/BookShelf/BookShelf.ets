import { BasicDataSource, XAnimation, XContext } from 'commonpackage'
import { __Setting__, __System__, __UI__, __ZlibUser__ } from '../../commons/shareDatas'
import { LengthUnit, SegmentButtonV2Items, TabSegmentButtonV2 } from '@kit.ArkUI'
import { I_BookShelfBookInfo } from '../../models/interfaces/I_BookShelfBookInfo'
import { shareBook } from '../../models/utils/ShareBook'
import { fileIo, fileUri } from '@kit.CoreFileKit'
import { Want, wantConstant } from '@kit.AbilityKit'
import { BusinessError } from '@kit.BasicServicesKit'
import { loadingDialog } from '../../components/LoadingNewDialog'
import { zlibClient } from '../../../zlibrary/zlibClient'
import { http } from '@kit.NetworkKit'
import { __Home__ } from '../zlibrary/Home/Home'
import { I_BookDetailedInfo } from '../../models/interfaces/I_BookInfo'
import { HdsNavigation } from '@hms.hds.hdsBaseComponent'
import { hdsMaterial, HdsNavigationTitleMode } from '@kit.UIDesignKit'
import { ZlibBookInfoArk } from 'libohos_app_cangjie_entry.zlib4cj.so'
import { BookInfo } from '../zlibrary/BookInfo/BookInfo'

@ObservedV2
export class BookShelfData {
  bookList: BasicDataSource<I_BookShelfBookInfo> =
    new BasicDataSource<I_BookShelfBookInfo>()

  zlibSavedBooks: BasicDataSource<ZlibBookInfoArk> =
    new BasicDataSource<ZlibBookInfoArk>()

  @Trace gettingBookNow: boolean = false
  @Trace errorText:string = ''
}

export let __BookShelf__: BookShelfData = new BookShelfData()

@ComponentV2
export struct BookShelf {
  @Local isOpening: boolean = false
  @Consumer('tabController') tabController: TabsController = new TabsController();
  @Consumer('currentTabIndex') currentTabIndex: number = 0
  @Local chooseItem: SegmentButtonV2Items = new SegmentButtonV2Items([
    { text: '本地' },
    { text: 'zlib收藏' },
  ]);
  @Local chooseIndex: number = 0;

  @Builder
  draggingPreview(item: I_BookShelfBookInfo) {
    Flex({ alignItems: ItemAlign.Start, space: { main: { value: 5, unit: LengthUnit.VP } } }) {
      Image(item.bookImage).size({ width: 65, height: 84 }).borderRadius(15)
      Column() {
        Text(item.bookName)
          .fontWeight(FontWeight.Medium)
          .fontSize(20)
          .maxLines(2)
        Text(item.bookAuthor)
          .fontSize(14)
          .maxLines(1)
          .opacity(0.8)
      }.constraintSize({ maxWidth: '80%' })
      .padding(5)
      .alignItems(HorizontalAlign.Start)

    }.padding(8).borderRadius(20).backgroundColor($r('app.color.start_window_background'))
  }

  @Builder
  bookMenu(item: I_BookShelfBookInfo, index: number) {
    Menu() {
      MenuItem({ content: $r('app.string.Text_Share') })
        .onClick(() => {
          shareBook(item.bookPath)
        })
        .enabled(fileIo.accessSync(item.bookPath))
      // MenuItem({ content: $r('app.string.Text_SearchSame') })
      //   .onClick(() => {
      //     let textFragment: string[] = item.bookName.split('.')
      //     let bookName = ''
      //     for (let index = 0; index < textFragment.length - 1; index++) {
      //       bookName += textFragment[index]
      //     }
      //     bookName = bookName.replaceAll(" (Z-Library)", "")
      //     this.tabController.changeIndex(0)
      //     __Home__.inSearchMode = false
      //     if (bookName != '') {
      //       __Home__.searchWord = bookName
      //       __Home__.recommendOrSearch = 1
      //       __Home__.req = http.createHttp()
      //       __Home__.searchBookArray.clearData()
      //       zlibClient.searchBook(__Home__.req, __Home__.searchWord, __Home__.searchBookIndex).then((res) => {
      //         if (res[0] == 1) {
      //           __Home__.recommendBookIndex ++
      //           (JSON.parse(res[1]) as I_ZlibBookInfoRes_Book[]).forEach((item) => {
      //             __Home__.searchBookArray.pushData(item)
      //           })
      //           __Home__.errorText = ''
      //         } else {
      //           __Home__.errorText = res[1]
      //         }
      //         XAnimation.runWithAnimation(() => {
      //           __Home__.canGetMore = true
      //         })
      //       })
      //       __Home__.searchHistory =
      //         __Home__.searchHistory.filter((item: I_SearchHistory) => item.value != bookName)
      //       __Home__.searchHistory.unshift({ value: bookName, time: Date.parse(new Date().toString()) })
      //       XPreferencesManager.putPreferencesValue("selineRead", 'zlibSearchHistory',
      //         JSON.stringify(__Home__.searchHistory))
      //     }
      //   })
      //   .enabled(fileIo.accessSync(item.bookPath))
      MenuItem({ content: $r('app.string.Text_Detail') })
        .onClick(async () => {
          this.isOpening = true
          let req = http.createHttp()
          let splitBook = item.bookHref.split(`/`)
          await zlibClient.getBookInfo(req, Number(splitBook[2]), splitBook[3]).then((res) => {
            if (res[0] == 1) {
              __Home__.errorText = ''
              let bookInfo: I_BookDetailedInfo = JSON.parse(res[1]) as I_BookDetailedInfo
              bookInfo.bookID = item.bookId
              bookInfo.href = item.bookHref
              __UI__.mainPageStack.pushPathByName("bookInfoPage", bookInfo)
            } else {
              __Home__.errorText = res[1]
            }
          })
          this.isOpening = false
        })
        .enabled(item.bookHref != '')

      MenuItem({ content: $r('app.string.Text_Export'), builder: (): void => this.exportMenu(item) })
        .enabled(fileIo.accessSync(item.bookPath))


      MenuItem({ content: $r('app.string.Text_Delete') })
        .onClick(() => {
          XContext.alterDialogWithTwoButton({
            title: $r('app.string.Title_AreYouSure'),
            message: $r('app.string.Title_DeleteEnsure'),
            cancelCallBack: (): void => {

            },
            confirmCallBack: (): void => {
              try {
                fileIo.unlink(item.bookPath)
                __BookShelf__.bookList.deleteData(index)
              } catch (e) {
              }
            }
          })
        })

    }
  }

  @Builder
  exportMenu(item: I_BookShelfBookInfo) {
    Menu() {
      MenuItem({ content: '格物阅读' })
        .onClick(async () => {
          let want: Want = {
            bundleName: 'com.hm.ultimate.reader',
            action: 'ohos.want.action.viewData',
            uri: fileUri.getUriFromPath(item.bookPath),
            flags: wantConstant.Flags.FLAG_AUTH_WRITE_URI_PERMISSION | wantConstant.Flags.FLAG_AUTH_READ_URI_PERMISSION
          };
          XContext.getAbilityContext().startAbility(want)
        })
        .enabled(fileIo.accessSync(item.bookPath))

      MenuItem({ content: '华为阅读' })
        .onClick(async () => {
          let want: Want = {
            bundleName: 'com.huawei.hmsapp.books',
            action: 'ohos.want.action.viewData',
            uri: fileUri.getUriFromPath(item.bookPath),
            flags: wantConstant.Flags.FLAG_AUTH_WRITE_URI_PERMISSION | wantConstant.Flags.FLAG_AUTH_READ_URI_PERMISSION
          };
          XContext.getAbilityContext().startAbility(want)
        })
        .enabled(fileIo.accessSync(item.bookPath))

      MenuItem({ content: '自定义' })
        .onClick(async () => {
          let want: Want = {
            action: 'ohos.want.action.viewData',
            uri: fileUri.getUriFromPath(item.bookPath),
            flags: wantConstant.Flags.FLAG_AUTH_WRITE_URI_PERMISSION | wantConstant.Flags.FLAG_AUTH_READ_URI_PERMISSION
          };
          XContext.getAbilityContext().startAbility(want)
            .then(() => {
              console.info('Succeed to invoke startAbility.');
            })
            .catch((err: BusinessError) => {
              console.error(`Failed to invoke startAbility, code: ${err.code}, message: ${err.message}`);
            });
        })
        .enabled(fileIo.accessSync(item.bookPath))

    }

  }

  @Builder
  changeSegButton() {
    Row() {
      TabSegmentButtonV2({
        items: this.chooseItem,
        selectedIndex: this.chooseIndex!!,
      }).width(200)
    }.padding({ left: 16, right: 16 })
  }

  @Monitor("chooseIndex")
  changeIndexCallback(){
    switch (this.chooseIndex){
      case 0:
        break
      case 1:
        __BookShelf__.zlibSavedBooks.clearData()
        __BookShelf__.gettingBookNow = true
        __ZlibUser__.localChooseAccount.getSavedBook(1,(books, pageInfo)=>{
          __BookShelf__.gettingBookNow = false
          books.forEach((item)=>{
            __BookShelf__.zlibSavedBooks.pushData(item)
          })
          console.log(`limit:${pageInfo.limit}`)
          console.log(`current:${pageInfo.current}`)
          console.log(`totalItems:${pageInfo.totalItems}`)
          console.log(`totalPages:${pageInfo.totalPages}`)

        },(error)=>{
          __BookShelf__.errorText = error
        })
        break
    }
  }

  build() {
    Column() {
      HdsNavigation() {
        Stack() {

          if (this.chooseIndex == 0){
            if (__BookShelf__.bookList.dataArray.length ==0){
              if (__BookShelf__.gettingBookNow) {
                Column() {
                  Text($r('app.string.Tip_GettingBookNow'))
                    .fontSize(26)
                    .fontWeight(FontWeight.Bold)
                }.height('100%')
                .width('100%')
                .padding({ left: 16, right: 16 })
                .justifyContent(FlexAlign.Center)
              } else {
                Column() {
                  Text($r('app.string.Tip_ThereAreNotEmptyAnyMore'))
                    .fontSize(26)
                    .fontWeight(FontWeight.Bold)
                }.height('100%')
                .width('100%')
                .padding({ left: 16, right: 16 })
                .justifyContent(FlexAlign.Center)
              }
            }else {
              List({ space: 10 }) {
                LazyForEach(__BookShelf__.bookList, (item: I_BookShelfBookInfo, index: number) => {
                  ListItem() {
                    Row({ space: 10 }) {
                      Image(item.bookImage)
                        .aspectRatio(2 / 3)
                        .autoResize(true)
                        .height('100%')
                        .shadow({
                          radius: 25,
                          color: Color.Gray,
                          offsetX: 0,
                          offsetY: 10
                        })
                      Column({ space: 5 }) {
                        Text(item.bookName)
                          .fontWeight(FontWeight.Medium)
                          .fontSize(16)
                          .width('100%')
                          .maxLines(1)
                          .textOverflow({ overflow: TextOverflow.MARQUEE })

                        Text(item.bookAuthor)
                          .fontWeight(FontWeight.Normal)
                          .fontSize(14)
                          .width('100%')
                          .maxLines(1)
                          .opacity(0.8)
                          .textOverflow({ overflow: TextOverflow.Ellipsis })
                      }.height('100%')
                      .layoutWeight(1)
                    }.height(120)
                    .backgroundColor($r('sys.color.comp_background_list_card'))
                    .borderRadius(20)
                    .padding(16)
                  }
                  .onClick(() => {
                    let want: Want = {
                      bundleName: 'com.huawei.hmsapp.books',
                      action: 'ohos.want.action.viewData',
                      uri: fileUri.getUriFromPath(item.bookPath),
                      flags: wantConstant.Flags.FLAG_AUTH_WRITE_URI_PERMISSION |
                        wantConstant.Flags.FLAG_AUTH_READ_URI_PERMISSION
                    };
                    switch (__Setting__.bookShelfClickOpenWay) {
                      case 2:
                        want.bundleName = 'com.huawei.hmsapp.books'
                        XContext.getAbilityContext().startAbility(want)
                        break;
                      case 3:
                        want.bundleName = 'com.hm.ultimate.reader'
                        XContext.getAbilityContext().startAbility(want)
                        break;
                    }
                  })
                  .transition(XAnimation.getAnimation('bottom'))
                  .bindContextMenu(this.bookMenu(item, index), ResponseType.RightClick)
                  .bindContextMenu(this.bookMenu(item, index), ResponseType.LongPress,
                    { preview: this.draggingPreview(item), previewAnimationOptions: { hoverScale: [1.0, 0.9] } })
                }, (item: I_BookShelfBookInfo, index: number) => JSON.stringify(item) + JSON.stringify(index))
              }
              .height('100%')
              .width('100%')
              .padding({ left: 16, right: 16 })
              .borderRadius(20)
              .contentEndOffset(Math.max(__System__.bottomRectHeight, 16) + 80)
            }
          }else {
            if (__BookShelf__.zlibSavedBooks.dataArray.length ==0){
              if (__BookShelf__.gettingBookNow) {
                Column() {
                  Text($r('app.string.Tip_GettingBookNow'))
                    .fontSize(26)
                    .fontWeight(FontWeight.Bold)
                }.height('100%')
                .width('100%')
                .padding({ left: 16, right: 16 })
                .justifyContent(FlexAlign.Center)
              } else {
                Column() {
                  Text($r('app.string.Tip_ThereAreNotEmptyAnyMore'))
                    .fontSize(26)
                    .fontWeight(FontWeight.Bold)
                }.height('100%')
                .width('100%')
                .padding({ left: 16, right: 16 })
                .justifyContent(FlexAlign.Center)
              }
            }else{
              List({ space: 10 }) {
                LazyForEach(__BookShelf__.zlibSavedBooks, (item: ZlibBookInfoArk, index: number) => {
                  ListItem() {
                    Row({ space: 10 }) {
                      Image(item.cover)
                        .aspectRatio(2 / 3)
                        .autoResize(true)
                        .height('100%')
                        .shadow({
                          radius: 25,
                          color: Color.Gray,
                          offsetX: 0,
                          offsetY: 10
                        })
                      Column({ space: 5 }) {
                        Text(item.title)
                          .fontWeight(FontWeight.Medium)
                          .fontSize(16)
                          .width('100%')
                          .maxLines(1)
                          .textOverflow({ overflow: TextOverflow.MARQUEE })

                        Text(item.author)
                          .fontWeight(FontWeight.Normal)
                          .fontSize(14)
                          .width('100%')
                          .maxLines(1)
                          .opacity(0.8)
                          .textOverflow({ overflow: TextOverflow.Ellipsis })
                      }.height('100%')
                      .layoutWeight(1)
                    }.height(120)
                    .backgroundColor($r('sys.color.comp_background_list_card'))
                    .borderRadius(20)
                    .padding(16)
                  }
                  .onClick(() => {
                    if (!this.isOpening) {
                      XAnimation.runWithAnimation(() => {
                        this.isOpening = true
                      })

                      __UI__.mainPageStack.pushPathByName("bookInfoPage", item)

                      XAnimation.runWithAnimation(() => {
                        this.isOpening = false
                      })
                    }
                  })
                  .transition(XAnimation.getAnimation('bottom'))
                }, (item: ZlibBookInfoArk, index: number) => JSON.stringify(item.cover) + JSON.stringify(index))
              }
              .height('100%')
              .width('100%')
              .padding({ left: 16, right: 16 })
              .borderRadius(20)
              .contentEndOffset(Math.max(__System__.bottomRectHeight, 16) + 80)
            }
          }


          if (__BookShelf__.errorText != '' ) {
            Stack() {
              Column({ space: 10 }) {
                LoadingProgress().size({ width: 100, height: 100 })
                Text(XContext.getStringFromResource($r('app.string.Tip_GettingError')) + '\n' + __BookShelf__.errorText)
                  .fontSize(20)
                  .fontWeight(FontWeight.Medium)
                  .textAlign(TextAlign.Center)
                Button('知道了')
                  .backgroundColor($r('sys.color.button_background_color_transparent'))
                  .fontColor($r('sys.color.font'))
                  .padding({ left: 32, right: 32 })
                  .onClick(() => {
                    __BookShelf__.errorText = ''
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

          if (this.isOpening) {
            loadingDialog()
          }

        }.size({ width: '100%', height: '100%' })

      }
      .size({ width: '100%', height: '100%' })
      .mode(NavigationMode.Stack)
      .titleBar({
        enableComponentSafeArea: true,
        style: {
          systemMaterialEffect: {
            materialType: hdsMaterial.MaterialType.IMMERSIVE,
            materialLevel: hdsMaterial.MaterialLevel.EXQUISITE
          },
          scrollEffectOpts: {
            enableScrollEffect: false
          }
        },
        content: {
          title: {
            mainTitle: $r('app.string.Title_BookShelf'),
          },
          stackBuilder: () => this.changeSegButton()
        }
      })
      .hideToolBar(true)
      .hideBackButton(true)
      .titleMode(HdsNavigationTitleMode.MINI)
    }.padding({ top: Math.max(16, __System__.topRectHeight) })
  }
}
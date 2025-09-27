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

import { minWidth, __CustomBackgroundData__, __DataBase__, __System__, __UI__ } from "../../datas/classes/ShareDatas"
import { XAnimation } from "../../datas/classes/XAnimation"
import { zlibClient } from "../../datas/classes/zlib"
import { I_ZlibHaveDownloadTable } from "../../datas/interfaces/I_zlibHaveDownloadTable"
import { curves, LengthUnit, promptAction } from "@kit.ArkUI"
import { dateGetTime, getDownloadFolderPath, shareBook } from "../../utils/ToolsUtil"
import { loadingDialog } from "../others/Builder"
import { fileIo, fileUri, picker } from "@kit.CoreFileKit"
import { linderDataBaseManger } from "../../datas/classes/LDataBaseManager"
import { relationalStore, unifiedDataChannel } from "@kit.ArkData"
import { bookParser } from "@kit.ReaderKit"
import { globalContext } from "../../../entryability/EntryAbility"
import { BusinessError, zlib } from "@kit.BasicServicesKit"
import { common, Want, wantConstant } from "@kit.AbilityKit"
import { XContext } from "../../datas/classes/XContext"

@ComponentV2
export struct BookShelf {
  @Local lanes: number = -1
  @Local isOpening: boolean = false

  build() {
    Stack() {
      Scroll() {
        Column({space: 10}){
          Flex({ justifyContent: FlexAlign.SpaceBetween, alignItems: ItemAlign.Center }) {
            Text('书架').fontSize(25).fontWeight(FontWeight.Medium)

            Row({space: 10}){
              Button({ stateEffect: true }) {
                SymbolGlyph($r('sys.symbol.plus')).fontSize(26).fontColor([$r('sys.color.font')])
              }
              .size({ width: 40, height: 40 })
              .backgroundColor(__CustomBackgroundData__.customBackground? $r('app.color.start_window_background_blur'): $r('sys.color.comp_background_list_card'))
              .backdropBlur(__CustomBackgroundData__.customBackground? 100: undefined)
              .useEffect(true)
              .onClick(() => {
                new picker.DocumentViewPicker().select({ fileSuffixFilters: ['epub', 'pdf'], maxSelectNumber: 1 })
                  .then(async (result) => {
                    const file0 = fileIo.openSync(result[0])
                    if (fileIo.accessSync(await getDownloadFolderPath() + new fileUri.FileUri(result[0]).name)) {
                      promptAction.showToast({ message: '文件已存在', duration: 2000 })
                      return
                    }
                    const file1 = fileIo.openSync(await getDownloadFolderPath() + new fileUri.FileUri(result[0]).name,
                      fileIo.OpenMode.CREATE | fileIo.OpenMode.READ_WRITE)
                    fileIo.copyFile(file0.fd, file1.fd).then(async () => {
                      const id = new Date().getTime() * -1
                      const valueBucket: relationalStore.ValuesBucket = {
                        BookID: id,
                        BookName: file0.name,
                        BookHref: '',
                        BookAuthor: '未知',
                        BookPublisher: '未知',
                        BookImage: '',
                        BookDownLoadTime: new Date().toISOString(),
                        BookFilePath: file1.path,
                        haveDownload: 0
                      };
                      try {
                        const bookParserHandler = await bookParser.getDefaultHandler(file1.path)
                        const bookInfo = bookParserHandler.getBookInfo();
                        valueBucket.BookName = bookInfo.bookTitle
                        valueBucket.BookAuthor = bookInfo.bookCreator || valueBucket.BookAuthor
                        if (bookInfo.bookCoverImage) {
                          fileIo.mkdir(globalContext.cacheDir + '/tmp/')
                          await zlib.decompressFile(file1.path, globalContext.cacheDir + '/tmp/')
                          const file2 = fileIo.openSync(globalContext.filesDir + '/' + id.toString(),
                            fileIo.OpenMode.CREATE | fileIo.OpenMode.READ_WRITE)
                          const coverImage = fileIo.openSync(globalContext.cacheDir + '/tmp/' + bookInfo.bookCoverImage)
                          fileIo.copyFileSync(coverImage.fd, file2.fd)
                          valueBucket.BookImage = fileUri.getUriFromPath(file2.path)
                          fileIo.rmdirSync(globalContext.cacheDir + '/tmp/')
                        }
                      } catch {
                      }

                      linderDataBaseManger.insertValueToRelationalDataBase(__DataBase__.baseStore, 'zlibHaveDownload',
                        valueBucket).then(() => {
                        zlibClient.flashDownloadHistoryAndLocalBooksList()
                      })
                      promptAction.showToast({ message: '导入完成', duration: 2000 })
                    })
                  })
              })
              if(__UI__.onlineMode){
                Button({ stateEffect: true }) {
                  SymbolGlyph($r('sys.symbol.download')).fontSize(26).fontColor([$r('sys.color.font')])
                }
                .size({ width: 40, height: 40 })
                .backgroundColor(__CustomBackgroundData__.customBackground? $r('app.color.start_window_background_blur'): $r('sys.color.comp_background_list_card'))
                .backdropBlur(__CustomBackgroundData__.customBackground? 100: undefined)
                .useEffect(true)
                .onClick(()=>{
                  if(!__UI__.HomePageStack.getAllPathName().includes('downloadPage')) __UI__.HomePageStack.pushPathByName('downloadPage', undefined)
                })
              }

            }


          }.padding({ top: Math.max(__System__.topRectHeight, 16), left: 16, right: 16 })


          if (zlibClient.localDownloadHistoryArray.totalCount() == 0) {
            Stack() {
              Text('空空如也')
                .fontSize(30)
                .fontWeight(FontWeight.Medium)
                .offset({ y: __System__.windowWidth > minWidth ? 0 : (70 + __System__.bottomRectHeight) * -1 })
            }.height('100%')
          } else {
            List({ space: 10 }) {

              LazyForEach(zlibClient.localDownloadHistoryArray, (item: I_ZlibHaveDownloadTable, index: number) => {
                ListItem() {
                  Row({ space: 10 }) {
                    Image(item.BookImage.length == 0 ? $r('app.media.zlib') : item.BookImage)
                      .size({ height: '100%', width: 82 })
                      .borderRadius(15)
                      .autoResize(true)
                      .draggable(false)
                    Flex({
                      justifyContent: FlexAlign.SpaceBetween,
                      alignItems: ItemAlign.Start,
                      direction: FlexDirection.Column
                    }) {
                      Column({ space: 2 }) {
                        Text(item.BookName)
                          .fontWeight(FontWeight.Medium)
                          .fontSize(21)
                          .maxLines(2)
                        Text(item.BookAuthor)
                          .maxLines(1)
                          .fontSize(16)
                          .opacity(0.8)

                      }.alignItems(HorizontalAlign.Start)

                      Flex({ justifyContent: FlexAlign.SpaceBetween, alignItems: ItemAlign.End }) {
                        Text(dateGetTime(item.BookDownLoadTime))
                          .maxLines(1)
                          .fontSize(12)
                          .opacity(0.6)
                        Row({ space: 5 }) {
                          if (!fileIo.accessSync(item.BookFilePath)) {
                            SymbolGlyph($r('sys.symbol.ohos_trash'))
                              .fontSize(20)
                              .fontColor([$r('sys.color.warning')])

                          }
                          if (item.BookID > 0) {
                            SymbolGlyph($r('sys.symbol.cloud'))
                              .fontSize(20)
                              .fontColor([$r('sys.color.font')])
                          }
                        }.opacity(0.4).padding({ left: 10, right: 10 })

                      }

                    }.layoutWeight(1).padding({ top: 5, bottom: 5 })

                  }.size({ width: '100%', height: '100%' })
                  .padding(8)
                  .onClick(() => {
                    if (fileIo.accessSync(item.BookFilePath)) {
                      if(item.BookFilePath.split('.')[item.BookFilePath.split('.').length - 1]?.toLowerCase() == 'pdf'){
                        __UI__.HomePageStack.pushPath({ name: 'pdfViewerPage', param: item.BookFilePath }, true)
                      }else{
                        __UI__.HomePageStack.pushPath({ name: 'readerPage', param: item.BookFilePath }, true)
                      }
                    } else {
                      promptAction.showToast({
                        message: '源文件不存在',
                        duration: 2000
                      })
                    }
                  })
                }
                .transition(XAnimation.getAnimation('bottom'))
                .backgroundColor(__CustomBackgroundData__.customBackground? $r('app.color.start_window_background_blur'): $r('sys.color.comp_background_list_card'))
                .backdropBlur(__CustomBackgroundData__.customBackground? 100: undefined)
                .useEffect(true)
                .draggable(fileIo.accessSync(item.BookFilePath))
                .onDragStart((event) => {
                  if (fileIo.accessSync(item.BookFilePath)) {
                    let data: unifiedDataChannel.File = new unifiedDataChannel.File()
                    data.uri = item.BookFilePath
                    event.setData(new unifiedDataChannel.UnifiedData(data))
                  }
                  return this.draggingPreview(item)
                })
                .bindContextMenu(this.BookMenu(item), ResponseType.RightClick)
                .bindContextMenu(this.BookMenu(item), ResponseType.LongPress,
                  { preview: this.draggingPreview(item), previewAnimationOptions: { hoverScale: [1.0, 0.9] } })
                .borderRadius(20)
                .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.95 })
                .size({ width: '100%', height: 120 })
              }, (item: string) => item)

            }
            .onScrollStart(()=>{
              setTimeout(()=>{
                __UI__.hideBars()
              }, 50)
            })
            .nestedScroll({
              scrollForward: NestedScrollMode.PARENT_FIRST,
              scrollBackward: NestedScrollMode.SELF_FIRST
            })
            .height('100%')
            .lanes(this.lanes, 10)
            .scrollBar(BarState.Off)
            .edgeEffect(EdgeEffect.Spring)
            .chainAnimation(true)
            .contentEndOffset(Math.max(16, __System__.bottomRectHeight + (__System__.windowWidth > minWidth ? 0 : 70)))
            .onAreaChange((_, newValue) => {
              XAnimation.runWithAnimation(() => {
                this.lanes = Math.max(Math.floor(new Number(newValue.width).valueOf() / 400), 1)
              }, this.lanes > 0)
            })
            .margin({ left: 16, right: 16 })
          }
        }

      }.size({ height: '100%', width: '100%' }).scrollBar(BarState.Off)

      if (this.isOpening) {
        loadingDialog()
      }

    }.size({ height: '100%', width: '100%' })
    .onAppear(() => {
      zlibClient.flashDownloadHistoryAndLocalBooksList()
    })
  }

  @Builder
  draggingPreview(item: I_ZlibHaveDownloadTable) {
    Flex({ alignItems: ItemAlign.Start, space: { main: { value: 5, unit: LengthUnit.VP } } }) {
      Image(item.BookImage).size({ width: 65, height: 84 }).borderRadius(15)
      Column() {
        Text(item.BookName)
          .fontWeight(FontWeight.Medium)
          .fontSize(20)
          .maxLines(2)
        Text(item.BookAuthor)
          .fontSize(14)
          .maxLines(1)
          .opacity(0.8)
      }.constraintSize({ maxWidth: '80%' })
      .padding(5)
      .alignItems(HorizontalAlign.Start)

    }.padding(8).borderRadius(20).backgroundColor($r('app.color.start_window_background'))
  }

  @Builder
  ExportMenu(item: I_ZlibHaveDownloadTable)
  {
    Menu() {
      MenuItem({ content: '格物阅读' })
        .onClick(async () => {
          let want: Want = {
            bundleName: 'com.hm.ultimate.reader',
            action: 'ohos.want.action.viewData',
            uri: fileUri.getUriFromPath(item.BookFilePath),
            flags: wantConstant.Flags.FLAG_AUTH_WRITE_URI_PERMISSION | wantConstant.Flags.FLAG_AUTH_READ_URI_PERMISSION
          };
          (globalContext as common.UIAbilityContext).startAbility(want)
        })
        .enabled(fileIo.accessSync(item.BookFilePath))

      MenuItem({ content: '华为阅读' })
        .onClick(async () => {
          let want: Want = {
            bundleName: 'com.huawei.hmsapp.books',
            action: 'ohos.want.action.viewData',
            uri: fileUri.getUriFromPath(item.BookFilePath),
            flags: wantConstant.Flags.FLAG_AUTH_WRITE_URI_PERMISSION | wantConstant.Flags.FLAG_AUTH_READ_URI_PERMISSION
          };
          (globalContext as common.UIAbilityContext).startAbility(want)
        })
        .enabled(fileIo.accessSync(item.BookFilePath))

      MenuItem({ content: '自定义' })
        .onClick(async () => {
          let want: Want = {
            action: 'ohos.want.action.viewData',
            uri: fileUri.getUriFromPath(item.BookFilePath),
            flags: wantConstant.Flags.FLAG_AUTH_WRITE_URI_PERMISSION | wantConstant.Flags.FLAG_AUTH_READ_URI_PERMISSION
          };
          (globalContext as common.UIAbilityContext).startAbility(want)
            .then(() => {
              console.info('Succeed to invoke startAbility.');
            })
            .catch((err: BusinessError) => {
              console.error(`Failed to invoke startAbility, code: ${err.code}, message: ${err.message}`);
            });
        })
        .enabled(fileIo.accessSync(item.BookFilePath))

    }

  }


  @Builder
  BookMenu(item: I_ZlibHaveDownloadTable) {
    Menu() {
      MenuItem({ content: '分享' })
        .onClick(() => {
          shareBook(item.BookFilePath)
        })
        .enabled(fileIo.accessSync(item.BookFilePath))
      if (__UI__.onlineMode) {
        MenuItem({ content: '查看详情' })
          .onClick(async () => {
            this.isOpening = true
            await zlibClient.getBookInfo(item.BookHref).then((res) => {
              if (res.name != '' && res.name != undefined) {
                res.bookID = item.BookID
                res.image = item.BookImage
                res.href = item.BookHref
                __UI__.HomePageStack.removeByName('bookInfoPage')
                __UI__.HomePageStack.pushPathByName('bookInfoPage', res)
              }
              this.isOpening = false
            })
          })
          .enabled(item.BookID > 0)
      }
      MenuItem({ content: '编辑' })
        .onClick(async () => {

        })
        .enabled(item.BookID < 0)
      MenuItem({ content: '删除' })
        .contentFontColor($r('sys.color.warning'))
        .onClick(() => {
          linderDataBaseManger.deleteValueToRelationalDataBase(__DataBase__.baseStore, "zlibHaveDownload",
            [{ key: 'ID', value: item.ID }]).then(() => {
            zlibClient.flashDownloadHistoryAndLocalBooksList()
          })
          try {
            fileIo.unlinkSync(globalContext.filesDir + '/' + item.BookID)
          } catch {
          }
        })


      MenuItem({ content: '导出至...',builder: ():void=>this.ExportMenu(item) })
        .enabled(fileIo.accessSync(item.BookFilePath))

    }
  }
}

@ComponentV2
struct EditBookInfoPage {
  @Param @Require info: I_ZlibHaveDownloadTable

  build() {

  }
}
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

import { minWidth, __DataBase__, __System__, __UI__ } from "../../datas/classes/ShareDatas"
import { XAnimation } from "../../datas/classes/XAnimation"
import { zlibClient } from "../../datas/classes/zlib"
import { I_ZlibHaveDownloadTable } from "../../datas/interfaces/I_zlibHaveDownloadTable"
import { curves, LengthUnit, promptAction } from "@kit.ArkUI"
import { dateGetTime, getDownloadFolderPath, shareBook } from "../../utils/ToolsUtil"
import { loadingDialog } from "../Builder"
import { fileIo, fileUri, picker } from "@kit.CoreFileKit"
import { linderDataBaseManger } from "../../datas/classes/LDataBaseManager"
import { relationalStore, unifiedDataChannel } from "@kit.ArkData"
import { bookParser } from "@kit.ReaderKit"
import { globlContext } from "../../../entryability/EntryAbility"
import { BusinessError, zlib } from "@kit.BasicServicesKit"
import { common, Want, wantConstant } from "@kit.AbilityKit"

@ComponentV2
export struct BookShelf {
  @Local lanes: number = -1
  @Local isOpening: boolean = false

  build() {
    Stack() {
      Column({ space: 10 }) {
        Flex({ justifyContent: FlexAlign.SpaceBetween, alignItems: ItemAlign.Center }) {
          Text('书架').fontSize(25).fontWeight(FontWeight.Medium)

          Row({space: 10}){
            Button({ stateEffect: true }) {
              SymbolGlyph($r('sys.symbol.plus')).fontSize(26).fontColor([$r('sys.color.font')])
            }
            .size({ width: 40, height: 40 })
            .backgroundColor($r('sys.color.comp_background_list_card'))
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
                        fileIo.mkdir(globlContext.cacheDir + '/tmp/')
                        await zlib.decompressFile(file1.path, globlContext.cacheDir + '/tmp/')
                        const file2 = fileIo.openSync(globlContext.filesDir + '/' + id.toString(),
                          fileIo.OpenMode.CREATE | fileIo.OpenMode.READ_WRITE)
                        const coverImage = fileIo.openSync(globlContext.cacheDir + '/tmp/' + bookInfo.bookCoverImage)
                        fileIo.copyFileSync(coverImage.fd, file2.fd)
                        valueBucket.BookImage = fileUri.getUriFromPath(file2.path)
                        fileIo.rmdirSync(globlContext.cacheDir + '/tmp/')
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
              .backgroundColor($r('sys.color.comp_background_list_card'))
              .onClick(()=>{
                if(!__UI__.indexPageStack.getAllPathName().includes('downloadPage')) __UI__.indexPageStack.pushPathByName('downloadPage', undefined)
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
                    __UI__.indexPageStack.pushPath({ name: 'readerPage', param: item.BookFilePath }, true)
                  } else {
                    promptAction.showToast({
                      message: '源文件不存在',
                      duration: 2000
                    })
                  }
                })
              }
              .transition(XAnimation.getAnimation('bottom'))
              .backgroundColor($r('sys.color.comp_background_list_card'))
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
          .height('100%')
          .lanes(this.lanes, 10)
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.Spring)
          .contentEndOffset(Math.max(16, __System__.bottomRectHeight + (__System__.windowWidth > minWidth ? 0 : 70)))
          .onAreaChange((_, newValue) => {
            XAnimation.runWithAnimation(() => {
              this.lanes = Math.max(Math.floor(new Number(newValue.width).valueOf() / 400), 1)
            }, this.lanes > 0)
          })
          .layoutWeight(1)
          .margin({ left: 16, right: 16 })
          .borderRadius({ topLeft: 20, topRight: 20 })
          .clip(true)
        }

      }


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
          .maxLines(3)
        Text(item.BookAuthor)
          .fontSize(14)
          .maxLines(1)
          .opacity(0.8)
      }.constraintSize({ maxWidth: '80%' })
      .padding(5)
      .alignItems(HorizontalAlign.Start)

    }.padding(8).borderRadius(20).backgroundColor($r('sys.color.comp_background_list_card'))
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
                __UI__.indexPageStack.removeByName('bookInfoPage')
                __UI__.indexPageStack.pushPathByName('bookInfoPage', res)
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
            fileIo.unlinkSync(globlContext.filesDir + '/' + item.BookID)
          } catch {
          }
        })

      MenuItem({ content: '导出至格物阅读' })
        .onClick(async () => {
          let want: Want = {
            bundleName: 'com.hm.ultimate.reader',
            action: 'ohos.want.action.viewData',
            uri: fileUri.getUriFromPath(item.BookFilePath),
            flags: wantConstant.Flags.FLAG_AUTH_WRITE_URI_PERMISSION | wantConstant.Flags.FLAG_AUTH_READ_URI_PERMISSION
          };
          (globlContext as common.UIAbilityContext).startAbility(want)
        })
    }
  }
}

@ComponentV2
struct EditBookInfoPage {
  @Param @Require info: I_ZlibHaveDownloadTable

  build() {

  }
}
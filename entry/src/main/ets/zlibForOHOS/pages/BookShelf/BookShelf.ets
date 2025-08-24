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
import { curves, promptAction } from "@kit.ArkUI"
import { dateGetTime, shareBook } from "../../utils/ToolsUtil"
import { loadingDialog } from "../Builder"
import { fileIo } from "@kit.CoreFileKit"
import { linderDataBaseManger } from "../../datas/classes/LDataBaseManager"

@ComponentV2
export struct BookShelf {

  @Local lanes: number = -1
  @Local isOpening: boolean = false

  build() {
    Stack() {
      Column({space: 10}){
        Flex({justifyContent: FlexAlign.SpaceBetween, alignItems: ItemAlign.Center}){
          Text('书架').fontSize(25).fontWeight(FontWeight.Medium)
          Button({stateEffect: true}){
            SymbolGlyph($r('sys.symbol.plus')).fontSize(26).fontColor([$r('sys.color.font')])
          }
          .size({width: 40, height: 40})
          .backgroundColor($r('sys.color.comp_background_list_card'))
          .onClick(()=>{
            zlibClient.flashDownloadHistoryAndLocalBooksList()
          })
        }.padding({top: Math.max( __System__.topRectHeight, 16), left: 16, right: 16})

        List({ space: 10 }) {

          LazyForEach(zlibClient.localDownloadHistoryArray, (item: I_ZlibHaveDownloadTable, index: number) => {
            ListItem() {
              Row({ space: 10 }) {
                Image(item.BookImage)
                  .size({ height: '100%', width: 82 })
                  .borderRadius(15)
                Flex({justifyContent: FlexAlign.SpaceBetween, alignItems: ItemAlign.Start, direction: FlexDirection.Column}){
                  Column({ space: 2 }) {
                    Text(item.BookName)
                      .fontWeight(FontWeight.Medium)
                      .fontSize(22)
                      .maxLines(1)
                    Text(item.BookAuthor)
                      .maxLines(1)
                      .fontSize(16)
                      .opacity(0.8)

                  }.alignItems(HorizontalAlign.Start)
                  Text(dateGetTime(item.BookDownLoadTime))
                    .maxLines(1)
                    .fontSize(12)
                    .opacity(0.6)
                }.layoutWeight(1).padding({top: 5, bottom: 5})

              }.size({ width: '100%', height: '100%' })
              .padding(8)

              .bindMenu([
                {
                  value: '分享',
                  action: ()=>{
                    shareBook(item.BookFilePath)
                  },
                  enabled: fileIo.accessSync(item.BookFilePath)
                },
                {
                  value: '查看详情',
                  action: async ()=>{
                    this.isOpening = true
                    await zlibClient.getBookInfo(item.BookHref).then((res) => {
                      if (res.name!='' && res.name!=undefined ) {
                        res.bookID = item.BookID
                        res.image = item.BookImage
                        res.href = item.BookHref
                        __UI__.indexPageStack.removeByName('bookInfoPage')
                        __UI__.indexPageStack.pushPathByName('bookInfoPage', res)
                      }
                    })
                    this.isOpening = false
                  }
                },
                {
                  value: '在内置阅读器查看',
                  action: ()=>{
                    __UI__.indexPageStack.pushPath({name: 'readerPage', param: item.BookFilePath}, true)
                  },
                  enabled: fileIo.accessSync(item.BookFilePath)
                },
                {
                  value: '编辑',
                  action: ()=>{
                  },
                },
                {
                  value: '删除',
                  action: ()=>{
                    linderDataBaseManger.deleteValueToRelationalDataBase(__DataBase__.baseStore,"zlibHaveDownload", [{key: 'ID', value: item.ID}]).then(()=>{
                      zlibClient.flashDownloadHistoryAndLocalBooksList()
                    })
                  },
                }
              ])
            }
            .transition(XAnimation.getAnimation('bottom'))
            .backgroundColor($r('sys.color.comp_background_list_card'))
            .borderRadius(20)
            .clickEffect({level: ClickEffectLevel.LIGHT, scale: 0.95})
            .size({ width: '100%', height: 120 })
          }, (item: string) => item)

        }
        .height('100%')
        .lanes(this.lanes, 10)
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
        .contentEndOffset(Math.max(16, __System__.bottomRectHeight + (__System__.windowWidth > minWidth? 0: 70)))
        .onAreaChange((_, newValue)=>{
          XAnimation.runWithAnimation(()=>{
            this.lanes = Math.max(Math.floor(new Number(newValue.width).valueOf() / 400), 1)
          }, this.lanes > 0)
        })
        .layoutWeight(1)
        .margin({left: 16, right: 16})
        .borderRadius({topLeft: 20, topRight: 20})
        .clip(true)
      }


      if(this.isOpening){
        loadingDialog()
      }

    }.size({ height: '100%', width: '100%' })
    .onAppear(()=>{
      zlibClient.flashDownloadHistoryAndLocalBooksList()
    })
  }
}

@ComponentV2
struct EditBookInfoPage{

  @Param @Require info: I_ZlibHaveDownloadTable

  build() {

  }
}
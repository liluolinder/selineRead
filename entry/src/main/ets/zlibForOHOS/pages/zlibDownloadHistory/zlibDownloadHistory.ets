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

import { minWidth, __System__, __UI__ } from "../../datas/classes/ShareDatas"
import { XAnimation } from "../../datas/classes/XAnimation"
import { zlibClient } from "../../datas/classes/zlib"
import { I_ZlibHaveDownloadTable } from "../../datas/interfaces/I_zlibHaveDownloadTable"
import { promptAction } from "@kit.ArkUI"
import { dateGetTime } from "../../utils/ToolsUtil"

@ComponentV2
export struct zlibDownloadHistory {

  @Local lanes: number = -1

  build() {
    Column() {
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

            .onClick(async () => {
              if (__UI__.isHaveOpenBook) {
                promptAction.showToast({ message: `已有待打开的书籍，请稍后`, duration: 800 })
              }else {
                await zlibClient.getBookInfo(item.BookHref).then((res) => {
                  if (res.name!='' && res.name!=undefined ) {
                    res.bookID = item.BookID
                    res.image = item.BookImage
                    res.href = item.BookHref
                    __UI__.indexPageStack.pushPathByName('bookInfoPage', res)
                  }
                })
              }
            })
          }
          .onClick(async () => {
          })
          .transition(XAnimation.getAnimation('bottom'))
          .backgroundColor($r('sys.color.comp_background_list_card'))
          .borderRadius(20)
          .clickEffect({level: ClickEffectLevel.LIGHT, scale: 0.9})
          .size({ width: '100%', height: 120 })
        })

      }.size({ width: '100%', height: '100%' })
      .padding({ bottom: 55 })
      .edgeEffect(EdgeEffect.Spring)
      .contentStartOffset(Math.max(__System__.topRectHeight, 16))
      .contentEndOffset(Math.max(16, __System__.bottomRectHeight + (__System__.windowWidth > minWidth? 70: 0)))
      .onAreaChange((_, newValue)=>{
        XAnimation.runWithAnimation(()=>{
          this.lanes = Math.max(Math.floor(new Number(newValue.width).valueOf() / 300), 1)
        }, this.lanes > 0)
      })

    }.size({ height: '100%', width: '100%' })
    .padding({ left: 16, right: 16 })
  }
}
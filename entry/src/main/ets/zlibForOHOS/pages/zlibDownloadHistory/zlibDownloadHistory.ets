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

import { __System__ } from "../../datas/classes/ShareDatas"
import { XAnimation } from "../../datas/classes/XAnimation"
import { zlibClient } from "../../datas/classes/zlib"
import { I_ZlibHaveDownloadTable } from "../../datas/interfaces/I_zlibHaveDownloadTable"

@ComponentV2
export struct zlibDownloadHistory {
  build() {
    Column() {
      List({ space: 10 }) {

        LazyForEach(zlibClient.localDownloadHistoryArray, (item: I_ZlibHaveDownloadTable, index: number) => {
          ListItem() {
            Row({ space: 10 }) {
              Image(item.BookImage)
                .size({ height: '100%', width: 82 })
                .borderRadius(18)

              Column({ space: 5 }) {
                Text(item.BookName)
                  .size({ width: '100%' })
                  .fontWeight(FontWeight.Medium)
                  .fontSize(20)
                  .textAlign(TextAlign.Start)
                  .maxLines(1)
                Text(item.BookAuthor)
                  .size({ width: '100%' })
                  .textAlign(TextAlign.Start)
                  .maxLines(1)
                Text(new Date(item.BookDownLoadTime).toString())
                  .size({ width: '100%' })
                  .textAlign(TextAlign.Start)
                  .maxLines(1)
              }.layoutWeight(1)
            }.size({ width: '100%', height: '100%' })
            .padding(8)
          }
          .onClick(async () => {
          })
          .transition(XAnimation.getAnimation('bottom'))
          .backgroundColor($r('sys.color.comp_background_list_card'))
          .borderRadius(20)
          .size({ width: '100%', height: 120 })
        })

      }.size({ width: '100%', height: '100%' })
      .padding({ bottom: 55 })
      .edgeEffect(EdgeEffect.Spring)
      .lanes(__System__.currentBreakpoint === 'lg' ? 3 : (__System__.currentBreakpoint == 'md' ? 2 : 1), 10)
    }.size({ height: '100%', width: '100%' })
    .padding({ left: 16, right: 16 })
  }
}
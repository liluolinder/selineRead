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
import { __System__ } from "../../datas/classes/ShareDatas"
import { globlUIContext } from "../../../entryability/EntryAbility"

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
      Column() {
        List({ space: 10 }) {

          ListItem() {
            Row({ space: 10 }) {
              Column({ space: 10 }) {
                Text(this.bookInfo?.name)
                  .fontWeight(FontWeight.Bold)
                  .fontSize(24)
                  .size({ width: '100%' })
                  .maxLines(3)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })

                Text() {
                  ForEach(this.bookInfo?.author, (item: authorInfo) => {
                    Span(item.name)
                    Span(' ')
                  })
                }
                .maxLines(3)
                .fontWeight(FontWeight.Normal)
                .fontSize(18)
                .textAlign(TextAlign.Start)
                .size({ width: '100%' })
                .textOverflow({ overflow: TextOverflow.Ellipsis })
              }.layoutWeight(1)

              Image(this.bookInfo?.image)
                .size({ height: 160 })
                .shadow({
                  radius: 25,
                  color: Color.Gray,
                  offsetX: 0,
                  offsetY: 10
                })

            }.padding(16)
            .justifyContent(FlexAlign.SpaceBetween)

          }.backgroundColor($r('sys.color.comp_background_list_card'))

          .size({ width: '100%', height: 200 })
          .borderRadius(20)

          ListItem() {
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

            }.size({ width: '100%', height: '100%' })
            .edgeEffect(EdgeEffect.Spring)
            .scrollBar(BarState.Off)
            .fadingEdge(true)
          }
          .borderRadius(20)
          .padding(16)
          .backgroundColor($r('sys.color.comp_background_list_card'))
          .size({ height: 200, width: '100%' })

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
                text: this.bookInfo?.datePublished.toString()
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

          }.borderRadius(20)
          .backgroundColor($r('sys.color.comp_background_list_card'))
          .size({ height: '48', width: '100%' })
          .divider(this.egDivider)

          ListItem() {
            Row() {
              Column() {
                Button(this.bookInfo?.firstDownloadInfo?.format + '   ' + this.bookInfo?.firstDownloadInfo?.size)
                  .size({ height: '100%', width: '100%' })
                  .onClick(() => {
                    zlibClient.getTrueDownloadBookUrl(this.getUIContext().getHostContext() as common.UIAbilityContext,
                      this.bookInfo?.firstDownloadUrl!, this.bookInfo!)
                  })
              }.size({ height: '100%', width: '50%' })
              .padding({ right: 8 })

              Column() {
                Button('更多下载选项')
                  .size({ height: '100%', width: '100%' })
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
              }.size({ height: '100%', width: '50%' })
              .padding({ left: 8 })
            }.size({ height: '100%', width: '100%' })
          }
          .size({ height: 48, width: '100%' })
          .margin({
            bottom:globlUIContext.px2vp(__System__.bottomRectHeight)
          })

        }.width('100%')
        .height('100%')
        .scrollBar(BarState.Off)
        .lanes(__System__.currentBreakpoint == 'sm' ? 1 : 2, 10)


      }.size({ width: '100%', height: '100%' })
      .padding({ left: 16, right: 16 })

    }.size({ width: '100%', height: '100%' })
    .backgroundColor($r('sys.color.comp_background_gray'))
    .title(this.bookInfo?.name)
    .onReady((context: NavDestinationContext) => {
      this.pageInfos = context.pathStack
      this.bookInfo = context.pathInfo.param as I_BookInfo

    })
  }
}
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
import { minWidth, __System__ } from "../../datas/classes/ShareDatas"
import { globlUIContext } from "../../../entryability/EntryAbility"
import { LengthUnit } from "@kit.ArkUI"
import { XAnimation } from "../../datas/classes/XAnimation"

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
        List({ space: 10 }) {

          ListItem() {
            Row({space: 20}) {
              Image(this.bookInfo?.image)
                .size({ height: 160, width:116})
                .shadow({
                  radius: 25,
                  color: Color.Gray,
                  offsetX: 0,
                  offsetY: 10
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

          }.backgroundColor($r('sys.color.comp_background_list_card'))
          .size({ width: '100%', height: 200 })
          .borderRadius(20)

          ListItem() {
            Stack({alignContent: Alignment.Top}){
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
            }.constraintSize({maxHeight: 200, minHeight: this.pageWidth > minWidth? 200: 0}).padding(16)
          }
          .borderRadius(20)
          .backgroundColor($r('sys.color.comp_background_list_card'))
          .width('100%')

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
                text: this.bookInfo?.datePublished?.toString()??'暂无数据'
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


          ListItem(){
            Button({type: ButtonType.Normal, stateEffect: true}){
              Text(this.bookInfo?.firstDownloadInfo?.format + '   ' + this.bookInfo?.firstDownloadInfo?.size)
            }.height(55).borderRadius(20).backgroundColor($r('sys.color.comp_background_list_card')).width('100%')
            .clickEffect({level: ClickEffectLevel.LIGHT, scale: 0.9})
            .onClick(() => {
              zlibClient.getTrueDownloadBookUrl(this.getUIContext().getHostContext() as common.UIAbilityContext,
                this.bookInfo?.firstDownloadUrl!, this.bookInfo!)
            })
          }

          ListItem(){
            Button({type: ButtonType.Normal, stateEffect: true}){
              Text('更多下载选项')
            }.height(55).borderRadius(20).backgroundColor($r('sys.color.comp_background_list_card')).width('100%')
            .clickEffect({level: ClickEffectLevel.LIGHT, scale: 0.9})
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




        }
        .height('100%')
        .scrollBar(BarState.Off)
        .contentEndOffset(Math.max(__System__.bottomRectHeight, 16))
        .lanes(this.pageWidth > minWidth? 2: 1, 10)
        .borderRadius({topLeft: 20, topRight: 20}).clip(true)
        .margin({ left: Math.max(16, __System__.leftRectHeight), right: Math.max(16, __System__.rightRectHeight) })
      .chainAnimation(true)


    }.size({ width: '100%', height: '100%' })
    .backgroundColor($r('sys.color.comp_background_gray'))
    .title(this.bookInfo?.name)
    .onReady((context: NavDestinationContext) => {
      this.pageInfos = context.pathStack
      this.bookInfo = context.pathInfo.param as I_BookInfo

    })
    .padding({top: __System__.topRectHeight})
    .onAreaChange((_, newValue)=>{
      XAnimation.runWithAnimation(()=>{
        this.pageWidth = new Number(newValue.width).valueOf()
      }, this.pageWidth > 0)
    })
  }
}
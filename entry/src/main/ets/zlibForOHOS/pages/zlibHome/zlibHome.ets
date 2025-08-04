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

import { zlibClient } from "../../datas/classes/zlib"
import { I_RecommendBook } from "../../datas/interfaces/I_RecommendBook"
import { curves, LengthMetrics } from "@kit.ArkUI"
import { __System__ } from "../../datas/classes/ShareDatas"
import { XAnimation } from "../../datas/classes/XAnimation"
import { I_searchBook } from "../../datas/interfaces/I_BookInfo"
import { zlibIndexShowMod } from "../../datas/enums/zlibIndexShowMod"
import { effectKit } from "@kit.ArkGraphics2D"

@ComponentV2
export struct zlibHome {
  @Consumer('pageStack') pageStack: NavPathStack = new NavPathStack()
  @Consumer('isInSearchMode') isInSearchMode: boolean = false
  @Local recommendIndex: number = 1
  @Local searchIndex: number = 1
  @Local showSearchPage: boolean = false
  @Local searchOrRecommend: zlibIndexShowMod = zlibIndexShowMod.Recommend
  @Local listOrWaterFlow: zlibIndexShowMod = zlibIndexShowMod.WaterFlow
  @Local searchBookName: string = ''

  getWaterFlowColumnNumber(): number {
    if (__System__.currentBreakpoint == 'sm') {
      return 2
    } else if (__System__.currentBreakpoint == 'md') {
      return 4
    } else {
      return 6
    }
  }

  @Builder
  waterFlow_recommend() {
    LazyForEach(zlibClient.recommendBooksArray, (item: I_RecommendBook, index: number) => {
      FlowItem() {
        Column({ space: 10 }) {
          Image(item.cover)
            .size({ width: '90%' })
            .shadow({
              radius: 25,
              color: Color.Gray,
              offsetX: 0,
              offsetY: 10
            })

          Text(item.title)
            .fontSize(15)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

        }.padding(5)

        /*.size({ width: '100%', height: '100%' })*/
      }
      .padding(10)
      .width('100%')
      .backgroundColor($r('sys.color.comp_background_list_card'))
      .borderRadius(20)
      .transition(TransitionEffect.OPACITY
        .combine(TransitionEffect.scale({ x: 0.5, y: 0.5 }))// 对每个方格的转场添加delay，实现组件的渐次出现消失效果
        .animation({ duration: 500, curve: Curve.Friction }))
      .onClick(async () => {
        await zlibClient.getBookInfo(item.url).then((res) => {
          res.bookID = item.id
          res.image = item.cover
          res.href = item.url
          this.pageStack.pushPathByName('bookInfoPage', res)
        })
      })
    }, (item: string) => item)
  }

  @Builder
  list_recommend() {
    LazyForEach(zlibClient.recommendBooksArray, (item: I_RecommendBook, index: number) => {
      ListItem() {
        Row({ space: 10 }) {
          Image(item.cover)
            .size({ height: '100%' })
            .shadow({
              radius: 25,
              color: Color.Gray,
              offsetX: 0,
              offsetY: 10
            })

          Column({ space: 5 }) {
            Text(item.title)
              .size({ width: '100%' })
              .fontWeight(FontWeight.Medium)
              .fontSize(20)
              .textAlign(TextAlign.Start)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Text(item.author)
              .size({ width: '100%' })
              .textAlign(TextAlign.Start)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }.layoutWeight(1)
        }.size({ width: '100%', height: '100%' })
        .padding(15)
      }
      .onClick(async () => {
        await zlibClient.getBookInfo(item.url).then((res) => {
          res.bookID = item.id
          res.image = item.cover
          res.href = item.url
          this.pageStack.pushPathByName('bookInfoPage', res)
        })
      })
      .transition(TransitionEffect.OPACITY
        .combine(TransitionEffect.scale({ x: 0.5, y: 0.5 }))// 对每个方格的转场添加delay，实现组件的渐次出现消失效果
        .animation({ duration: 500, curve: Curve.Friction }))
      .backgroundColor($r('sys.color.comp_background_list_card'))
      .borderRadius(20)
      .size({ width: '100%', height: 120 })
    })
  }

  @Builder
  waterFlow_search() {
    LazyForEach(zlibClient.searchBooksArray, (item: I_searchBook, index: number) => {
      FlowItem() {
        Column({ space: 10 }) {
          Image(item.image)
            .size({ width: '90%' })
            .shadow({
              radius: 25,
              color: Color.Gray,
              offsetX: 0,
              offsetY: 10
            })

          Text(item.title)
            .fontWeight(FontWeight.Medium)
            .fontSize(18)
            .maxLines(1)

        }.padding(10)
        .margin({ bottom: 10 })

        /*.size({ width: '100%', height: '100%' })*/
      }
      .width('100%')
      .backgroundColor($r('sys.color.comp_background_list_card'))
      .borderRadius(20)
      .transition(TransitionEffect.OPACITY
        .combine(TransitionEffect.scale({ x: 0.5, y: 0.5 }))
        .animation({ duration: 500, curve: Curve.Friction }))
      .onClick(async () => {
        await zlibClient.getBookInfo(item.href).then((res) => {
          res.bookID = Number(item.id)
          res.image = item.image
          res.href = item.href
          this.pageStack.pushPathByName('bookInfoPage', res)
        })
      })
    }, (item: string) => item)
  }

  @Builder
  list_search() {
    LazyForEach(zlibClient.searchBooksArray, (item: I_searchBook, index: number) => {
      ListItem() {
        Row({ space: 10 }) {
          Image(item.image)
            .size({ height: '100%' })
            .shadow({
              radius: 25,
              color: Color.Gray,
              offsetX: 0,
              offsetY: 10
            })

          Column({ space: 5 }) {
            Text(item.title)
              .size({ width: '100%' })
              .fontWeight(FontWeight.Medium)
              .fontSize(20)
              .textAlign(TextAlign.Start)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Text(item.writer)
              .size({ width: '100%' })
              .textAlign(TextAlign.Start)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }.layoutWeight(1)
        }.size({ width: '100%', height: '100%' })
        .padding(15)
      }
      .onClick(async () => {
        await zlibClient.getBookInfo(item.href).then((res) => {
          res.bookID = Number(item.id)
          res.image = item.image
          res.href = item.href
          this.pageStack.pushPathByName('bookInfoPage', res)
        })
      })
      .transition(TransitionEffect.OPACITY
        .combine(TransitionEffect.scale({ x: 0.5, y: 0.5 }))// 对每个方格的转场添加delay，实现组件的渐次出现消失效果
        .animation({ duration: 500, curve: Curve.Friction }))
      .backgroundColor($r('sys.color.comp_background_list_card'))
      .borderRadius(20)
      .size({ width: '100%', height: 120 })
    })
  }

  build() {
    Column({ space: 5 }) {
      //顶部搜索栏
      GridRow({ columns: {xs:4, sm: 4, md: 12, lg: 12 } }) {
        GridCol({
          span: {xs: this.isInSearchMode ? 0 : 2, sm: this.isInSearchMode ? 0 : 2, md: this.isInSearchMode ? 0 : 7, lg: this.isInSearchMode ? 0 : 7 }
        }) {
          Row() {
            Button({ type: ButtonType.Circle }) {
              SymbolGlyph(this.listOrWaterFlow == zlibIndexShowMod.WaterFlow ? $r('sys.symbol.list_bullet') :
              $r('sys.symbol.satellite_map'))
                .fontSize(24)
                .fontColor([$r('sys.color.font_secondary')])
            }
            .margin({ right: 5, top: 5 })
            .width(40)
            .height(40)
            .backgroundColor($r('sys.color.comp_background_tertiary'))
            .onClick(() => {
              XAnimation.runWithAnimation(() => {
                this.listOrWaterFlow = this.listOrWaterFlow == zlibIndexShowMod.WaterFlow ? zlibIndexShowMod.List :
                zlibIndexShowMod.WaterFlow
              })
            })

          }.justifyContent(FlexAlign.End)
          .size({ width: '100%', height: '100%' })
          .visibility(this.isInSearchMode ? Visibility.Hidden : Visibility.Visible)
        }.size({ width: '100%', height: '100%' })

        GridCol({
          span: {xs: this.isInSearchMode ? 0 : 2, sm: this.isInSearchMode ? 4 : 2, md: this.isInSearchMode ? 12 : 5, lg: this.isInSearchMode ? 12 : 5 }
        }) {
          Search()
            .focusable(this.isInSearchMode)
            .enableKeyboardOnFocus(this.isInSearchMode)
            .onEditChange((isInFocus) => {
              XAnimation.runWithAnimation(() => {
                this.isInSearchMode = isInFocus
              })
            })
            .onSubmit((value: string) => {
              if (value == '' || value == undefined) {
                XAnimation.runWithAnimation(() => {
                  this.searchOrRecommend = zlibIndexShowMod.Recommend
                })
              } else {
                this.searchIndex = 1
                this.searchBookName = value
                zlibClient.searchBooks(value, 1, true)
                XAnimation.runWithAnimation(() => {
                  this.searchOrRecommend = zlibIndexShowMod.Search
                })
              }

            })
            .onChange((value: string) => {
              if (value == '' || value == undefined) {
                XAnimation.runWithAnimation(() => {
                  this.searchOrRecommend = zlibIndexShowMod.Recommend
                })
              }
            })
            .onTouch(() => {
              XAnimation.runWithAnimation(() => {
                this.isInSearchMode = true
              })
            })
        }.size({ width: '100%', height: '100%' })
      }.height(50)

      if ((this.searchOrRecommend == zlibIndexShowMod.Recommend &&
        zlibClient.recommendBooksArray.dataArray.length == 0) ||
        (this.searchOrRecommend == zlibIndexShowMod.Search && zlibClient.searchBooksArray.dataArray.length == 0)) {
        LoadingProgress()
          .size({ width: 100, height: 100 })
      } else {
        Stack() {
          if (this.listOrWaterFlow == zlibIndexShowMod.WaterFlow) {
            WaterFlow() {
              if (this.searchOrRecommend == zlibIndexShowMod.Recommend) {
                this.waterFlow_recommend()
              } else {
                this.waterFlow_search()
              }
            }
            .columnsTemplate(`repeat(${this.getWaterFlowColumnNumber()},1fr)`)
            .alignSelf(ItemAlign.Center)
            .align(Alignment.Center)
            .padding({ bottom: 55 })
            .edgeEffect(EdgeEffect.Spring)
            .fadingEdge(true, { fadingEdgeLength: LengthMetrics.vp(80) })
            .columnsGap(10)
            .rowsGap(10)
            .height('100%')
            .onReachEnd(() => {
              if (this.searchOrRecommend != zlibIndexShowMod.Recommend) {
                zlibClient.searchBooks(this.searchBookName, ++this.searchIndex, false)
              } else {
                zlibClient.getRecommendBooks(++this.recommendIndex)
              }
            })
          } else {

            List({ space: 10 }) {
              if (this.searchOrRecommend == zlibIndexShowMod.Recommend) {
                this.list_recommend()
              } else {
                this.list_search()
              }
            }
            .size({ width: '100%', height: '100%' })
            .padding({ bottom: 55 })
            .onReachEnd(() => {
              if (this.searchOrRecommend != zlibIndexShowMod.Recommend) {
                zlibClient.searchBooks(this.searchBookName, ++this.searchIndex, false)
              } else {
                zlibClient.getRecommendBooks(++this.recommendIndex)
              }
            })
            .edgeEffect(EdgeEffect.Spring)
            .lanes(__System__.currentBreakpoint === 'lg' ? 3 : (__System__.currentBreakpoint == 'md' ? 2 : 1), 10)

          }

          if (this.isInSearchMode) {
            Column()
              .size({ width: '100%', height: '100%' })
              .blur(40)
              .onClick(() => {
                XAnimation.runWithAnimation(() => {
                  this.isInSearchMode = false
                })
              })
          }
        }
      }

    }
    .size({ height: '100%', width: '100%' })
    .padding({ left: 16, right: 16 })
  }
}
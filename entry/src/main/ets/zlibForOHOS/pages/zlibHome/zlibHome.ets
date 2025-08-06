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
import { curves, LengthMetrics, promptAction } from "@kit.ArkUI"
import { minWidth, __System__, __UI__ } from "../../datas/classes/ShareDatas"
import { XAnimation } from "../../datas/classes/XAnimation"
import { I_searchBook } from "../../datas/interfaces/I_BookInfo"
import { zlibIndexShowMod } from "../../datas/enums/zlibIndexShowMod"
import { effectKit } from "@kit.ArkGraphics2D"

@ComponentV2
export struct zlibHome {
  @Local recommendIndex: number = 1
  @Local searchIndex: number = 1
  @Local showSearchPage: boolean = false
  @Local listOrWaterFlow: zlibIndexShowMod = zlibIndexShowMod.WaterFlow
  @Local searchBookName: string = ''
  @Local waterFlowColumnNumber : number = -1
  @Local waterFlowEmptyItem: number[] = []

  @Local isOpening: boolean = false

  @Builder
  waterFlow_recommend() {
    LazyForEach(zlibClient.recommendBooksArray, (item: I_RecommendBook, index: number) => {
      FlowItem() {
        Column({ space: 20 }) {
          Image(item.cover)
            .size({ width: '100%' })
            .shadow({
              radius: 25,
              color: Color.Gray,
              offsetX: 0,
              offsetY: 10
            })

          Column({space: 2}){
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
      .clickEffect({level: ClickEffectLevel.LIGHT, scale: 0.9})
      .padding(15)
      .width('100%')
      .backgroundColor($r('sys.color.comp_background_list_card'))
      .borderRadius(15)
      .transition(TransitionEffect.OPACITY
        .combine(TransitionEffect.scale({ x: 0.5, y: 0.5 }))
        .animation({ curve: curves.springMotion(0.5, 0.7) }))
      .onClick(async () => {
        this.isOpening = true
        if (__UI__.isHaveOpenBook) {
          promptAction.showToast({ message: `已有待打开的书籍，请稍后`, duration: 800 })
        }else {
          await zlibClient.getBookInfo(item.url).then((res) => {
            if (res.name!='' && res.name!=undefined ) {
              res.bookID = item.id
              res.image = item.cover
              res.href = item.url
              __UI__.indexPageStack.removeByName('bookInfoPage')
              __UI__.indexPageStack.pushPathByName('bookInfoPage', res)
            }
            this.isOpening = false
          })
        }
      })
    }, (item: string) => item)
  }

  @Builder
  list_recommend() {
    LazyForEach(zlibClient.recommendBooksArray, (item: I_RecommendBook, index: number) => {
      ListItem() {
        Row({ space: 10 }) {
          Image(item.cover)
            .size({ height: '100%',width:'62' })
            .shadow({
              radius: 25,
              color: Color.Gray,
              offsetX: 0,
              offsetY: 10
            })

          Column({ space: 2 }) {
            Text(item.title)
              .fontWeight(FontWeight.Medium)
              .fontSize(20)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.MARQUEE })
            Text(item.author)
              .maxLines(1)
              .fontSize(14)
              .textOverflow({ overflow: TextOverflow.Ellipsis }).opacity(0.8)
          }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        }.size({ width: '100%', height: '100%' })
        .padding(15)
      }
      .clickEffect({level: ClickEffectLevel.LIGHT, scale: 0.9})
      .onClick(async () => {
        this.isOpening = true
        if (__UI__.isHaveOpenBook) {
          promptAction.showToast({ message: `已有待打开的书籍，请稍后`, duration: 800 })
        }else {
          await zlibClient.getBookInfo(item.url).then((res) => {
            if (res.name!='' && res.name!=undefined ) {
              res.bookID = item.id
              res.image = item.cover
              res.href = item.url
              __UI__.indexPageStack.removeByName('bookInfoPage')
              __UI__.indexPageStack.pushPathByName('bookInfoPage', res)
            }
            this.isOpening = false
          })
        }
      })
      .transition(TransitionEffect.OPACITY
        .combine(TransitionEffect.scale({ x: 0.5, y: 0.5 }))
        .animation({ curve: curves.springMotion(0.5, 0.7) }))
      .backgroundColor($r('sys.color.comp_background_list_card'))
      .borderRadius(20)
      .size({ width: '100%', height: 120 })
    })
  }

  @Builder
  waterFlow_search() {
    LazyForEach(zlibClient.searchBooksArray, (item: I_searchBook, index: number) => {
      FlowItem() {
        Column({ space: 20 }) {
          Image(item.image)
            .size({ width: '100%' })
            .shadow({
              radius: 25,
              color: Color.Gray,
              offsetX: 0,
              offsetY: 10
            })

          Column({space: 2}){
            Text(item.title)
              .fontSize(16)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.MARQUEE }).fontWeight(FontWeight.Medium)
            Text(item.writer)
              .fontSize(12)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis }).opacity(0.6)
          }.alignItems(HorizontalAlign.Start)


        }.alignItems(HorizontalAlign.Start)
      }
      .clickEffect({level: ClickEffectLevel.LIGHT, scale: 0.9})
      .padding(15)
      .backgroundColor($r('sys.color.comp_background_list_card'))
      .borderRadius(15)
      .transition(TransitionEffect.OPACITY
        .combine(TransitionEffect.scale({ x: 0.5, y: 0.5 }))
        .animation({ curve: curves.springMotion(0.5, 0.7) }))
      .onClick(async () => {
        if (__UI__.isHaveOpenBook) {
          promptAction.showToast({ message: `已有待打开的书籍，请稍后`, duration: 800 })
        }else {
          this.isOpening = true
          await zlibClient.getBookInfo(item.href).then((res) => {
            if (res.name!='' && res.name!=undefined ) {
              res.bookID = Number(item.id)
              res.image = item.image
              res.href = item.href
              __UI__.indexPageStack.removeByName('bookInfoPage')
              __UI__.indexPageStack.pushPathByName('bookInfoPage', res)
            }
            this.isOpening = false
          })
        }
      })
    }, (item: string) => item)
  }

  @Builder
  list_search() {
    LazyForEach(zlibClient.searchBooksArray, (item: I_searchBook, index: number) => {
      ListItem() {
        Row({ space: 10 }) {
          Image(item.image)
            .size({ height: '100%',width:'62' })
            .shadow({
              radius: 25,
              color: Color.Gray,
              offsetX: 0,
              offsetY: 10
            })

          Column({ space: 2 }) {
            Text(item.title)
              .fontWeight(FontWeight.Medium)
              .fontSize(20)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.MARQUEE })
            Text(item.writer)
              .maxLines(1)
              .fontSize(14)
              .textOverflow({ overflow: TextOverflow.Ellipsis }).opacity(0.8)
          }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        }.size({ width: '100%', height: '100%' })
        .padding(15)
      }
      .clickEffect({level: ClickEffectLevel.LIGHT, scale: 0.9})
      .onClick(async () => {
        if (__UI__.isHaveOpenBook) {
          promptAction.showToast({ message: `已有待打开的书籍，请稍后`, duration: 800 })
        }else {
          this.isOpening = true
          await zlibClient.getBookInfo(item.href).then((res) => {
            if (res.name!='' && res.name!=undefined ) {
              res.bookID = Number(item.id)
              res.image = item.image
              res.href = item.href
              __UI__.indexPageStack.removeByName('bookInfoPage')
              __UI__.indexPageStack.pushPathByName('bookInfoPage', res)
            }
            this.isOpening = false
          })
        }
      })
      .transition(TransitionEffect.OPACITY
        .combine(TransitionEffect.scale({ x: 0.5, y: 0.5 }))
        .animation({ curve: curves.springMotion(0.5, 0.7) }))
      .backgroundColor($r('sys.color.comp_background_list_card'))
      .borderRadius(20)
      .size({ width: '100%', height: 120 })
    })
  }

  build() {
    Stack({alignContent: Alignment.TopEnd}) {
      if(this.isOpening){
        Stack(){
          Column({space: 10}){
            LoadingProgress().size({width: 100, height: 100})
            Text('正在载入').fontSize(20).fontWeight(FontWeight.Medium)
          }.borderRadius(20).padding(20).backgroundColor($r('app.color.start_window_background_blur')).backdropBlur(100)
        }.size({width: '100%', height: '100%'}).backgroundColor($r('sys.color.comp_background_tertiary')).transition(TransitionEffect.OPACITY.animation({curve:Curve.Ease, duration: 300})).zIndex(2)
      }
      //顶部搜索栏
      Row({space: 10}){
        Button({ type: ButtonType.Circle }) {
          SymbolGlyph(this.listOrWaterFlow == zlibIndexShowMod.WaterFlow ? $r('sys.symbol.list_bullet') :
          $r('sys.symbol.satellite_map'))
            .fontSize(24)
            .fontColor([$r('sys.color.font_secondary')])
        }
        .width(40)
        .height(40)
        .backgroundColor($r('sys.color.comp_background_tertiary')).backdropBlur(100)
        .onClick(() => {
          XAnimation.runWithAnimation(() => {
            this.listOrWaterFlow = this.listOrWaterFlow == zlibIndexShowMod.WaterFlow ? zlibIndexShowMod.List :
            zlibIndexShowMod.WaterFlow
          })
        })
        .visibility(__UI__.isInSearchMode? Visibility.None: Visibility.Visible)

        Search()
          .backgroundColor($r('sys.color.comp_background_tertiary')).backdropBlur(100)
          .focusable(__UI__.isInSearchMode)
          .enableKeyboardOnFocus(__UI__.isInSearchMode)
          .onEditChange((isInFocus) => {
            XAnimation.runWithAnimation(() => {
              __UI__.isInSearchMode = isInFocus
            })
          })
          .onSubmit((value: string) => {
            if (value == '' || value == undefined) {
              XAnimation.runWithAnimation(() => {
                __UI__.searchOrRecommend = zlibIndexShowMod.Recommend
              })
            } else {
              this.searchIndex = 1
              this.searchBookName = value
              zlibClient.searchBooks(value, 1, true)
              XAnimation.runWithAnimation(() => {
                __UI__.searchOrRecommend = zlibIndexShowMod.Search
              })
            }

          })
          .onChange((value: string) => {
            if (value == '' || value == undefined) {
              XAnimation.runWithAnimation(() => {
                __UI__.searchOrRecommend = zlibIndexShowMod.Recommend
              })
            }
          })
          .onTouch(() => {
            XAnimation.runWithAnimation(() => {
              __UI__.isInSearchMode = true
            })
          })
          .width(__UI__.isInSearchMode? '100%': '50%')
      }.zIndex(1).padding({ left: 16, right: 16, top: __System__.topRectHeight })


      if ((__UI__.searchOrRecommend == zlibIndexShowMod.Recommend &&
        zlibClient.recommendBooksArray.dataArray.length == 0) ||
        (__UI__.searchOrRecommend == zlibIndexShowMod.Search && zlibClient.searchBooksArray.dataArray.length == 0)) {
        Column(){
          LoadingProgress()
            .size({ width: 150, height: 150 })
        }.size({width:'100%', height:'100%'})
        .justifyContent(FlexAlign.Center)
      } else {
        Stack() {
          if (this.listOrWaterFlow == zlibIndexShowMod.WaterFlow) {
            WaterFlow() {
              ForEach(this.waterFlowEmptyItem, (item: number)=>{FlowItem().height(__System__.topRectHeight + 60)})

              if (__UI__.searchOrRecommend == zlibIndexShowMod.Recommend) {
                this.waterFlow_recommend()
              } else {
                this.waterFlow_search()
              }

              ForEach(this.waterFlowEmptyItem, (item: number)=>{FlowItem().height(Math.max(__System__.bottomRectHeight + (__System__.windowWidth > minWidth? 0: 70), 16))})
            }
            .onAreaChange((_, newValue)=>{
              XAnimation.runWithAnimation(()=>{
                this.waterFlowColumnNumber = Math.max(Math.floor(new Number(newValue.width).valueOf() / 180), 2)
                let itemList: number[] = []
                for (let index = 0; index < this.waterFlowColumnNumber; index++) {
                  itemList.push(index)
                }
                this.waterFlowEmptyItem = itemList
              }, this.waterFlowColumnNumber > 0)
            })
            .columnsTemplate(`repeat(${this.waterFlowColumnNumber},1fr)`)
            .alignSelf(ItemAlign.Center)
            .align(Alignment.Center)
            .layoutWeight(1)
            .edgeEffect(EdgeEffect.Spring)
            .columnsGap(10)
            .rowsGap(10)
            .onReachEnd(() => {
              if (__UI__.searchOrRecommend != zlibIndexShowMod.Recommend) {
                zlibClient.searchBooks(this.searchBookName, ++this.searchIndex, false)
              } else {
                zlibClient.getRecommendBooks(++this.recommendIndex)
              }
            })
          } else {

            List({ space: 10 }) {
              ListItem().height(__System__.topRectHeight + 60)
              if (__UI__.searchOrRecommend == zlibIndexShowMod.Recommend) {
                this.list_recommend()
              } else {
                this.list_search()
              }
              ListItem().height(__System__.bottomRectHeight + (__System__.windowWidth > minWidth? 10: 70))
            }
            .scrollBar(BarState.Off)
            .size({ width: '100%', height: '100%' })
            .onReachEnd(() => {
              if (__UI__.searchOrRecommend != zlibIndexShowMod.Recommend) {
                zlibClient.searchBooks(this.searchBookName, ++this.searchIndex, false)
              } else {
                zlibClient.getRecommendBooks(++this.recommendIndex)
              }
            })
            .edgeEffect(EdgeEffect.Spring)

          }

          if (__UI__.isInSearchMode) {
            Column()
              .size({ width: '100%', height: '100%' })
              .onClick(() => {
                XAnimation.runWithAnimation(() => {
                  __UI__.isInSearchMode = false
                })
              })
          }
        }.padding({ left: 20, right: 20 }).blur(__UI__.isInSearchMode? 50: 0)
      }

    }
    .size({ height: '100%', width: '100%' })
  }
}
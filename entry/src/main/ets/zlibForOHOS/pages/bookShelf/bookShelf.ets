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
import { I_BookInfo_Bookshelf, I_ReadLists_Bookshelf } from "../../datas/interfaces/I_BookShelf"
import { loadingNewDialog } from "../Builder"
import { curves } from "@kit.ArkUI"

@ComponentV2
export struct bookShelf{
  @Local bookShelfIndex: number = 1
  @Local isFlashing: boolean = false
  @Local waterFlowColumnNumber : number = -1
  @Local waterFlowEmptyItem: number[] = []

  build() {
    if ((zlibClient.bookshelfArray.dataArray.length == 0)) {
      Stack(){
        LoadingProgress()
          .size({ width: 150, height: 150 })
      }.size({width:'100%', height:'100%'})
    }else{
      Stack(){
        WaterFlow(){
          ForEach(this.waterFlowEmptyItem, ()=>{FlowItem().height(Math.max(16, __System__.topRectHeight))})
          LazyForEach(zlibClient.bookshelfArray,(item:I_ReadLists_Bookshelf)=>{
            FlowItem(){
              Column({space: 10}){
                Text(item.title).fontSize(18).fontWeight(FontWeight.Medium).maxLines(1).textOverflow({overflow: TextOverflow.Ellipsis})
                List({space: 10}){
                  ForEach(item.booksGrouped?.slice(0, 7),(itemB:I_BookInfo_Bookshelf)=>{
                    ListItem(){
                      Image(itemB.coverUrl)
                        .width(75)
                        .draggable(false)
                    }
                  })
                }.listDirection(Axis.Horizontal).scrollBar(BarState.Off).contentStartOffset(5).contentEndOffset(5).fadingEdge(true)
              }.alignItems(HorizontalAlign.Start)
            }
            .clickEffect({level: ClickEffectLevel.LIGHT, scale: 0.95})
            .transition(TransitionEffect.OPACITY
              .combine(TransitionEffect.scale({ x: 0.5, y: 0.5 }))
              .animation({ curve: curves.springMotion(0.5, 0.7) }))
            .backgroundColor($r('sys.color.comp_background_list_card'))
            .padding(15)
            .borderRadius(20)
            .onClick(()=>{
              zlibClient.getBookShelfMoreInfo(item.id,1)
            })
          })
          ForEach(this.waterFlowEmptyItem, ()=>{FlowItem().height(Math.max(__System__.bottomRectHeight + (__System__.windowWidth > minWidth? 0: 70), 16))})
        }.margin({left: 16, right: 16})
        .scrollBar(BarState.Off)
        .columnsTemplate(`repeat(${this.waterFlowColumnNumber},1fr)`)
        .columnsGap(10)
        .rowsGap(10)
        .onReachEnd(async () => {
          XAnimation.runWithAnimation(()=>this.isFlashing = true)
          await zlibClient.getBookShelf(++this.bookShelfIndex)
          XAnimation.runWithAnimation(()=>this.isFlashing = false)
        })
        .edgeEffect(EdgeEffect.Spring)
        if(this.isFlashing){
          loadingNewDialog()
        }
      }.size({width: '100%', height: '100%'})
      .onAreaChange((_, newValue)=>{
        XAnimation.runWithAnimation(()=>{
          this.waterFlowColumnNumber = Math.max(Math.floor(new Number(newValue.width).valueOf() / 300), 1)
          let itemList: number[] = []
          for (let index = 0; index < this.waterFlowColumnNumber; index++) {
            itemList.push(index)
          }
          this.waterFlowEmptyItem = itemList
        }, this.waterFlowColumnNumber > 0)
      })
    }
  }
}
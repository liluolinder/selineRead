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

import { minWidth, __System__ } from "../../datas/classes/ShareDatas"
import { XAnimation } from "../../datas/classes/XAnimation"
import { zlibClient } from "../../datas/classes/zlib"
import { I_BookInfo_Bookshelf, I_ReadLists_Bookshelf } from "../../datas/interfaces/I_BookShelf"
import { loadingNewDialog } from "../Builder"

@ComponentV2
export struct bookShelf{
  @Local bookShelfIndex: number = 1
  @Local isFlashing: boolean = false
  @Local waterFlowColumnNumber : number = -1
  @Local waterFlowEmptyItem: number[] = []

  aboutToAppear(): void {
    zlibClient.getBookShelf(1)
  }

  build() {
    Stack(){
      WaterFlow(){
        LazyForEach(zlibClient.bookshelfArray,(item:I_ReadLists_Bookshelf)=>{
          FlowItem(){
            Column({space: 5}){
              Text(item.title).fontSize(18).fontWeight(FontWeight.Medium).maxLines(1)
              List({space: 10}){
                ForEach(item.booksGrouped?.slice(0, 5),(itemB:I_BookInfo_Bookshelf)=>{
                  ListItem(){
                    Image(itemB.coverUrl)
                      .width(75)
                  }
                })
              }.listDirection(Axis.Horizontal).scrollBar(BarState.Off).contentStartOffset(20).contentEndOffset(20).fadingEdge(true)
            }.alignItems(HorizontalAlign.Start)
          }
          .backgroundColor($r('sys.color.comp_background_list_card'))
          .borderRadius(20)
          .onClick(()=>{
            zlibClient.getBookShelfMoreInfo(item.id,1)
          })
        })
      }.margin({left: 15, right: 15})
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
        this.waterFlowColumnNumber = Math.max(Math.ceil(new Number(newValue.width).valueOf() / 270), 2)
        let itemList: number[] = []
        for (let index = 0; index < this.waterFlowColumnNumber; index++) {
          itemList.push(index)
        }
        this.waterFlowEmptyItem = itemList
      }, this.waterFlowColumnNumber > 0)
    })
  }
}
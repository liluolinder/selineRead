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
/*
 * Copyright (c) 2024 Huawei Device Co., Ltd.
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import { curves } from '@kit.ArkUI'
import { __System__, minWidth } from '../../datas/classes/ShareDatas';
import { XAnimation } from '../../datas/classes/XAnimation';
import { zlibClient } from '../../datas/classes/zlib';
import { I_ReadLists_Bookshelf, I_BookInfo_Bookshelf } from '../../datas/interfaces/I_BookShelf';
import { loadingDialog, loadingNewDialog } from '../Builder';
import BookShelfPage from './bookShelf';

@ComponentV2
export struct bookShelf {
  @Provider('bookShelfNavPathStack') bookShelfNavPathStack: NavPathStack = new NavPathStack()

  @Builder
  Pages(name: string){
    if(name == 'bookShelfPage'){
      BookShelfPage()
    }else if(name == 'bookShelfList'){
      bookShelfList()
    }
  }

  build() {
    Navigation(this.bookShelfNavPathStack)
    .navDestination(this.Pages)
    .mode(NavigationMode.Stack)
      .onAppear(()=>{
        this.bookShelfNavPathStack.pushPathByName('bookShelfList', false)
      })
  }
}

@ComponentV2
export struct bookShelfList {
  @Local transitionEffect: TransitionEffect = TransitionEffect.IDENTITY;
  @Consumer('bookShelfNavPathStack') bookShelfNavPathStack: NavPathStack = new NavPathStack()
  @Local bookShelfIndex: number = 1
  @Local isFlashing: boolean = false
  @Local waterFlowColumnNumber : number = -1
  @Local waterFlowEmptyItem: number[] = []
  @Local isOpening: boolean = false



  build() {
    NavDestination(){
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
              .geometryTransition(item.id.toString(), { follow: true })
              .clickEffect({level: ClickEffectLevel.LIGHT, scale: 0.95})
              .transition(TransitionEffect.OPACITY
                .combine(TransitionEffect.scale({ x: 0.5, y: 0.5 }))
                .animation({ curve: curves.springMotion(0.5, 0.7) }))
              .backgroundColor($r('sys.color.comp_background_list_card'))
              .padding(15)
              .borderRadius(20)
              .onClick(async ()=>{
                XAnimation.runWithAnimation(()=> this.isOpening = true)
                zlibClient.bookshelfBooks.clearData()
                await zlibClient.getBookShelfMoreInfo(item.id,1)
                XAnimation.runWithAnimation(()=> this.isOpening = false)
                this.transitionEffect = TransitionEffect.OPACITY
                  .combine(TransitionEffect.scale({ x: 0.9, y: 0.9 }))
                  .animation({ curve: curves.springMotion(0.4, 0.7) })

                animateToImmediately({ curve: curves.springMotion(0.5, 0.8) }, () => {
                  this.bookShelfNavPathStack.pushPath({ name: 'bookShelfPage', param: item }, false);
                })
              })
            })
            ForEach(this.waterFlowEmptyItem, ()=>{FlowItem().height(Math.max(__System__.bottomRectHeight + (__System__.windowWidth > minWidth? 0: 70), 16))})
          }.margin({left: 16, right: 16})
          .scrollBar(BarState.Off)
          .columnsTemplate(`repeat(${this.waterFlowColumnNumber},1fr)`)
          .columnsGap(10)
          .rowsGap(10)
          .onReachEnd(async () => {
            this.isFlashing = true
            await zlibClient.getBookShelf(++this.bookShelfIndex)
            this.isFlashing = false
          })
          .edgeEffect(EdgeEffect.Spring)
          if(this.isFlashing){
            loadingNewDialog()
          }
          if(this.isOpening){
            loadingDialog()
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
    .backgroundColor($r('sys.color.comp_background_gray'))
    .transition(this.transitionEffect)
    .hideTitleBar(true)
    .hideToolBar(true)
    .onBackPressed(()=>{
      return true
    })
  }

}

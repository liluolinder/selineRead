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

import { curves } from '@kit.ArkUI'
import { globlContext, globlUIContext } from '../../../entryability/EntryAbility';
import { __System__, minWidth, __UI__, __CustomBackgroundData__ } from '../../datas/classes/ShareDatas';
import { XAnimation } from '../../datas/classes/XAnimation';
import { zlibClient } from '../../datas/classes/zlib';
import { I_ReadLists_Bookshelf, I_BookInfo_Bookshelf } from '../../datas/interfaces/I_BookShelf';
import { loadingDialog, loadingNewDialog } from '../Builder';
import BookListPage from './BookListPage';
import { common } from '@kit.AbilityKit';
import { setContinueState } from '../../utils/ToolsUtil';

@ComponentV2
export struct BookList {
  @Builder
  Pages(name: string) {
    if (name == 'bookShelfPage') {
      BookListPage()
    } else if (name == 'bookShelfList') {
      BookListList()
    }
  }

  build() {
    Navigation(__UI__.bookListPageStack)
      .navDestination(this.Pages)
      .mode(NavigationMode.Stack)
      .onAppear(() => {
        __UI__.bookListPageStack.pushPathByName('bookShelfList', false)
      })
  }
}

@ComponentV2
export struct BookListList {
  @Local transitionEffect: TransitionEffect = TransitionEffect.IDENTITY;
  @Local bookShelfIndex: number = 1
  @Local isFlashing: boolean = false
  @Local waterFlowColumnNumber: number = -1
  @Local waterFlowEmptyItem: number[] = []

  build() {
    NavDestination() {
      if ((zlibClient.bookshelfArray.dataArray.length == 0)) {
        Stack() {
          LoadingProgress()
            .size({ width: 150, height: 150 })
        }.size({ width: '100%', height: '100%' })
      } else {
        Stack() {
          WaterFlow() {
            ForEach(this.waterFlowEmptyItem, () => {
              FlowItem().height(Math.max(16, __System__.topRectHeight))
            })
            LazyForEach(zlibClient.bookshelfArray, (item: I_ReadLists_Bookshelf) => {
              FlowItem() {
                Column({ space: 10 }) {
                  Text(item.title)
                    .fontSize(18)
                    .fontWeight(FontWeight.Medium)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                  List({ space: 10 }) {
                    ForEach(item.booksGrouped?.slice(0, 7), (itemB: I_BookInfo_Bookshelf) => {
                      ListItem() {
                        Image(itemB.coverUrl)
                          .width(75)
                          .draggable(false)
                      }
                    })
                  }
                  .listDirection(Axis.Horizontal)
                  .scrollBar(BarState.Off)
                  .contentStartOffset(5)
                  .contentEndOffset(5)
                  .fadingEdge(true)
                }.alignItems(HorizontalAlign.Start)
              }
              .geometryTransition(item.id.toString(), { follow: true })
              .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.95 })
              .transition(TransitionEffect.OPACITY
                .combine(TransitionEffect.scale({ x: 0.5, y: 0.5 }))
                .animation({ curve: curves.springMotion(0.5, 0.7) }))
              .backgroundColor(__CustomBackgroundData__.customBackground ?
              $r('app.color.start_window_background_blur') : $r('sys.color.comp_background_list_card'))
              .backdropBlur(__CustomBackgroundData__.customBackground ? 100 : undefined)
              .useEffect(true)
              .padding(15)
              .borderRadius(20)
              .onClick(async () => {
                XAnimation.runWithAnimation(() => __BookListData__.isOpening = true)
                zlibClient.bookshelfBooks.clearData()
                await zlibClient.getBookShelfMoreInfo(item.id, 1)
                XAnimation.runWithAnimation(() => __BookListData__.isOpening = false)
                this.transitionEffect = TransitionEffect.OPACITY
                  .combine(TransitionEffect.scale({ x: 0.9, y: 0.9 }))
                  .animation({ curve: curves.springMotion(0.4, 0.7) })
                setContinueState(true, 'bookList', '', JSON.stringify(item))
                animateToImmediately({ curve: curves.springMotion(0.5, 0.8) }, () => {
                  __UI__.bookListPageStack.pushPath({ name: 'bookShelfPage', param: item }, false);
                })
              })
            }, (item: I_ReadLists_Bookshelf) => item.id.toString() + item.title)
            ForEach(this.waterFlowEmptyItem, () => {
              FlowItem()
                .height(Math.max(__System__.bottomRectHeight + (__System__.windowWidth > minWidth ? 0 : 70), 16))
            })
          }
          .margin({ left: 16, right: 16 })
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

          if (this.isFlashing) {
            loadingNewDialog()
          }
          if (__BookListData__.isOpening) {
            loadingDialog()
          }
        }.size({ width: '100%', height: '100%' })
        .onAreaChange((_, newValue) => {
          XAnimation.runWithAnimation(() => {
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
    .onAppear(async () => {
      await zlibClient.refreshUrl().then(async () => {
        zlibClient.getBookShelf(1)
      })
    })
    .backgroundColor(Color.Transparent)
    .transition(this.transitionEffect)
    .hideTitleBar(true)
    .hideToolBar(true)
    .onBackPressed(() => {
      return true
    })
  }
}

@ObservedV2
class bookList {
  @Trace isOpening: boolean = false
}

export const __BookListData__ = new bookList()
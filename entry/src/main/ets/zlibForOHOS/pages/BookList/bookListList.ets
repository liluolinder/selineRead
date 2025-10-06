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
import { globalContext, globalUIContext } from '../../../entryability/EntryAbility';
import { __System__, minWidth, __UI__, __CustomBackgroundData__ } from '../../datas/classes/ShareDatas';
import { XAnimation } from '../../datas/classes/XAnimation';
import { zlibClient } from '../../datas/classes/zlib';
import { I_ReadLists_Bookshelf, I_BookInfo_Bookshelf } from '../../datas/interfaces/I_BookShelf';
import { BookCover, loadingDialog, loadingNewDialog } from '../others/Builder';
import BookListPage from './BookListPage';
import { common } from '@kit.AbilityKit';
import { addLog, setContinueState } from '../../utils/ToolsUtil';
import { CJLoader } from '../../CJloader/CJLoader';
import { zlibIndexShowMod } from '../../datas/enums/zlibIndexShowMod';
import { I_SearchHistory } from '../../datas/interfaces/I_SearchHistory';
import { scanBarcode, scanCore } from '@kit.ScanKit';

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
  @Local scrollerOffset: number = 0

  build() {
    NavDestination() {
      if ((zlibClient.bookshelfArray.dataArray.length == 0)) {
        Stack() {
          LoadingProgress()
            .size({ width: 150, height: 150 })
        }.size({ width: '100%', height: '100%' })
      } else {
        Stack({alignContent: Alignment.Top}) {
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
                        BookCover({ data: itemB.coverUrl, haveShadow: false })
                          .width(75)
                      }
                    }, (itemB: I_BookInfo_Bookshelf) => itemB.cover)
                  }
                  .listDirection(Axis.Horizontal)
                  .scrollBar(BarState.Off)
                  .contentStartOffset(5)
                  .contentEndOffset(5)
                  .fadingEdge(true)
                }.alignItems(HorizontalAlign.Start)
              }
              .geometryTransition(item.id.toString())
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
                item.isLoved = await zlibClient.getBookShelfIsLoved(item)

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
          .onDidScroll((scrollOffset: number, scrollState: ScrollState) => {
            this.scrollerOffset += scrollOffset
          })
          .margin({ left: 16, right: 16 })
          .scrollBar(BarState.Off)
          .columnsTemplate(`repeat(${this.waterFlowColumnNumber},1fr)`)
          .columnsGap(10)
          .rowsGap(10)
          .onScrollStart(() => {
            __UI__.hideBars()
          })
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
          if (__UI__.displayTabs || this.scrollerOffset == 0) {
            Row({ space: 10 }) {

              Button({ type: ButtonType.Circle }) {
                SymbolGlyph($r('sys.symbol.circle_viewfinder'))
                  .fontSize(24)
                  .fontColor([$r('sys.color.font_secondary')])
              }
              .width(40)
              .height(40)
              .backgroundColor($r('app.color.start_window_background_blur'))
              .backdropBlur(100)
              .useEffect(true)
              .onClick(() => {
                //Todo: 左边按钮
              })
              .visibility(__BookListData__.isInSearchMode ? Visibility.None : Visibility.Visible)

              Search({ value: __BookListData__.searchWords })
                .onChange((text) => {
                  __BookListData__.searchWords = text
                })
                .backgroundColor($r('app.color.start_window_background_blur'))
                .backdropBlur(100)
                .useEffect(true)
                .layoutWeight(1)
                .focusable(__BookListData__.isInSearchMode)
                .enableKeyboardOnFocus(__BookListData__.isInSearchMode)
                .onSubmit((value: string) => {
                  //Todo: 提交搜索
                })
                .onChange((value: string) => {
                  if (value == '' || value == undefined) {
                    XAnimation.runWithAnimation(() => {
                      __BookListData__.searchOrRecommend = zlibIndexShowMod.Recommend
                    })
                  }
                })
                .onTouch(() => {
                  XAnimation.runWithAnimation(() => {
                    __BookListData__.isInSearchMode = true
                  })
                })

              Button({ type: ButtonType.Circle }) {
                SymbolGlyph($r('sys.symbol.satellite_map'))
                  .fontSize(24)
                  .fontColor([$r('sys.color.font_secondary')])
              }
              .width(40)
              .height(40)
              .backgroundColor($r('app.color.start_window_background_blur'))
              .backdropBlur(100)
              .useEffect(true)
              .onClick(() => {
                //Todo: 右边按钮
              })
              .visibility(__BookListData__.isInSearchMode ? Visibility.None : Visibility.Visible)
            }
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
  @Trace searchOrRecommend: zlibIndexShowMod = zlibIndexShowMod.Recommend //Todo: 搜索或者推荐
  @Trace isInSearchMode: boolean = false
  @Trace searchWords: string = ''
}

export const __BookListData__ = new bookList()
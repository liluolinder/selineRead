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

import { curves } from '@kit.ArkUI';
import { __System__, __UI__, minWidth, __CustomBackgroundData__ } from '../../datas/classes/ShareDatas';
import { XAnimation } from '../../datas/classes/XAnimation';
import { zlib, zlibClient } from '../../datas/classes/zlib';
import { zlibIndexShowMod } from '../../datas/enums/zlibIndexShowMod';
import { I_Bookshelf_extraBooks, I_ReadLists_Bookshelf } from '../../datas/interfaces/I_BookShelf';
import { setContinueState } from '../../utils/ToolsUtil';
import { loadingDialog, loadingNewDialog } from '../others/Builder';


@ComponentV2
export default struct BookListPage {
  @Local waterFlowColumnNumber: number = -1
  @Local waterFlowEmptyItem: number[] = []
  @Local isOpening: boolean = false
  @Local isFlashing: boolean = false
  @Local bookShelfIndex: number = 1
  private data: I_ReadLists_Bookshelf | undefined

  build() {
    NavDestination() {
      Stack({ alignContent: Alignment.Top }) {
        Column({ space: 10 }) {
          Row({ space: 10 }) {
            Button({ stateEffect: true }) {
              SymbolGlyph($r('sys.symbol.chevron_left')).fontSize(26).fontColor([$r('sys.color.font')])
            }
            .size({ width: 40, height: 40 })
            .backgroundColor(__CustomBackgroundData__.customBackground ? $r('app.color.start_window_background_blur') :
            $r('sys.color.comp_background_list_card'))
            .backdropBlur(__CustomBackgroundData__.customBackground ? 100 : undefined)
            .useEffect(true)
            .onClick(() => {
              setContinueState(false, 'home', '', '')
              animateToImmediately({ curve: curves.springMotion(0.5, 0.8) }, () => {
                __UI__.bookListPageStack.pop(false);
              })
            })

            Text(this.data?.title).fontSize(22).fontWeight(FontWeight.Medium)
          }

          WaterFlow() {
            LazyForEach(zlibClient.bookshelfBooks, (item: I_Bookshelf_extraBooks) => {
              FlowItem() {
                Column({ space: 20 }) {
                  Image(item.book.cover)
                    .draggable(false)
                    .size({ width: '100%' })
                    .shadow({
                      radius: 25,
                      color: Color.Gray,
                      offsetX: 0,
                      offsetY: 10
                    })

                  Column({ space: 2 }) {
                    Text(item.book.title)
                      .fontSize(16)
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.MARQUEE }).fontWeight(FontWeight.Medium)
                    Text(item.book.author)
                      .fontSize(12)
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis }).opacity(0.6)
                  }.alignItems(HorizontalAlign.Start)

                }.alignItems(HorizontalAlign.Start)
              }
              .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.95 })
              .padding(15)
              .width('100%')
              .backgroundColor(__CustomBackgroundData__.customBackground ?
              $r('app.color.start_window_background_blur') : $r('sys.color.comp_background_list_card'))
              .backdropBlur(__CustomBackgroundData__.customBackground ? 100 : undefined)
              .useEffect(true)
              .borderRadius(15)
              .transition(TransitionEffect.OPACITY
                .combine(TransitionEffect.scale({ x: 0.5, y: 0.5 }))
                .animation({ curve: curves.springMotion(0.5, 0.7) }))
              .onClick(async () => {
                this.isOpening = true
                await zlibClient.getBookInfo(item.book.href).then((res) => {
                  if (res.name != '' && res.name != undefined) {
                    res.bookID = item.id
                    res.image = item.book.cover
                    res.href = item.book.href
                    __UI__.HomePageStack.removeByName('bookInfoPage')
                    __UI__.HomePageStack.pushPathByName('bookInfoPage', res)
                  }
                  this.isOpening = false
                })
              })
            }, (item: string) => item)

            ForEach(this.waterFlowEmptyItem, () => {
              FlowItem()
                .height(Math.max(__System__.bottomRectHeight + (__System__.windowWidth > minWidth ? 0 : 70), 16))
            })
          }
          .borderRadius({ topLeft: 15, topRight: 15 })
          .clip(true)
          .rowsGap(10)
          .columnsGap(10)
          .onReachEnd(() => {
          })
          .edgeEffect(EdgeEffect.Spring)

          .onReachEnd(async () => {
            this.isFlashing = true
            await zlibClient.getBookShelfMoreInfo(this.data!.id, ++this.bookShelfIndex)
            this.isFlashing = false
          })
          .onAreaChange((_, newValue) => {
            XAnimation.runWithAnimation(() => {
              this.waterFlowColumnNumber = Math.max(Math.ceil(new Number(newValue.width).valueOf() / 240), 2)
              let itemList: number[] = []
              for (let index = 0; index < this.waterFlowColumnNumber; index++) {
                itemList.push(index)
              }
              this.waterFlowEmptyItem = itemList
            }, this.waterFlowColumnNumber > 0)
          })
          .columnsTemplate(`repeat(${this.waterFlowColumnNumber},1fr)`)
          .layoutWeight(1)
        }.alignItems(HorizontalAlign.Start).width('100%')
        .padding({ left: 16, right: 16, top: Math.max(16, __System__.topRectHeight) })
        .geometryTransition(this.data?.id.toString())

        if (this.isOpening) {
          loadingDialog()
        }
        if (this.isFlashing) {
          loadingNewDialog()
        }
      }
    }
    .transition(TransitionEffect.OPACITY)
    .hideTitleBar(true)
    .backgroundColor(Color.Transparent)
    .onReady((context: NavDestinationContext) => {
      this.data = context.pathInfo.param as I_ReadLists_Bookshelf
    })
    .onBackPressed(() => {
      setContinueState(false, 'home', '', '')
      animateToImmediately({ curve: curves.springMotion(0.5, 0.8) }, () => {
        __UI__.bookListPageStack.pop(false);
      })
      return true;
    })
  }
}
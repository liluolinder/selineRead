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

@ComponentV2
export struct bookShelf{
  @Local bookShelfIndex: number = 1
  build() {
    Column(){
      Text('正在开发')
     /* List({space:10}){
       LazyForEach(zlibClient.bookshelfArray,(item:I_ReadLists_Bookshelf)=>{
          ListItem(){
            Column(){
              Text(item.title)
              Scroll(){
                Row(){
                  ForEach(item.booksGrouped,(itemB:I_BookInfo_Bookshelf)=>{
                    Image(itemB.coverUrl)
                      .width(75)
                  })
                }
              }.scrollable(ScrollDirection.Horizontal)
            }
          }.height(200)
         .backgroundColor($r('sys.color.comp_background_list_card'))
         .borderRadius(20)
       })
        ListItem().height(__System__.bottomRectHeight + (__System__.windowWidth > minWidth? 10: 70))
      }.size({ height: '100%', width: '100%' })
      .onReachEnd(async () => {
       // XAnimation.runWithAnimation(()=>this.isFlashing = true)
        await zlibClient.getBookShelf(++this.bookShelfIndex)
        //XAnimation.runWithAnimation(()=>this.isFlashing = false)
      })
      .edgeEffect(EdgeEffect.Spring)*/
    }
    .padding({top:Math.max(__System__.topRectHeight, 16)})
    .size({ height: '100%', width: '100%' })
    .padding({ left: 16, right: 16 })
  }
}
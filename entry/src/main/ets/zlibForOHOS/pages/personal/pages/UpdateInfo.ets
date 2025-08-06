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

import { ComposeListItem } from "@ohos.arkui.advanced.ComposeListItem"
import { __System__ } from "../../../datas/classes/ShareDatas"
import { XAnimation } from "../../../datas/classes/XAnimation"
import { I_UpdateInfo } from "../../../datas/interfaces/I_UpdateInfo"


@Builder
export function UpdateInfoBuilder()
{
  UpdateInfo()
}

@ComponentV2
export struct UpdateInfo{

  @Local historyArray:I_UpdateInfo[]=[
    {version:'beta 0.0.4',date:'2025/8/6',optimizeArray:['UI优化','新增动画']},
    {version:'beta 0.0.3',date:'2025/8/5',addNewFunArray:['版本信息页面','鸣谢页面','打开仓库按钮','打开issues按钮']},
    {version:'beta 0.0.2',date:'2025/8/4',fixBugsArray:["重复入栈",'历史记录排序问题','深色模式bug','书籍图片异常比例','tabs伪卡顿','loding图标位置']},
    {version:'beta 0.0.1',date:'2025/7/28',addNewFunArray:["zlib推荐页面获取",'zlib下载','个人信息界面','下载通知','下载历史']},
  ]

  @Local currentIndex:number=-1

  listScroller:Scroller = new Scroller()

  build() {
    Column(){
      List({scroller:this.listScroller, space: 10}){

        ForEach(this.historyArray,(item:I_UpdateInfo,index:number)=>{

          ListItemGroup(){

            ComposeListItem({contentItem:{primaryText:item.version,secondaryText:item.date},operateItem:{icon:{value:index==this.currentIndex?$r('sys.media.ohos_ic_public_arrow_up'):$r('sys.media.ohos_ic_public_arrow_down')}}})

            if(index==this.currentIndex)
            {
              ListItem(){
                Column({space:5}){
                  if(item.addNewFunArray!=undefined){
                    Text("[新增功能]").width('100%')
                    ForEach(item.addNewFunArray,(newFun:string,indexA:number)=>{
                      Text(`${indexA+1}. ${newFun}`).width('100%').fontSize(14)

                    })
                  }

                  if(item.fixBugsArray!=undefined){
                    Text("[BUG修复]").width('100%')
                    ForEach(item.fixBugsArray,(fixBug:string,indexA:number)=>{
                      Text(`${indexA+1}. ${fixBug}`).width('100%').fontSize(14)
                    })
                  }

                  if(item.optimizeArray!=undefined){
                    Text("[优化更新]").width('100%')
                    ForEach(item.optimizeArray,(optimize:string,indexA:number )=>{
                      Text(`${indexA+1}. ${optimize}`).width('100%').fontSize(14)
                    })
                  }
                }
              }.width('100%').padding({left: 15, right: 15, bottom: 15}).opacity(0.9)
            }

          }
          .backgroundColor($r('sys.color.comp_background_list_card'))
          .borderRadius(20)
          .onClick(()=>{
           if(this.currentIndex==index){
             XAnimation.runWithAnimation(()=>{
               this.currentIndex=-1
             })
           }else {
             XAnimation.runWithAnimation(()=>{
               this.currentIndex=index
             })
           }
          })
        })

      }
      .contentEndOffset(Math.max(__System__.bottomRectHeight, 16))
      .scrollBar(BarState.Off)
      .chainAnimation(true)
      .borderRadius({topLeft: 20, topRight: 20})
      .margin({left: 16, right: 16})

    }
    .width('100%')
    .height('100%')
  }

}

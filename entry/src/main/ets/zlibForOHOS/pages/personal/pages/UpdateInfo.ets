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
    {version:'beta 0.0.1',date:'2025/2/26',addNewFunArray:["初步完善功能"]},
  ]

  @Local currentIndex:number=-1

  listScroller:Scroller = new Scroller()

  build() {
    Column(){
      List({scroller:this.listScroller}){

        ForEach(this.historyArray,(item:I_UpdateInfo,index:number)=>{

          ListItemGroup(){

            ComposeListItem({contentItem:{primaryText:item.version,secondaryText:item.date},operateItem:{icon:{value:index==this.currentIndex?$r('sys.media.ohos_ic_public_arrow_up'):$r('sys.media.ohos_ic_public_arrow_down')}}})

            if(index==this.currentIndex)
            {
              ListItem(){
                Column({space:5}){
                  if(item.addNewFunArray!=undefined){
                    Text("【新增功能】").width('100%')
                    ForEach(item.addNewFunArray,(newFun:string,indexA:number)=>{
                      Text(`${indexA+1}、${newFun}`).width('100%').margin({left:20})

                    })
                  }

                  if(item.fixBugsArray!=undefined){
                    Text("【BUG修复】").width('100%')
                    ForEach(item.fixBugsArray,(fixBug:string,indexA:number)=>{
                      Text(`${indexA+1}、${fixBug}`).width('100%').margin({left:20})
                    })
                  }

                  if(item.optimizeArray!=undefined){
                    Text("【优化更新】").width('100%')
                    ForEach(item.optimizeArray,(optimize:string,indexA:number )=>{
                      Text(`${indexA+1}、${optimize}`).width('100%').margin({left:20})
                    })
                  }
                }
              }.width('100%')
            }

          }
          .transition(XAnimation.getAnimation('bottom'))
          .onClick(()=>{
           if(this.currentIndex==index){
             XAnimation.runWithAnimation(()=>{
               this.currentIndex=-1
             },400)
           }else {
             XAnimation.runWithAnimation(()=>{
               this.currentIndex=index
             },400)
           }
          })
        })

      }.backgroundColor($r('sys.color.comp_background_list_card'))
      .width('90%')
      .scrollBar(BarState.Off)
      .borderRadius('20')
      .divider({ strokeWidth:0.5 ,color:$r('sys.color.comp_divider'), startMargin: 20, endMargin: 20 })

    }
    .backgroundColor($r('sys.color.comp_background_gray'))
    .width('100%')
    .height('100%')
  }

}

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
export function UpdateInfoBuilder() {
  UpdateInfo()
}

@ComponentV2
export struct UpdateInfo {
  @Local historyArray: I_UpdateInfo[] = [
    {
      version: 'beta 0.3.0',
      date: '2025/9/1',
      addNewFunArray:['新增查看大图(书籍详细页点击)','扫描条形码并自动搜索ISBN','运行日志'],
      optimizeArray: ['优化tab出现动画','优化动画曲线'],
    },
    {
      version: 'beta 0.2.2',
      date: '2025/8/28',
      optimizeArray: ['导出至格物阅读新增校验文件是否定存在'],
      fixBugsArray: ['后台下载异常问题','书单UI异常','首次打开APP个人信息不加载']
    },
    {
      version: 'beta 0.2.1',
      date: '2025/8/27',
      addNewFunArray: ['书架长按书籍直接导入格物阅读','搜索书籍展示主文件格式'],
      optimizeArray: ['新增鸣谢详细信息'],
      fixBugsArray: ['修复部分右侧箭头无法使用','修复后台下载不更新通知(本版本仍不建议后台下载，下载完成不会移动至下载目录)']
    },
    {
      version: 'beta 0.2.0',
      date: '2025/8/26',
      addNewFunArray: ['新增自定义API', '新增本地书导入', '新增API设置', '新增下载完自动分享设置', '新增书架拖动分享'],
      optimizeArray: ['优化动画', '更换icon(感谢群友:楠柒Zayn)', '优化部分展示效果', '优化书架展示',
        '优化书架书籍是否存在显示', '登录确定按钮位置移动'],
      fixBugsArray: ['修复重复加载', '内置阅读器首次打开异常']
    },
    {
      version: 'beta 0.1.0',
      date: '2025/8/16',
      addNewFunArray: ['新增书单', '新增引导注册页'],
      optimizeArray: ['优化Tab动画']
    },
    { version: 'beta 0.0.4', date: '2025/8/6', optimizeArray: ['UI优化', '新增动画'] },
    {
      version: 'beta 0.0.3',
      date: '2025/8/5',
      addNewFunArray: ['版本信息页面', '鸣谢页面', '打开仓库按钮', '打开issues按钮']
    },
    {
      version: 'beta 0.0.2',
      date: '2025/8/4',
      fixBugsArray: ["重复入栈", '历史记录排序问题', '深色模式bug', '书籍图片异常比例', 'tabs伪卡顿', 'loding图标位置']
    },
    {
      version: 'beta 0.0.1',
      date: '2025/7/28',
      addNewFunArray: ["zlib推荐页面获取", 'zlib下载', '个人信息界面', '下载通知', '下载历史']
    },
  ]
  @Local currentIndex: number = -1
  listScroller: Scroller = new Scroller()

  build() {
    Column() {
      List({ scroller: this.listScroller, space: 10 }) {

        ForEach(this.historyArray, (item: I_UpdateInfo, index: number) => {

          ListItemGroup() {

            ComposeListItem({
              contentItem: { primaryText: item.version, secondaryText: item.date },
              operateItem: {
                icon: {
                  value: index == this.currentIndex ? $r('sys.media.ohos_ic_public_arrow_up') :
                  $r('sys.media.ohos_ic_public_arrow_down'),
                  action:()=>{
                    if (this.currentIndex == index) {
                      XAnimation.runWithAnimation(() => {
                        this.currentIndex = -1
                      })
                    } else {
                      XAnimation.runWithAnimation(() => {
                        this.currentIndex = index
                      })
                    }
                  }
                }

              }
            })

            if (index == this.currentIndex) {
              ListItem() {
                Column({ space: 5 }) {
                  if (item.addNewFunArray != undefined) {
                    Text("[新增功能]").width('100%').fontWeight(FontWeight.Bold)
                    ForEach(item.addNewFunArray, (newFun: string, indexA: number) => {
                      Text(`${indexA + 1}. ${newFun}`).width('100%').fontSize(14)

                    })
                  }

                  if (item.fixBugsArray != undefined) {
                    Text("[BUG修复]").width('100%').fontWeight(FontWeight.Bold)
                    ForEach(item.fixBugsArray, (fixBug: string, indexA: number) => {
                      Text(`${indexA + 1}. ${fixBug}`).width('100%').fontSize(14)
                    })
                  }

                  if (item.optimizeArray != undefined) {
                    Text("[优化更新]").width('100%').fontWeight(FontWeight.Bold)
                    ForEach(item.optimizeArray, (optimize: string, indexA: number) => {
                      Text(`${indexA + 1}. ${optimize}`).width('100%').fontSize(14)
                    })
                  }
                }
              }.width('100%').padding({ left: 15, right: 15, bottom: 15 }).opacity(0.9)
            }

          }
          .transition(XAnimation.getAnimation('bottom'))
          .backgroundColor($r('sys.color.comp_background_list_card'))
          .borderRadius(20)
          .onClick(() => {
            if (this.currentIndex == index) {
              XAnimation.runWithAnimation(() => {
                this.currentIndex = -1
              })
            } else {
              XAnimation.runWithAnimation(() => {
                this.currentIndex = index
              })
            }
          })
        })

      }
      .contentEndOffset(Math.max(__System__.bottomRectHeight, 16))
      .scrollBar(BarState.Off)
      .chainAnimation(true)
      .borderRadius({ topLeft: 20, topRight: 20 })
      .margin({ left: 16, right: 16 })

    }
    .width('100%')
    .height('100%')
  }
}

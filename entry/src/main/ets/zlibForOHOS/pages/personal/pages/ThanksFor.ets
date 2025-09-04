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

import { promptAction } from "@kit.ArkUI"
import { productViewManager } from "@kit.StoreKit"
import { common, Want } from "@kit.AbilityKit"
import { XAnimation } from "../../../datas/classes/XAnimation"
import { I_Acknowledgment, I_Acknowledgment_List } from "../../../datas/interfaces/I_Acknowledgment"
import { globlContext } from "../../../../entryability/EntryAbility"
import { __System__ } from "../../../datas/classes/ShareDatas"


@Builder
export function TanksForBuilder() {
  TanksFor()
}

@ComponentV2
export struct TanksFor {
  @Local acknowledgmentArray: I_Acknowledgment_List[] = [
    {
      name: '主要开发人员',
      list: [
        {
          name: '琉离铟落linder',
          info: '后端开发',
          avatar: 'https://file.atomgit.com/uploads/user/1753793061913_4336.jpeg',
          bilibili: '473413928',
          atomgitHome: 'liluolinder'
        },
        {
          name: '乂心',
          info: '全栈开发',
          avatar: 'https://file.atomgit.com/uploads/user/1755279040850_9559.png',
          bilibili: '441929890',
          appInfo: '像素匠',
          appBundle: 'com.soulharbor.pixelartisan',
          atomgitHome: 'xheart1'
        },
        {
          name: '鱼-salmon',
          info: '前端开发',
          avatar: 'https://file.atomgit.com/uploads/user/1744210680007_2116.png',
          bilibili: '299579466',
          appInfo: '溏心音乐',
          appBundle: 'com.salmon.sweetmusic',
          atomgitHome: 'lqsxy'
        }
      ]
    },
    {
      name: '贡献者',
      list: [
        {
          name: '逝水秋生白',
          info: '技术支持',
          avatar: 'https://file.atomgit.com/uploads/user/1744968466315_9239.jpeg',
          bilibili: '476197206',
          appInfo: '云宫',
          appBundle: 'ai.CloudUI.Liquid',
          atomgitHome: 'cenber',
        },
        {
          name: '楠柒',
          info: '提供应用图标',
          avatar: $r("app.media.nanqi"),
          barrier: 'ICON绘制'
        },
        {
          name: '未定义',
          info: '格物阅读开发者',
          avatar: $r('app.media.avatar_weidingyi'),
          bilibili: '3546793237285117',
          appInfo: '格物阅读',
          appBundle: 'com.hm.ultimate.reader'
        },
        {
          name: '超爱mika',
          info: 'Bug测试',
          avatar: 'https://file.atomgit.com/uploads/user/1754226827763_9527.jpeg',
          barrier: '吉祥物'
        },
        {
          name: 'F-park',
          info: 'Bug测试',
          avatar: 'https://file.atomgit.com/uploads/user/1754322665099_6919.jpeg',
          atomgitHome: 'fpark',
          barrier: 'Bug测试'
        },
      ]
    }
  ]

  build() {
    Column() {

      List({ space: 10 }) {
        ForEach(this.acknowledgmentArray, (list: I_Acknowledgment_List, index0: number) => {

          ListItem(){
           Stack({alignContent: Alignment.Start}){
             Text(list.name).fontSize(20).fontWeight(FontWeight.Bold)
           } .width('100%').padding({left: 10, right: 10, top: 10})
          }.transition(XAnimation.getAnimation('bottom', index0 * 50))

          ForEach(list.list, (item: I_Acknowledgment, index: number)=>{
            ListItem() {

              RelativeContainer() {

                Image(item.avatar)
                  .width('55')
                  .height('55')
                  .clipShape(new Circle({ width: '55', height: '55' }))
                  .alignRules({
                    top: { anchor: "__container__", align: VerticalAlign.Top },
                    left: { anchor: '__container__', align: HorizontalAlign.Start }
                  })
                  .margin({ top: 10, left: 10 })
                  .id('avatar')
                  .draggable(false)

                Text(item.name)
                  .id('name')
                  .fontWeight(FontWeight.Medium)
                  .fontSize(20)
                  .margin({ left: 10 })
                  .alignRules({
                    top: { anchor: "avatar", align: VerticalAlign.Top },
                    left: { anchor: 'avatar', align: HorizontalAlign.End }
                  })
                Marquee({ start: true, src: item.info })
                  .margin({ left: 10, right: 10 })
                  .opacity(0.75)
                  .alignRules({
                    bottom: { anchor: "avatar", align: VerticalAlign.Bottom },
                    left: { anchor: 'avatar', align: HorizontalAlign.End },
                    right: { anchor: '__container__', align: HorizontalAlign.End }
                  })
                List({ space: 10 }) {
                  if (item.appInfo != undefined && item.appBundle != undefined) {
                    ListItem() {
                      Text(item.appInfo).fontColor($r('app.color.linder_blue'))
                    }
                    .width('80')
                    .height('30')
                    .backgroundColor($r('sys.color.comp_background_tertiary'))
                    .borderRadius(20)
                    .onClick(() => {
                      const wantParam: Want = {
                        parameters: {
                          bundleName: item.appBundle!,
                        }
                      }
                      productViewManager.loadProduct(globlContext as common.UIAbilityContext, wantParam);
                    })
                  }
                  if (item.githubHome != undefined) {
                    ListItem() {
                      Text("Github").fontColor($r('app.color.pixelartisan_blue'))
                    }
                    .width('80')
                    .height('30')
                    .backgroundColor($r('sys.color.comp_background_tertiary'))
                    .borderRadius(20)
                    .onClick(() => {
                      let want: Want = {
                        action: 'ohos.want.action.viewData',
                        entities: ['entity.system.browsable'],
                        uri: 'https://github.com/' + item.githubHome,
                      };
                      (globlContext as common.UIAbilityContext).startAbility(want)
                    })
                  }
                  if (item.atomgitHome != undefined) {
                    ListItem() {
                      Text("AtomGit").fontColor($r('app.color.pixelartisan_blue'))
                    }
                    .width('80')
                    .height('30')
                    .backgroundColor($r('sys.color.comp_background_tertiary'))
                    .borderRadius(20)
                    .onClick(() => {
                      let want: Want = {
                        action: 'ohos.want.action.viewData',
                        entities: ['entity.system.browsable'],
                        uri: 'https://atomgit.com/' + item.atomgitHome,
                      };
                      (globlContext as common.UIAbilityContext).startAbility(want)
                    })
                  }
                  if (item.bilibili != undefined) {
                    ListItem() {
                      Text("BiliBili").fontColor($r('app.color.linder_pink'))
                    }
                    .width('80')
                    .height('30')
                    .backgroundColor($r('sys.color.comp_background_tertiary'))
                    .borderRadius(20)
                    .onClick(() => {
                      let url: string = "bilibili://author/" + item.bilibili
                      let want: Want = {
                        bundleName: 'yylx.danmaku.bili',
                        abilityName: 'EntryAbility',
                        uri: url
                      };
                      (globlContext as common.UIAbilityContext).startAbility(want)
                    })
                  }
                  if (item.barrier != undefined) {
                    ListItem() {
                      Text(item.barrier).fontColor(Color.Black)
                    }
                    .width('80')
                    .height('30')
                    .backgroundColor($r('sys.color.comp_background_tertiary'))
                    .borderRadius(20)
                    .onClick(() => {
                      promptAction.showToast({ message: `怎么点都不会有更多的，哼(￢︿̫̿￢☆)😕` });
                    })
                  }
                }
                .scrollBar(BarState.Off)
                .margin({ top: 20, bottom: 10 })
                .listDirection(Axis.Horizontal)
                .alignRules({
                  top: { anchor: "avatar", align: VerticalAlign.Bottom },
                  left: { anchor: 'avatar', align: HorizontalAlign.Start },
                  right: { anchor: '__container__', align: HorizontalAlign.End }
                })

              }.width('100%')

            }
            .transition(XAnimation.getAnimation('bottom', (index + 1) * 50))
            .height('125')
            .width('100%')
            .backgroundColor($r('sys.color.comp_background_list_card'))
            .borderRadius(20)
          })

        })

      }
      .layoutWeight(1)
      .contentEndOffset(Math.max(__System__.bottomRectHeight, 16))
      .chainAnimation(true)
      .margin({ left: 16, right: 16 })
      .height('100%')
      .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
      .scrollSnapAlign(ScrollSnapAlign.START)
      .scrollBar(BarState.Off)
      .borderRadius({ topLeft: 20, topRight: 20 })

    }.width('100%')
    .height('100%')
  }
}
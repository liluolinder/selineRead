import { XAnimation, XContext } from "commonpackage"
import { I_Acknowledgment, I_Acknowledgment_List } from "../../models/interfaces/I_Acknowledgment"
import { Want } from "@kit.AbilityKit"
import { productViewManager } from "@kit.StoreKit"
import { __System__ } from "../../commons/shareDatas"


@Builder
export function AcknowledgmentsBuilder() {
  Acknowledgments()
}

@ComponentV2
export struct Acknowledgments {
  @Local acknowledgmentArray: I_Acknowledgment_List[] = [
    {
      name: '主要开发人员',
      list: [
        {
          name: '逝水秋生白',
          info: 'LiqD创始人,技术支持',
          avatar: 'https://cdn-img.gitcode.com/ef/ea/e8f2031e20af14b49d3af2f95fbab0ab9d3174554926d8c067e9d0d603f9adcf.png',
          bilibili: '476197206',
          appInfo: 'Lookless',
          appBundle: 'ai.Lookless.Liquid',
          gitcodeHome: 'cenber',
        },
        {
          name: '鱼-salmon',
          info: '前端开发',
          avatar: 'https://cdn-img.gitcode.com/bc/cf/0bccfbf3a76b918e950c96444d7f244c0c237da5b50d0cd9c594bae061295ace.jpg',
          bilibili: '299579466',
          appInfo: '溏心音乐',
          appBundle: 'com.salmon.sweetmusic',
          gitcodeHome: 'lqsxy'
        },
        {
          name: '乂心',
          info: '全栈开发',
          avatar: 'https://file.atomgit.com/uploads/user/1755279040850_9559.png',
          bilibili: '441929890',
          appInfo: '像素匠',
          appBundle: 'com.soulharbor.pixelartisan',
          gitcodeHome: 'xheart1'
        },
        {
          name: '琉离铟落linder',
          info: '后端开发',
          avatar: 'https://cdn-img.gitcode.com/ea/fa/ea0f2458a55fb2a36d3b99819c3d9c46a89b6a6b97ff6c86f2935b6b6e17a98a.png',
          bilibili: '473413928',
          gitcodeHome: 'liluolinder'
        },
      ]
    },
    {
      name: '贡献者',
      list: [
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
          avatar: 'https://cdn-img.gitcode.com/aa/bd/2aa79bd82b63c6146cd8bfbb8ce4edbbd189b2888a9b776ae1c172d186980e05.png',
          barrier: '吉祥物'
        },
      ]
    }
  ]

  build() {
    NavDestination(){
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
                        productViewManager.loadProduct(XContext.getAbilityContext(), wantParam);
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
                        XContext.getAbilityContext().startAbility(want)
                      })
                    }
                    if (item.gitcodeHome != undefined) {
                      ListItem() {
                        Text("GitCode").fontColor($r('app.color.pixelartisan_blue'))
                      }
                      .width('80')
                      .height('30')
                      .backgroundColor($r('sys.color.comp_background_tertiary'))
                      .borderRadius(20)
                      .onClick(() => {
                        let want: Want = {
                          action: 'ohos.want.action.viewData',
                          entities: ['entity.system.browsable'],
                          uri: 'https://gitcode.com/' + item.gitcodeHome,
                        };
                        XContext.getAbilityContext().startAbility(want)
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
                        XContext.getAbilityContext().startAbility(want)
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
                        XContext.toast(`怎么点都不会有更多的，哼(￢︿̫̿￢☆)😕` );
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
    .size({ width: '100%', height: '100%' })
    .backgroundColor($r('sys.color.background_tertiary'))
    .title($r('app.string.Title_Acknowledgments'))
  }
}
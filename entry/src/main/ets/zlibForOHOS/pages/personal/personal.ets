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


import { __System__, __User__, minWidth, __UI__ } from '../../datas/classes/ShareDatas';
import { CircleShape, ComposeListItem, CustomContentDialog, promptAction } from '@kit.ArkUI';
import { zlibClient } from '../../datas/classes/zlib';
import NeoPreferencesUtil from '../../datas/classes/XPreferencesUtil';
import { globlContext } from '../../../entryability/EntryAbility';
import { common, Want } from '@kit.AbilityKit';
import { UpdateInfoBuilder } from './pages/UpdateInfo';
import { TanksForBuilder } from './pages/ThanksFor';
import { XAnimation } from '../../datas/classes/XAnimation';
import { pasteboard } from '@kit.BasicServicesKit';
import { settingsBuilder } from './pages/Settings/Settings';
import { loggerBuilder, LoggerPage } from './pages/LoggerPage';

@ComponentV2
export struct personal {
  @Local userAccount: string = ''
  @Local userPassword: string = ''
  @Local showDownloadLimitTips: boolean = false
  @Local showDonationTips: boolean = false
  @Local showLoginInOrRegister:boolean = false
  @Local showUpdateInfo: boolean = false
  @Local showTanks: boolean = false
  @Local pageWidth: number = -1

  buttonsArray: string[] = [
    '设置', '版本信息'
  ]
  buttonsArray2: string[] = [
    '鸣谢', '开源仓库', '问题反馈'
  ]

  zlibLoginDialogController: CustomDialogController = new CustomDialogController({
    builder: CustomContentDialog({
      primaryTitle: 'zlib登录',
      contentBuilder: () => {
        this.loginPageBuilder()
      },

      buttons: [
        {
          value: '取消',
          buttonStyle: ButtonStyleMode.TEXTUAL,
          role: ButtonRole.ERROR,
          action: () => {
            this.userAccount = ''
            this.userPassword = ''
          }
        },
        {
          value: '确定',
          buttonStyle: ButtonStyleMode.TEXTUAL,
          action: () => {
            zlibClient.loginIn(this.userAccount, this.userPassword)
            this.userAccount = ''
            this.userPassword = ''
          }
        }
      ],

    }),
  });


  @Builder
  loginPageBuilder() {
    Column({ space: 10 }) {
      Column({ space: 5 }) {
        Text("账号:")
          .fontWeight(FontWeight.Medium)
          .fontSize(18)
          .width('100%')

        TextInput({ placeholder: '请输入账号', text: $$this.userAccount })
          .height(40)


      }.width('100%')

      Column({ space: 5 }) {
        Text("密码:")
          .fontWeight(FontWeight.Medium)
          .fontSize(18)
          .width('100%')

        TextInput({ placeholder: '请输入密码', text: $$this.userPassword })
          .type(InputType.Password)
          .showUnderline(true)
          .height(40)

      }.width('100%')
    }.width('100%')
    .padding({ left: 16, right: 16 })
  }



  @Builder
  loginOrRegister()
  {
    Column(){
      List({space:20}){
        ComposeListItem({
          contentItem:{
            primaryText:'登录'
          }
        }).backgroundColor($r('sys.color.comp_background_list_card'))
          .borderRadius(10)
          .onClick(()=>{
            this.zlibLoginDialogController.open()
            this.showLoginInOrRegister = false
          })

        ComposeListItem({
          contentItem:{
            primaryText:'注册'
          }
        }).backgroundColor($r('sys.color.comp_background_list_card'))
          .borderRadius(10)
          .onClick(()=>{
            AlertDialog.show({
              title: '提醒',
              message: '即将打开网站',
              autoCancel: true,
              primaryButton: {
                value: '取消',
                action: () => {
                }
              },
              secondaryButton: {
                enabled: true,
                defaultFocus: true,
                style: DialogButtonStyle.HIGHLIGHT,
                value: '确定',
                action: () => {
                  let want: Want = {
                    action: 'ohos.want.action.viewData',
                    entities: ['entity.system.browsable'],
                    uri: zlibClient.base_url,
                  };
                  (globlContext as common.UIAbilityContext).startAbility(want)
                }
              }
            })
            this.showLoginInOrRegister = false
          })
      }
    }.padding({left:16, right:16,bottom:50})
  }


  build() {
    Column() {
      List({ space: 10 }) {

        if(__UI__.onlineMode){
          ListItem() {
            Row({ space: 15 }) {
              if(zlibClient.userInfo?.avatar){
                Image(zlibClient.userInfo?.avatar)
                  .width(80)
                  .height(80)
                  .borderRadius(40)
              }else{
                Stack(){
                  SymbolGlyph($r('sys.symbol.person')).opacity(0.5).fontColor([$r('sys.color.font')]).fontSize(40)
                }.backgroundColor($r('sys.color.comp_background_gray'))
                .width(80)
                .height(80)
                .borderRadius(40)
              }


              Column({ space: 5 }) {
                Text(__User__.isLoginZlib ? zlibClient.userInfo?.userName??'正在获取' : '点击登录')
                  .fontSize(18).maxLines(2)
                  .fontWeight(FontWeight.Medium)
                if (__User__.isLoginZlib) {
                  Button({stateEffect: true}){
                    SymbolGlyph($r('sys.symbol.arrow_right_and_square')).fontSize(18).fontColor([$r('sys.color.font')])
                  }
                  .size({ width: 30, height: 30 })
                  .backgroundColor(Color.Transparent)
                  .opacity(0.8)
                  .clickEffect({level: ClickEffectLevel.LIGHT, scale: 0.9})
                  .onClick(() => {
                    NeoPreferencesUtil.putPreferencesValue('selineRead', "isLoginZlib", false)
                    NeoPreferencesUtil.putPreferencesValue('selineRead', "zlibAccount", '')
                    NeoPreferencesUtil.putPreferencesValue('selineRead', "zlibPassword", '')
                    __User__.zlibAccount = ''
                    __User__.zlibPassword = ''
                    __User__.isLoginZlib = false
                  })
                }
              }.layoutWeight(1).alignItems(HorizontalAlign.Start)
            }.size({ width: '100%', height: '100%' })
            .padding(15)
          }.size({ width: '100%', height: 120 })
          .backgroundColor($r('sys.color.comp_background_list_card'))
          .borderRadius(20)
          .bindSheet($$this.showLoginInOrRegister,this.loginOrRegister(),{
            title:{title:'注册/登录'},
            preferType:SheetType.CENTER,
            height:SheetSize.FIT_CONTENT
          })
          .onClick(() => {
            if (!__User__.isLoginZlib) {
              this.showLoginInOrRegister = true
            }
          })
          .transition(XAnimation.getAnimation('bottom'))

          ListItem() {
            Row({ space: 10 }) {
              Stack() {
                Column({ space: 15 }) {
                  SymbolGlyph($r('sys.symbol.download'))
                    .fontSize(30)
                    .fontWeight(FontWeight.Medium)
                    .fontColor([$r('sys.color.font')])


                  if (zlibClient.userInfo?.downloadLimit != undefined) {
                    Text(zlibClient.userInfo?.downloadLimit)
                      .fontWeight(FontWeight.Medium)
                      .fontSize(18)

                  }
                }
              }
              .layoutWeight(1)
              .height('100%')
              .backgroundColor($r('sys.color.comp_background_list_card'))
              .borderRadius(20)
              .bindPopup($$this.showDownloadLimitTips, {
                message: '下载限制是Zlibrary官方设置的,可以通过对zlib官网捐赠提高限制值',
                onStateChange: (e) => {
                  this.showDownloadLimitTips = e.isVisible
                }
              })
              .onClick(() => {
                this.showDownloadLimitTips = true;
              })

              Stack() {
                Column({ space: 15 }) {
                  SymbolGlyph($r('sys.symbol.yuansign_moneybag'))
                    .fontSize(30)
                    .fontWeight(FontWeight.Medium)
                    .fontColor([$r('sys.color.font')])
                  if (zlibClient.userInfo?.donation != undefined) {
                    Text(zlibClient.userInfo?.donation)
                      .fontWeight(FontWeight.Medium)
                      .fontSize(18)
                  }
                }
              }
              .layoutWeight(1)
              .height('100%')
              .backgroundColor($r('sys.color.comp_background_list_card'))
              .borderRadius(20)
              .bindPopup(this.showDonationTips, {
                message: '此处捐赠额度指的是对zlib官方的捐赠，不是对此APP开发者的捐赠',
                onStateChange: (e) => {
                  this.showDonationTips = e.isVisible
                }
              })
              .onClick(() => {
                this.showDonationTips = true;
                console.log(`FUCK${this.showDonationTips}`)
              })

            }

          }.size({ width: '100%', height: 120 }).transition(XAnimation.getAnimation('bottom'))
        }

        ListItemGroup() {
          ForEach(this.buttonsArray, (item: string, index: number) => {
            ComposeListItem({
              contentItem: { primaryText: item },
              operateItem: { icon: { value: $r('sys.media.ohos_ic_public_arrow_right'),action:()=>{
                switch (index){
                  case 0:
                    __UI__.showSettings = true
                    break
                  case 1:
                    this.showUpdateInfo = true;
                    break
                }
              } } }
            }).onClick(() => {
              switch (index){
                case 0:
                  __UI__.showSettings = true
                  break
                case 1:
                  this.showUpdateInfo = true;
                  break
              }
            })
          })
        }
        .divider({
          strokeWidth: 0.5,
          color: $r('sys.color.comp_divider'),
          startMargin: 18,
          endMargin: 18
        })
        .bindSheet($$this.showUpdateInfo, UpdateInfoBuilder(), {
          preferType: SheetType.CENTER,
          title: { title: '版本更新信息' },
          height: SheetSize.LARGE,
        })
        .borderRadius(20)
        .backgroundColor($r('sys.color.comp_background_list_card'))
        .padding({ bottom: 6, top: 6 })
        .transition(XAnimation.getAnimation('bottom'))

        ListItemGroup() {
          ForEach(this.buttonsArray2, (item: string, index: number) => {
            ComposeListItem({
              contentItem: { primaryText: item },
              operateItem: { icon: { value: $r('sys.media.ohos_ic_public_arrow_right') ,action:()=>{
                if (index == 0) {
                  this.showTanks = true;
                  return
                }
                let url: string = ''
                if (index == 1) {
                  url = 'https://atomgit.com/liluolinder/selineRead'
                } else if (index == 2) {
                  url = 'https://atomgit.com/liluolinder/selineRead/issues'
                }

                AlertDialog.show({
                  title: '提醒',
                  message: '即将打开网站',
                  autoCancel: true,
                  primaryButton: {
                    value: '取消',
                    action: () => {
                    }
                  },
                  secondaryButton: {
                    enabled: true,
                    defaultFocus: true,
                    style: DialogButtonStyle.HIGHLIGHT,
                    value: '确定',
                    action: () => {
                      let want: Want = {
                        action: 'ohos.want.action.viewData',
                        entities: ['entity.system.browsable'],
                        uri: url,
                      };
                      (globlContext as common.UIAbilityContext).startAbility(want)
                    }
                  }
                })
              }} }
            }).onClick(() => {
              if (index == 0) {
                this.showTanks = true;
                return
              }
              let url: string = ''
              if (index == 1) {
                url = 'https://atomgit.com/liluolinder/selineRead'
              } else if (index == 2) {
                url = 'https://atomgit.com/liluolinder/selineRead/issues'
              }

              AlertDialog.show({
                title: '提醒',
                message: '即将打开网站',
                autoCancel: true,
                primaryButton: {
                  value: '取消',
                  action: () => {
                  }
                },
                secondaryButton: {
                  enabled: true,
                  defaultFocus: true,
                  style: DialogButtonStyle.HIGHLIGHT,
                  value: '确定',
                  action: () => {
                    let want: Want = {
                      action: 'ohos.want.action.viewData',
                      entities: ['entity.system.browsable'],
                      uri: url,
                    };
                    (globlContext as common.UIAbilityContext).startAbility(want)
                  }
                }
              })
            })
          })

          ComposeListItem({
            contentItem: { primaryText: '反馈QQ群' },
            operateItem: { text:'718559395'}
          }).onClick(()=>{
            let pasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, '718559395');
            pasteboard.getSystemPasteboard().setData(pasteData) //写入剪切板
            promptAction.showToast({
              message:'复制成功',
              duration: 2000
            });
          })

        }
        .transition(XAnimation.getAnimation('bottom'))
        .bindSheet($$this.showTanks, TanksForBuilder(), {
          preferType: SheetType.CENTER,
          title: { title: '鸣谢' },
          height: SheetSize.LARGE,
        })
        .divider({
          strokeWidth: 0.5,
          color: $r('sys.color.comp_divider'),
          startMargin: 18,
          endMargin: 18
        })
        .borderRadius(20)
        .backgroundColor($r('sys.color.comp_background_list_card'))
        .padding({ bottom: 6, top: 6 })

      }
      .bindSheet(__UI__.showLogger, loggerBuilder(), {
        preferType: SheetType.CENTER,
        height: SheetSize.LARGE,
        title: {title: '运行日志'},
        onDisappear: ()=> __UI__.showLogger = false
      })
      .contentStartOffset(Math.max(__System__.topRectHeight, 16))
      .contentEndOffset(Math.max(__System__.bottomRectHeight + (__System__.windowWidth > minWidth ? 0 : 80), 16))
      .lanes(this.pageWidth > minWidth ? 2 : 1, 10)
      .scrollBar(BarState.Off)
      .chainAnimation(true)

    }
    .onAppear(()=>{
      if(__User__.isLoginZlib && __UI__.onlineMode){
        zlibClient.refreshUrl().then(async () => {
          zlibClient.getUserInfo()
        })

      }
    })
    .size({ height: '100%', width: '100%' })
    .padding({ left: 16, right: 16 })
    .onAreaChange((_, newValue) => {
      XAnimation.runWithAnimation(() => {
        this.pageWidth = new Number(newValue.width).valueOf()
      }, this.pageWidth > 0)
    })
    .bindSheet(__UI__.showSettings, settingsBuilder(), {
      preferType: SheetType.CENTER,
      height: SheetSize.LARGE,
      onDisappear: ()=> __UI__.showSettings = false
    })
  }
}
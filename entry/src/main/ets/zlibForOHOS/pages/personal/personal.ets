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


import { FunctionalButton, functionalButtonComponentManager } from '@kit.ScenarioFusionKit';
import { __System__, __User__ } from '../../datas/classes/ShareDatas';
import { linderPixelMap } from '../../datas/classes/LPixelMap';
import { ComposeListItem, CustomContentDialog } from '@kit.ArkUI';
import { zlibClient } from '../../datas/classes/zlib';
import NeoPreferencesUtil from '../../datas/classes/XPreferencesUtil';
import { globlContext } from '../../../entryability/EntryAbility';
import { common, Want } from '@kit.AbilityKit';
import { UpdateInfo, UpdateInfoBuilder } from './pages/UpdateInfo';
import { TanksForBuilder } from './pages/ThanksFor';

@ComponentV2
export struct personal {
  @Local userAccount: string = ''
  @Local userPassword: string = ''
  @Local showDownloadLimitTips: boolean = false
  @Local showDonationTips: boolean = false
  @Local showUpdateInfo: boolean = false
  @Local showTanks: boolean = false
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
          value: '确定',
          buttonStyle: ButtonStyleMode.TEXTUAL,
          action: () => {
            zlibClient.loginIn(this.userAccount, this.userPassword)
            this.userAccount = ''
            this.userPassword = ''
          }
        },
        {
          value: '取消',
          buttonStyle: ButtonStyleMode.TEXTUAL,
          role: ButtonRole.ERROR,
          action: () => {
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

  build() {
    Column() {
      List({ space: 15 }) {
        ListItem() {
          Row() {
            FunctionalButton({
              params: {
                // OpenType.CHOOSE_AVATAR indicates that the button is used to select an avatar.
                openType: functionalButtonComponentManager.OpenType.CHOOSE_AVATAR,
                label: '',
                // Adjust the button style.
                styleOption: {
                  styleConfig: new functionalButtonComponentManager.ButtonConfig()
                    .type(ButtonType.Circle)
                    .backgroundImage(__User__.avatar)
                    .backgroundImageSize(ImageSize.Contain)
                    .width(80)
                    .height(80)
                    .backgroundColor('#E5E5E5')
                },
              },
              // When OpenType is set to CHOOSE_AVATAR, the callback must be onChooseAvatar.
              controller: new functionalButtonComponentManager.FunctionalButtonController().onChooseAvatar(async (err,
                data) => {
                if (err) {
                  return;
                }
                try {
                  __User__.avatar = data.avatarUri!
                  const pixelMap = await linderPixelMap.createPixelMAp(data.avatarUri!)
                  linderPixelMap.savePixelMapToSandBox(pixelMap, getContext().filesDir + '/avatar.jpg')
                } catch (err) {
                }
              })
            })

            Column() {
              Text(__User__.isLoginZlib ? __User__.zlibAccount : '点击登录')
                .fontSize(18)
                .fontWeight(FontWeight.Medium)
                .margin({ left: 15 })
              if (__User__.isLoginZlib) {
                Image($r('app.media.logoff'))
                  .size({ width: 25, height: 25 })
                  .fillColor($r('sys.color.font'))
                  .onClick(() => {
                    NeoPreferencesUtil.putPreferencesValue('selineRead', "isLoginZlib", false)
                    NeoPreferencesUtil.putPreferencesValue('selineRead', "zlibAccount", '')
                    NeoPreferencesUtil.putPreferencesValue('selineRead', "zlibPassword", '')
                    __User__.zlibAccount = ''
                    __User__.zlibPassword = ''
                    __User__.isLoginZlib = false
                  })
                  .margin({ top: 10, left: 15 })
                  .alignSelf(ItemAlign.Start)
              }
            }
          }.size({ width: '100%', height: '100%' })
          .padding(15)
        }.size({ width: '100%', height: 120 })
        .backgroundColor($r('sys.color.comp_background_list_card'))
        .borderRadius(20)
        .onClick(() => {
          if (!__User__.isLoginZlib) {
            this.zlibLoginDialogController.open()
          }
        })

        ListItem() {
          Grid() {
            GridItem() {
              Column({ space: 15 }) {
                SymbolGlyph($r('sys.symbol.download'))
                  .fontSize(30)
                  .fontWeight(FontWeight.Medium)
                  .fontColor([$r('sys.color.font')])

                if (zlibClient.userDownloadLimitAndDonation?.downloadLimit == undefined) {
                  LoadingProgress()
                    .size({ width: 30, height: 30 })
                } else {
                  Text() {
                    Span(zlibClient.userDownloadLimitAndDonation?.downloadLimit)
                    Span(' ')
                    SymbolSpan($r('sys.symbol.questionmark_circle'))
                      .fontColor([$r('sys.color.font')])
                  }
                  .fontWeight(FontWeight.Medium)
                  .fontSize(18)
                }


              }.bindPopup($$this.showDownloadLimitTips, {
                message: '下载限制是Zlibrary官方设置的,可以通过对zlib官网捐赠提高限制值',
                onStateChange: (e) => {
                  this.showDownloadLimitTips = e.isVisible
                }
              })
              .onClick(() => {
                this.showDownloadLimitTips = true;
              })

            }.size({ width: '100%', height: '100%' })
            .backgroundColor($r('sys.color.comp_background_list_card'))
            .borderRadius(20)

            GridItem() {
              Column({ space: 15 }) {
                SymbolGlyph($r('sys.symbol.yuansign_moneybag'))
                  .fontSize(30)
                  .fontWeight(FontWeight.Medium)
                  .fontColor([$r('sys.color.font')])
                if (zlibClient.userDownloadLimitAndDonation?.donation == undefined) {
                  LoadingProgress()
                    .size({ width: 30, height: 30 })
                } else {
                  Text() {
                    Span(zlibClient.userDownloadLimitAndDonation?.donation)
                    Span(' ')
                    SymbolSpan($r('sys.symbol.questionmark_circle'))
                      .fontColor([$r('sys.color.font')])

                  }
                  .fontSize(18)
                  .fontWeight(FontWeight.Medium)
                }


              }
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
            }.size({ width: '100%', height: '100%' })
            .backgroundColor($r('sys.color.comp_background_list_card'))
            .borderRadius(20)
          }.columnsTemplate('repeat(2,1fr)')
          .columnsGap(15)
          .size({ width: '100%', height: '100%' })
        }.size({ width: '100%', height: 120 })

        ListItemGroup() {
          ForEach(this.buttonsArray, (item: string, index:number) => {
            ComposeListItem({
              contentItem: { primaryText: item },
              operateItem: { icon: { value: $r('sys.media.ohos_ic_public_arrow_right') } }
            }).onClick(()=>{
              if (index==1) {
                this.showUpdateInfo = true;
              }
            })
          })
        }.divider({
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

        ListItemGroup() {
          ForEach(this.buttonsArray2, (item: string, index: number) => {
            ComposeListItem({
              contentItem: { primaryText: item },
              operateItem: { icon: { value: $r('sys.media.ohos_ic_public_arrow_right') } }
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
        }
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
      .lanes(__System__.currentBreakpoint === 'sm' ? 1 : 2, 10)
      .scrollBar(BarState.Off)

    }
    .size({ height: '100%', width: '100%' })
    .padding({ left: 16, right: 16, top: 5 })
  }
}
import { relationalStore } from "@kit.ArkData";
import { __UI__, __ZlibUser__ } from "../../../../commons/shareDatas";
import { I_BasicUserInfo, I_ZlibUserInfo } from "../../../../../zlibrary/interface/I_ZlibUserInfo";
import { ListItemWithInput, ListItemWithRadio, ListItemWithToggle } from "templatecomponent";
import { SymbolGlyphModifier } from "@kit.ArkUI";
import { __CustomBackgroundData__ } from "../../../../components/CustomBackground";
import { XAnimation, XContext, XPreferencesManager } from "commonpackage";
import { ZlibLoginSheetBuilder } from "./zlibraryLoginSheet";
import { RelationStoreManager } from "../../../../models/classes/DataBase";
import { zlibClient } from "../../../../../zlibrary/zlibClient";
import { ZlibUserInfo } from "../../../../../zlibrary/classes/UserInfo";
import { http } from "@kit.NetworkKit";
import { __Home__ } from "../../Home/Home";
import { I_BookInfo } from "../../../../models/interfaces/I_BookInfo";
import { I_loginRes_user } from "../../../../../zlibrary/interface/I_loginInfo";
import { I_ZlibBookInfoRes_Book, I_ZLibRecommendBook_Book } from "../../../../../zlibrary/interface/I_ZlibBookInfo";
import { ZlibSetting } from "./ZlibSetting";

@Builder
export function ZlibraryAccountBuilder() {
  ZlibraryAccount()
}

@ComponentV2
export struct ZlibraryAccount {
  @Local showDownloadLimitTips: boolean = false
  @Local showDonationTips: boolean = false
  @Provider('showZlibSetting') showZlibSetting: boolean = false
  @Provider('showZlibLoginSheet') showLoginSheet: boolean = false

  async aboutToAppear(): Promise<void> {
    await RelationStoreManager.getZlibAccount(__ZlibUser__.dataBase)

  }

  @Builder
  editCustom(item: ZlibUserInfo, index: number) {
    Column() {
      Button({ type: ButtonType.Circle }) {
        SymbolGlyph($r('sys.symbol.trash_fill'))
          .fontSize(28)
          .fontColor([Color.White])

      }.padding(8)
      .backgroundColor($r('sys.color.warning'))
      .onClick(() => {
        __ZlibUser__.zlibAccountArray.deleteData(index)
        let predicates = new relationalStore.RdbPredicates('ZlibraryAccount')
        predicates.equalTo('Account', item.account).equalTo("Password", item.password)
        RelationStoreManager.deleteValue(__ZlibUser__.dataBase, predicates)
        if (item.account == __ZlibUser__.account && item.password == __ZlibUser__.password) {
          __ZlibUser__.account = ''
          __ZlibUser__.password = ''
          __ZlibUser__.userName = ''
          __ZlibUser__.cookie = ''
          XPreferencesManager.putPreferencesValue('selineRead', "zlibAccount", '')
          XPreferencesManager.putPreferencesValue('selineRead', "zlibPassword", '')
          XPreferencesManager.putPreferencesValue('selineRead', "zlibCookie", '')
        }
      })
    }.padding({ left: 16, right: 16 })
  }

  @Builder
  ZlibSettingBuilder() {
    Column() {
      ZlibSetting()
    }.width('100%')
  }

  build() {
    NavDestination() {
      Stack() {
        if (__ZlibUser__.zlibAccountArray.dataArray.length == 0) {
          Column() {
            Text('还没有账号欸,添加一个吧')
              .fontSize(24)
              .fontWeight(FontWeight.Bold)
          }.size({ width: '100%', height: '100%' })
          .justifyContent(FlexAlign.Center)
        } else {
          List({ space: 10 }) {
            LazyForEach(__ZlibUser__.zlibAccountArray, (item: ZlibUserInfo, index: number) => {
              ListItem() {
                Column() {
                  ListItemWithRadio({
                    image: item.userAvatar == '' ? $r('app.media.zlib') : item.userAvatar,
                    message: item.account,
                    group: 'zlibAccount',
                    checked: __ZlibUser__.account == item.account && __ZlibUser__.password == item.password ,
                    index: index,
                    onChange: (checked: boolean, itemIndex: number) => {
                      if (checked) {
                        __ZlibUser__.account = item.account!
                        __ZlibUser__.password = item.password!
                        __ZlibUser__.userName = $r('app.string.Tip_GettingBookNow')
                        XPreferencesManager.putPreferencesValue('selineRead', "zlibAccountIndex", itemIndex)
                        XPreferencesManager.putPreferencesValue('selineRead', "zlibAccount", item.account ?? '')
                        XPreferencesManager.putPreferencesValue('selineRead', "zlibPassword", item.password ?? '')
                        XPreferencesManager.putPreferencesValue('selineRead', "zlibCookie", item.cookie ?? '')
                        __ZlibUser__.zlibClient.login(__ZlibUser__.account, __ZlibUser__.password, (user) => {
                          __ZlibUser__.localChooseAccount = user
                          item.userName = user.name
                          item.userDownloadLimitNumber = `${user.todayDownloadNum}/${user.downloadLimit}`
                          item.userAvatar = ''
                          __ZlibUser__.cookie = item.cookie!
                          __ZlibUser__.avatar = item.userAvatar!
                          __ZlibUser__.userName = item.userName!
                        }, (error) => {
                          XContext.toast(error)
                        })
                      }
                    }
                  })

                  if (__ZlibUser__.account == item.account && __ZlibUser__.password == item.password) {
                    Column() {
                      Row({ space: 10 }) {
                        Stack() {
                          Column({ space: 15 }) {
                            SymbolGlyph($r('sys.symbol.download'))
                              .fontSize(30)
                              .fontWeight(FontWeight.Medium)
                              .fontColor([$r('sys.color.font')])

                            if (item.userDownloadLimitNumber && item.userDownloadLimitNumber != '') {
                              Text(item.userDownloadLimitNumber)
                                .fontWeight(FontWeight.Medium)
                                .fontSize(18)
                            } else {
                              LoadingProgress()
                                .size({
                                  width: 20
                                })
                            }
                          }
                        }
                        .layoutWeight(1)
                        .height('100%')
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
                            if (item.userDonateNumber && item.userDonateNumber != '') {
                              Text(item.userDonateNumber)
                                .fontWeight(FontWeight.Medium)
                                .fontSize(18)
                            } else {
                              LoadingProgress()
                                .size({
                                  width: 20
                                })
                            }
                          }
                        }
                        .layoutWeight(1)
                        .height('100%')
                        .bindPopup(this.showDonationTips, {
                          message: '此处捐赠额度指的是对zlib官方的捐赠，不是对此APP开发者的捐赠',
                          onStateChange: (e) => {
                            this.showDonationTips = e.isVisible
                          }
                        })
                        .onClick(() => {
                          this.showDonationTips = true;
                        })

                      }.size({ width: '100%', height: 120 })
                    }
                  }
                }.backgroundColor($r('sys.color.comp_background_list_card'))
                .borderRadius(20)
              }
              .swipeAction({
                end: {
                  builder: () => {
                    this.editCustom(item, index)
                  },
                }
              })

              .transition(XAnimation.getAnimation('bottom', index * 200))

            }, (item: ZlibUserInfo, index: number) => JSON.stringify(item) + JSON.stringify(index))
          }
          .height('100%')
          .width('100%')
          .borderRadius(20)
          .clip(true)
          .contentEndOffset(16)
          .padding({ left: 16, right: 16 })
        }

        Column() {
          Blank()
            .bindSheet($$this.showZlibSetting, this.ZlibSettingBuilder(), {
              height: SheetSize.MEDIUM,
              preferType: SheetType.CENTER,
              showClose:false,
              backgroundColor: $r('sys.color.background_tertiary')
            })
        }
      }
    }.size({ width: '100%', height: '100%' })
    .backgroundColor($r('sys.color.background_tertiary'))
    .menus([{
      symbolIcon: new SymbolGlyphModifier($r('sys.symbol.gearshape')),
      value: 'Zlibrary设置',
      action: () => {
        this.showZlibSetting = true
      }
    },
      {
        symbolIcon: new SymbolGlyphModifier($r('sys.symbol.plus')),
        value: '添加账号',
        action: () => {
          this.showLoginSheet = true
        }
      }
    ])
    .bindSheet($$this.showLoginSheet, ZlibLoginSheetBuilder(), {
      preferType: SheetType.CENTER,
      height: SheetSize.LARGE,
      showClose: false
    })
  }
}
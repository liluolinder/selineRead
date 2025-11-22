import { relationalStore } from "@kit.ArkData";
import { __ZlibUser__ } from "../../../../commons/shareDatas";
import { I_BasicUserInfo, I_ZlibUserInfo } from "../../../../../zlibrary/interface/I_ZlibUserInfo";
import { ListItemWithRadio, ListItemWithToggle } from "templatecomponent";
import { SymbolGlyphModifier } from "@kit.ArkUI";
import { __CustomBackgroundData__ } from "../../../../components/CustomBackground";
import { XAnimation, XPreferencesManager } from "commonpackage";
import { ZlibLoginSheetBuilder } from "./zlibraryLoginSheet";
import { RelationStoreManager } from "../../../../models/classes/DataBase";
import { zlibClient } from "../../../../../zlibrary/zlibClient";
import { ZlibUserInfo } from "../../../../../zlibrary/classes/UserInfo";

@Builder
export function ZlibraryAccountBuilder() {
  ZlibraryAccount()
}

@ComponentV2
export struct ZlibraryAccount {

  @Local showDownloadLimitTips: boolean = false
  @Local showDonationTips: boolean = false
  @Provider('showZlibLoginSheet') showLoginSheet: boolean = false

  async aboutToAppear(): Promise<void> {
    await RelationStoreManager.getZlibAccount(__ZlibUser__.dataBase)
    console.log(__ZlibUser__.accountIndex.toString())
    if (__ZlibUser__.zlibAccountArray.dataArray[__ZlibUser__.accountIndex]) {
      zlibClient.getPersonInfo(__ZlibUser__.zlibAccountArray.dataArray[__ZlibUser__.accountIndex].cookie ?? '').then((res) => {
        if (res[0] == 1) {
          let basicInfo = JSON.parse(res[1]) as I_BasicUserInfo
          __ZlibUser__.zlibAccountArray.dataArray[__ZlibUser__.accountIndex].userName = basicInfo.userName
          __ZlibUser__.zlibAccountArray.dataArray[__ZlibUser__.accountIndex].userDownloadLimitNumber =
            basicInfo.userDownloadLimitNumber
          __ZlibUser__.zlibAccountArray.dataArray[__ZlibUser__.accountIndex].userDonateNumber = basicInfo.userDonateNumber
          __ZlibUser__.zlibAccountArray.dataArray[__ZlibUser__.accountIndex].userAvatar = basicInfo.userAvatar
        }
      })
    }
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
              ListItemGroup() {
                ListItemWithRadio({
                  image:item.userAvatar==''?$r('app.media.zlib'):item.userAvatar,
                  message: item.account,
                  group: 'zlibAccount',
                  checked: __ZlibUser__.accountIndex === index,
                  index: index,
                  onChange: (checked: boolean, itemIndex: number) => {
                    if (checked) {
                      XPreferencesManager.putPreferencesValue('selineRead', "zlibAccountIndex",  itemIndex)
                      XPreferencesManager.putPreferencesValue('selineRead', "zlibAccount", item.account??'')
                      XPreferencesManager.putPreferencesValue('selineRead', "zlibPassword", item.password??'')
                      XPreferencesManager.putPreferencesValue('selineRead', "zlibCookie", item.cookie??'')
                      XAnimation.runWithAnimation(() => {
                        __ZlibUser__.accountIndex = itemIndex
                      })
                      zlibClient.getPersonInfo(item.cookie ?? '').then((res) => {
                        if (res[0] == 1) {
                          let basicInfo = JSON.parse(res[1]) as I_BasicUserInfo
                          item.userName = basicInfo.userName
                          item.userDownloadLimitNumber = basicInfo.userDownloadLimitNumber
                          item.userDonateNumber = basicInfo.userDonateNumber
                          item.userAvatar = basicInfo.userAvatar

                          __ZlibUser__.account = item.account!
                          __ZlibUser__.password = item.password!
                          __ZlibUser__.cookie = item.cookie!
                          __ZlibUser__.avatar = item.userAvatar!
                          __ZlibUser__.userName = item.userName!
                        }
                      })
                    }
                  }
                })
                if (__ZlibUser__.accountIndex == index) {
                  ListItem() {
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
              }
              .backgroundColor($r('sys.color.comp_background_list_card'))
              .borderRadius(20)
              .transition(XAnimation.getAnimation('bottom',index*200))


            },(item: ZlibUserInfo, index: number)=>JSON.stringify(item))
          }
          .height('100%')
          .width('100%')
          .borderRadius(20)
          .clip(true)
          .contentEndOffset(16)
          .padding({ left: 16, right: 16 })
        }

      }
    }.size({ width: '100%', height: '100%' })
    .backgroundColor($r('sys.color.background_tertiary'))
    .menus([{
      symbolIcon: new SymbolGlyphModifier($r('sys.symbol.plus')),
      value: '',
      action: () => {
        this.showLoginSheet = true
      }
    },])
    .bindSheet($$this.showLoginSheet, ZlibLoginSheetBuilder(), {
      preferType: SheetType.CENTER,
      height: SheetSize.LARGE,
      showClose:false
    })
  }
}
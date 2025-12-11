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

@Builder
export function ZlibraryAccountBuilder() {
  ZlibraryAccount()
}

@ComponentV2
export struct ZlibraryAccount {
  @Local showDownloadLimitTips: boolean = false
  @Local showDonationTips: boolean = false
  @Local showZlibSetting:boolean = false

  @Provider('showZlibLoginSheet') showLoginSheet: boolean = false

  async aboutToAppear(): Promise<void> {
    await RelationStoreManager.getZlibAccount(__ZlibUser__.dataBase)
    if (__ZlibUser__.zlibAccountArray.dataArray[__ZlibUser__.accountIndex]) {
      zlibClient.getPersonInfo(__ZlibUser__.zlibAccountArray.dataArray[__ZlibUser__.accountIndex].cookie ?? '')
        .then((res) => {
          if (res[0] == 1) {
            let basicInfo = JSON.parse(res[1]) as I_loginRes_user
            __ZlibUser__.zlibAccountArray.dataArray[__ZlibUser__.accountIndex].userName = basicInfo.name
            __ZlibUser__.zlibAccountArray.dataArray[__ZlibUser__.accountIndex].userDownloadLimitNumber =
              `${basicInfo.downloads_today}/${basicInfo.downloads_limit}`
            __ZlibUser__.zlibAccountArray.dataArray[__ZlibUser__.accountIndex].userDonateNumber =
              `${basicInfo.donations_active}`
            __ZlibUser__.zlibAccountArray.dataArray[__ZlibUser__.accountIndex].userAvatar = ''
            __ZlibUser__.userName = basicInfo.name
            __ZlibUser__.avatar = ''
          }
        })
    }
  }


  @Builder
  editCustom(item:ZlibUserInfo ,index:number) {
    Column(){
      Button({type:ButtonType.Circle}){
        SymbolGlyph($r('sys.symbol.trash_fill'))
          .fontSize(28)
          .fontColor([Color.White])

      }.padding(8)
      .backgroundColor($r('sys.color.warning'))
      .onClick(() => {
        __ZlibUser__.zlibAccountArray.deleteData(index)
        let predicates = new relationalStore.RdbPredicates('ZlibraryAccount')
        predicates.equalTo('Account', item.account).equalTo("Password", item.password)
        RelationStoreManager.deleteValue(__ZlibUser__.dataBase,predicates)
        __ZlibUser__.account = ''
        __ZlibUser__.password = ''
        __ZlibUser__.userName = ''
        __ZlibUser__.cookie = ''
        __ZlibUser__.accountIndex = -1
        XPreferencesManager.putPreferencesValue('selineRead', "zlibAccountIndex",  __ZlibUser__.accountIndex)
        XPreferencesManager.putPreferencesValue('selineRead', "zlibAccount", '')
        XPreferencesManager.putPreferencesValue('selineRead', "zlibPassword", '')
        XPreferencesManager.putPreferencesValue('selineRead', "zlibCookie", '')
      })
    }.padding({left:16, right:16})
  }

  @Builder
  ZlibSettingBuilder(){
    Column(){
      List(){
        ListItem(){
          ListItemWithInput({
            image:$r('app.media.zlib'),
            message:$r('app.string.Title_ServerAddress'),
            text:__ZlibUser__.base_url,
            placeholder:$r('app.string.Tip_TapHereToType'),
            returnFunc:(returnText:string)=>{
              //保存地址
              __ZlibUser__.base_url = returnText
              __ZlibUser__.baseApi_url = returnText + '/papi'
              __ZlibUser__.baseEApi_url = returnText + '/eapi'
              XPreferencesManager.putPreferencesValue('selineRead', "zlibBaseUrl", returnText)
              //重新获取数据
              __Home__.recommendBookIndex = 1
              __Home__.errorText = '';
              zlibClient.refreshUrl().then(()=>{
                let req = http.createHttp();
                zlibClient.getRecommendBook(req).then((res)  => {
                  __Home__.canGetMore = true
                  if (res[0] == 1) {
                    __Home__.recommendBookArray.clearData;
                    __Home__.errorText = '';
                    (JSON.parse(res[1]) as I_ZLibRecommendBook_Book[]).forEach((item) => {
                      __Home__.recommendBookArray.pushData(item)
                    });
                    __Home__.recommendBookIndex++;
                  }else {
                    __Home__.errorText = res[1];
                  }
                })
              })

              XContext.toast($r('app.string.Tip_Success'))
            }
          })
        }.backgroundColor($r('sys.color.comp_background_list_card'))
        .borderRadius(20)
      }.width('100%')
      .height('100%')
      .padding({left:16, right:16})
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
                Column(){
                  ListItemWithRadio({
                    image: item.userAvatar == '' ? $r('app.media.zlib') : item.userAvatar,
                    message: item.account,
                    group: 'zlibAccount',
                    checked: __ZlibUser__.accountIndex === index,
                    index: index,
                    onChange: (checked: boolean, itemIndex: number) => {
                      if (checked) {
                        console.log(`124`)
                        XPreferencesManager.putPreferencesValue('selineRead', "zlibAccountIndex", itemIndex)
                        XPreferencesManager.putPreferencesValue('selineRead', "zlibAccount", item.account ?? '')
                        XPreferencesManager.putPreferencesValue('selineRead', "zlibPassword", item.password ?? '')
                        XPreferencesManager.putPreferencesValue('selineRead', "zlibCookie", item.cookie ?? '')
                        XAnimation.runWithAnimation(() => {
                          __ZlibUser__.accountIndex = itemIndex
                        })
                        __ZlibUser__.account = item.account!
                        __ZlibUser__.password = item.password!
                        __ZlibUser__.userName=$r('app.string.Tip_GettingBookNow')
                        zlibClient.getPersonInfo(item.cookie ?? '').then((res) => {
                          if (res[0] == 1) {
                            let basicInfo = JSON.parse(res[1]) as I_loginRes_user
                            item.userName = basicInfo.name
                            item.userDownloadLimitNumber = `${basicInfo.downloads_today}/${basicInfo.downloads_limit}`
                            item.userDonateNumber = `${basicInfo.donations_active}`
                            item.userAvatar = ''
                            __ZlibUser__.cookie = item.cookie!
                            __ZlibUser__.avatar = item.userAvatar!
                            __ZlibUser__.userName = item.userName!
                          }
                        })
                        zlibClient.refreshUrl().then(()=>{
                          let req = http.createHttp();
                          zlibClient.getRecommendBook(req).then((res)  => {
                            __Home__.canGetMore = true
                            if (res[0] == 1) {
                              __Home__.recommendBookArray.clearData
                              __Home__.errorText = '';
                              (JSON.parse(res[1]) as I_ZLibRecommendBook_Book[]).forEach((item) => {
                                __Home__.recommendBookArray.pushData(item)
                              });
                            }else {
                              __Home__.errorText = res[1];
                            }
                          })
                        })
                      }
                    }
                  })

                  if (__ZlibUser__.accountIndex == index) {
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
                } .backgroundColor($r('sys.color.comp_background_list_card'))
                .borderRadius(20)
              }
              .swipeAction({
                end: {
                  builder: () => { this.editCustom(item, index) },
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

        Column(){
          Blank()
            .bindSheet($$this.showZlibSetting, this.ZlibSettingBuilder(), {
              height:SheetSize.MEDIUM,
              preferType:SheetType.CENTER,
              title:{title:$r('app.string.Title_Setting_zlib')},
              backgroundColor:$r('sys.color.background_tertiary')
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
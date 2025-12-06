import { XAnimation, XContext, XPreferencesManager } from "commonpackage"
import { I_ZlibUserInfo } from "../../../../../zlibrary/interface/I_ZlibUserInfo"
import { zlibClient } from "../../../../../zlibrary/zlibClient"
import { __ZlibUser__ } from "../../../../commons/shareDatas"
import { RelationStoreManager } from "../../../../models/classes/DataBase"
import { relationalStore } from "@kit.ArkData"
import { ZlibUserInfo } from "../../../../../zlibrary/classes/UserInfo"

@Builder
export function ZlibLoginSheetBuilder() {
  zlibLoginSheet()
}

enum loginType {
  Login, Register
}

enum loginState {
  Idle, Loading, Error, Complete
}


@ComponentV2
export struct zlibLoginSheet {
  @Consumer('showZlibLoginSheet') showLoginSheet: boolean = false
  @Local localLoginState: loginState = loginState.Idle
  @Local email: string = ''
  @Local password: string = ''
  @Local loginErrorInfo?: string = ''

  build() {
    Row() {
      RelativeContainer() {
        Row({ space: 10 }) {
          Image($r('app.media.zlibrary'))
            .size({ width: 60, height: 60 })
          Text('Z-library')
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
        }
        .alignRules({
          top: { anchor: "__container__", align: VerticalAlign.Top },
          end: { anchor: "__container__", align: HorizontalAlign.End }
        })
        .id('logoWithName')

        Row({ space: 10 }) {
          Text($r('app.string.Title_Welcome'))
            .fontSize(28)
            .fontWeight(FontWeight.Normal)
        }
        .alignRules({
          top: { anchor: "logoWithName", align: VerticalAlign.Bottom },
          start: { anchor: "__container__", align: HorizontalAlign.Start },
        })
        .id('welcome')

        Column({ space: 10 }) {
          TextInput({ placeholder: $r('app.string.Text_Account'), text: $$this.email })
            .height(48)
            .type(InputType.Email)

          TextInput({ placeholder: $r('app.string.Text_Password'), text: $$this.password })
            .height(48)
            .type(InputType.Password)

        }
        .margin({ top: 10 })
        .alignRules({
          top: { anchor: "welcome", align: VerticalAlign.Bottom },
          start: { anchor: "__container__", align: HorizontalAlign.Start },
        })
        .id('input')

        Row() {
          Button($r('app.string.Text_CreateAccount'))
            .backgroundColor($r('sys.color.comp_background_list_card'))
            .fontColor($r('sys.color.font'))
            .onClick(()=>{
              XContext.getAbilityContext().startAbility({
                uri: __ZlibUser__.base_url
              })
            })
        }
        .justifyContent(FlexAlign.SpaceBetween)
        .alignRules({
          top: { anchor: "input", align: VerticalAlign.Bottom },
          start: { anchor: "__container__", align: HorizontalAlign.Start },
        })
        .id('accountButton')
        .width('100%')
        .margin({ top: 10 })

        Row() {
          Text(this.loginErrorInfo)
            .fontColor($r('sys.color.warning'))
        }
        .alignRules({
          top: { anchor: "accountButton", align: VerticalAlign.Bottom },
          start: { anchor: "__container__", align: HorizontalAlign.Start },
        })
        .width('100%')
        .margin({ top: 10 })

        Button({ type: ButtonType.ROUNDED_RECTANGLE }) {
          if (this.localLoginState == loginState.Loading) {
            LoadingProgress()
              .size({ width: 60, height: 60 })
          } else {
            SymbolGlyph($r('sys.symbol.arrow_right'))
          }
        }.size({ width: 80, height: 80 })
        .onClick(() => {
          if (this.localLoginState != loginState.Loading) {
            this.loginErrorInfo = ''
            if (this.email == '' && this.password == '') {
              this.loginErrorInfo = 'Account Or Password cannot be empty'
            } else {
              this.localLoginState = loginState.Loading
              zlibClient.login(this.email, this.password).then(async (res) => {
                if (res[0] == 0) {
                  this.loginErrorInfo = res[1]
                  this.localLoginState = loginState.Error
                } else {
                  let userInfo: I_ZlibUserInfo = JSON.parse(res[1]) as I_ZlibUserInfo
                  await RelationStoreManager.addValue(__ZlibUser__.dataBase, 'ZlibraryAccount', {
                    Account: userInfo.account,
                    Password: userInfo.password,
                    Cookie: userInfo.cookie
                  })
                  let userInfoClass:ZlibUserInfo = new ZlibUserInfo()
                  userInfoClass.account = userInfo.account
                  userInfoClass.password = userInfo.password
                  userInfoClass.cookie = userInfo.cookie
                  userInfoClass.userName = userInfo.userName
                  userInfoClass.userDownloadLimitNumber = userInfo.userDownloadLimitNumber
                  userInfoClass.userDonateNumber = userInfo.userDonateNumber
                  userInfoClass.userAvatar = userInfo.userAvatar
                  __ZlibUser__.zlibAccountArray.pushData(userInfoClass)
                  __ZlibUser__.accountIndex = __ZlibUser__.zlibAccountArray.totalCount()-1
                  __ZlibUser__.account = userInfo.account
                  __ZlibUser__.password = userInfo.password
                  __ZlibUser__.cookie = userInfo.cookie
                  __ZlibUser__.userName = userInfo.userName
                  __ZlibUser__.avatar = userInfo.userAvatar
                  XPreferencesManager.putPreferencesValue('selineRead', "zlibAccountIndex",  __ZlibUser__.accountIndex)
                  XPreferencesManager.putPreferencesValue('selineRead', "zlibAccount", userInfo.account??'')
                  XPreferencesManager.putPreferencesValue('selineRead', "zlibPassword", userInfo.password??'')
                  XPreferencesManager.putPreferencesValue('selineRead', "zlibCookie", userInfo.cookie??'')

                  this.showLoginSheet = false
                }
              })
            }
          }
        })
        .backgroundColor($r('sys.color.button_background_color_transparent'))
        .alignRules({
          bottom: { anchor: "__container__", align: VerticalAlign.Bottom },
          end: { anchor: "__container__", align: HorizontalAlign.End },
        })
      }.backgroundColor($r('sys.color.comp_background_list_card'))
      .padding(16)
      .layoutWeight(1)
      .borderRadius(20)

    }
    .size({ width: '100%', height: '100%' })
    .padding(16)
  }
}
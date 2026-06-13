import { XContext, XPreferencesManager } from 'commonpackage'
import { __ZlibUser__ } from '../../../../commons/shareDatas'
import { RelationStoreManager } from '../../../../models/classes/DataBase'
import { ZlibUserInfo } from '../../../../../zlibrary/classes/UserInfo'

@Builder
export function ZlibLoginSheetBuilder() {
  zlibLoginSheet()
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


              __ZlibUser__.zlibClient.login(this.email, this.password, async (user)=>{
                __ZlibUser__.localChooseAccount = user
                let cookie = user.cookie
                await RelationStoreManager.addValue(__ZlibUser__.dataBase, 'ZlibraryAccount', {
                  Account: this.email,
                  Password: this.password,
                  Cookie: cookie
                })
                let userInfoClass:ZlibUserInfo = new ZlibUserInfo()
                userInfoClass.account = this.email
                userInfoClass.password = this.password
                userInfoClass.cookie = cookie
                userInfoClass.userName = user.name
                userInfoClass.userDownloadLimitNumber = `${user.todayDownloadNum}/${user.downloadLimit}`
                userInfoClass.userAvatar = ``
                __ZlibUser__.zlibAccountArray.pushData(userInfoClass)
                __ZlibUser__.account = this.email
                __ZlibUser__.password = this.password
                __ZlibUser__.cookie = cookie
                __ZlibUser__.userName = user.name
                __ZlibUser__.avatar = ``
                XPreferencesManager.putPreferencesValue('selineRead', "zlibAccount", this.email??'')
                XPreferencesManager.putPreferencesValue('selineRead', "zlibPassword", this.password??'')
                XPreferencesManager.putPreferencesValue('selineRead', "zlibCookie", cookie??'')

                // zlibClient.refreshUrl().then(()=>{
                //   let req = http.createHttp();
                //   zlibClient.getRecommendBook(req).then((res)  => {
                //     __Home__.canGetMore = true
                //     if (res[0] == 1) {
                //       __Home__.recommendBookArray.clearData;
                //       __Home__.errorText = '';
                //       (JSON.parse(res[1]) as I_ZLibRecommendBook_Book[]).forEach((item) => {
                //         //__Home__.recommendBookArray.pushData(item)
                //       });
                //       __Home__.recommendBookIndex++;
                //     }else {
                //       __Home__.errorText = res[1];
                //     }
                //   })
                // })

                this.showLoginSheet = false

              },(error)=>{
                this.loginErrorInfo = error
                this.localLoginState = loginState.Error
                XContext.toast(error)
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
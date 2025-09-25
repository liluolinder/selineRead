import { __CustomBackgroundData__, __System__, __UI__, __User__ } from "../../../../datas/classes/ShareDatas"
import { XAnimation } from "../../../../datas/classes/XAnimation"
import NeoPreferencesUtil from '../../../../datas/classes/XPreferencesUtil'
import { zlibClient } from "../../../../datas/classes/zlib"
import { promptAction } from "@kit.ArkUI"
import { selectImage } from "../../../../utils/ToolsUtil"
import { fileIo } from "@kit.CoreFileKit"
import { globlContext } from "../../../../../entryability/EntryAbility"
import { SettingsClickItem } from "../../../others/ListItem"
import { linderPush } from "../../../../datas/classes/LPushKit"
import { pushToken, pushTokenDataBase } from "../../../../datas/classes/LCloudDataBaseKit"
import { cloudDatabase } from "@kit.CloudFoundationKit"

@Builder
export function settingsBuilder() {
  Settings()
}

@ComponentV2
struct Settings {
  @Provider('settingsPagesInfo') settingsPagesInfo: NavPathStack = new NavPathStack()

  @Builder
  Page(name: string) {
    if (name == 'settings') {
      SettingsPage()
    }
  }

  aboutToAppear(): void {
    this.settingsPagesInfo.pushPath({ name: 'settings' }, false)
  }

  build() {
    Navigation(this.settingsPagesInfo)
      .hideTitleBar(true)
      .navDestination(this.Page)
  }
}

@ComponentV2
struct SettingsPage {
  @Consumer('settingsPagesInfo') settingsPagesInfo: NavPathStack = new NavPathStack()
  @Local apiAddress: string = zlibClient.base_url
  @Local shareBoolText: string = __UI__.shareBookText

  build() {
    NavDestination() {
      List({ space: 10 }) {
        ListItem() {
          SettingsToggleItem({
            symbol: $r('sys.symbol.brush'),
            message: '主界面背景',
            checked: __CustomBackgroundData__.customBackground,
            onChange: (checked: boolean) => {
              XAnimation.runWithAnimation(() => __CustomBackgroundData__.customBackground = checked)
              NeoPreferencesUtil.putPreferencesValue("selineRead", 'customBackground', checked)
            }
          })
        }

        if (__CustomBackgroundData__.customBackground) {
          SettingsClickItem({
            symbol: $r('sys.symbol.plus'),
            message: '选取图片',
            onPress: async () => {
              const uri = await selectImage()
              if (uri) {
                __CustomBackgroundData__.refresh = true
                const file0 = fileIo.openSync(uri)
                const file1 = fileIo.openSync(globlContext.filesDir + '/background',
                  fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE)
                fileIo.copyFileSync(file0.fd, file1.fd)
                fileIo.closeSync(file0)
                fileIo.closeSync(file1)
                setTimeout(() => __CustomBackgroundData__.refresh = false, 50)
              }
            }
          })
        }


        ListItem() {
          SettingsToggleItem({
            symbol: $r('sys.symbol.link_slash'),
            symbol1: $r('sys.symbol.link'),
            message: '使用局域网书库',
            checked: __UI__.onlineMode,
            onChange: async (checked: boolean) => {
              XAnimation.runWithAnimation(() => __UI__.onlineMode = checked)
              NeoPreferencesUtil.putPreferencesValue("selineRead", 'onlineMode', checked)
              zlibClient.recommendBooksArray.clearData()
              zlibClient.bookshelfArray.clearData()
              if (checked) {
                zlibClient.getUserInfo()
                await zlibClient.refreshUrl().then(async () => {
                  zlibClient.getRecommendBooks(1)
                  zlibClient.getBookShelf(1)
                  if (__User__.isLoginZlib && __UI__.onlineMode) {
                    zlibClient.getUserInfo()
                  }
                })
              }

            }
          })
        }

        if (__UI__.onlineMode) {
          ListItem() {
            Column({ space: 10 }) {
              Text('服务地址').fontSize(15).fontWeight(FontWeight.Medium).padding({ left: 5, right: 5 })
              Row({ space: 10 }) {
                TextInput({ text: $$this.apiAddress })
                  .backgroundColor($r('sys.color.comp_background_secondary'))
                  .layoutWeight(1)
                  .height(40)
                Button({ stateEffect: true }) {
                  SymbolGlyph($r('sys.symbol.checkmark')).fontSize(17).fontColor([$r('sys.color.font')])
                }
                .backgroundColor($r('sys.color.comp_background_secondary'))
                .size({ width: 40, height: 40 })
                .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
                .onClick(() => {
                  let res = this.apiAddress
                  if (this.apiAddress == 'book.liluolinder.top') {
                    res = 'https://zh.laoshihao.ru'
                  }
                  zlibClient.base_url = res
                  zlibClient.baseApi_url = res + '/papi'
                  NeoPreferencesUtil.putPreferencesValue("selineRead", 'zlibUrl', res)
                  zlibClient.recommendBooksArray.clearData()
                  zlibClient.bookshelfArray.clearData()
                  zlibClient.refreshUrl().then(async () => {
                    zlibClient.getRecommendBooks(1)
                    zlibClient.getBookShelf(1)
                  })
                  promptAction.showToast({
                    message: '已保存',
                    duration: 2000
                  });
                })
              }.width('100%')
            }
            .width('100%')
            .borderRadius(20)
            .backgroundColor($r('sys.color.comp_background_list_card'))
            .padding(15)
            .alignItems(HorizontalAlign.Start)

          }

          ListItem() {
            SettingsToggleItem({
              symbol: $r('sys.symbol.share'),
              message: '下载完成后自动分享',
              checked: zlibClient.autoShare,
              onChange: (checked: boolean) => {
                zlibClient.autoShare = checked
                NeoPreferencesUtil.putPreferencesValue("selineRead", 'autoShare', checked)
              }
            })
          }

          ListItem() {
            SettingsToggleItem({
              symbol: $r('sys.symbol.paperplane'),
              message: '接受可用API推送',
              checked: __UI__.needGetNewAPI,
              onChange: async (checked: boolean) => {
                __UI__.needGetNewAPI = checked
                if (checked) {
                  await linderPush.getPushToken().then((token:string)=>{
                    let condition = new cloudDatabase.DatabaseQuery(pushToken)
                    condition.equalTo('pushToken', token);

                    pushTokenDataBase.query(condition).then((res)=>{
                      if (res == undefined || res.length==0) {
                        console.log(`Liquid:不存在`)
                        let record = new pushToken()
                        record.pushToken = token
                        record.needGetNewAPI= true
                        pushTokenDataBase.upsert(record)
                      }else {
                        let record = res[0]
                        record.needGetNewAPI = true
                        pushTokenDataBase.upsert(record)
                      }
                    })
                  })
                }else {
                  await linderPush.getPushToken().then((token:string)=>{
                    let condition = new cloudDatabase.DatabaseQuery(pushToken)
                    condition.equalTo('pushToken', token);

                    pushTokenDataBase.query(condition).then((res)=>{
                      if (res == undefined || res.length==0) {}
                      else {
                        let record = res[0]
                        record.needGetNewAPI = false
                        pushTokenDataBase.upsert(record)
                      }
                    })
                  })
                }
                NeoPreferencesUtil.putPreferencesValue("selineRead", 'needGetNewAPI', checked)
              }
            })
          }

          ListItem() {
            Column({ space: 10 }) {
              Column(){
                Text('分享书本的消息格式').fontSize(15).fontWeight(FontWeight.Medium)
                Text('{link}为分享内容，{userName}为用户名').fontSize(12).opacity(0.75)
              }.alignItems(HorizontalAlign.Start).padding({ left: 5, right: 5 })

              Row({ space: 10 }) {
                TextInput({ text: $$this.shareBoolText })
                  .backgroundColor($r('sys.color.comp_background_secondary'))
                  .layoutWeight(1)
                  .height(40)
                Button({ stateEffect: true }) {
                  SymbolGlyph($r('sys.symbol.checkmark')).fontSize(17).fontColor([$r('sys.color.font')])
                }
                .backgroundColor($r('sys.color.comp_background_secondary'))
                .size({ width: 40, height: 40 })
                .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
                .onClick(() => {
                  if(!this.shareBoolText.includes('{link}')){
                    promptAction.showToast({message: '必须包含分享内容！'})
                  } else {
                    promptAction.showToast({message: '已保存'})
                    __UI__.shareBookText = this.shareBoolText
                    NeoPreferencesUtil.putPreferencesValue("selineRead", 'shareBookText', this.shareBoolText)
                  }
                })
              }.width('100%')
            }
            .width('100%')
            .borderRadius(20)
            .backgroundColor($r('sys.color.comp_background_list_card'))
            .padding(15)
            .alignItems(HorizontalAlign.Start)

          }

        }

        ListItem() {
          SettingsClickItem({
            symbol: $r('sys.symbol.text_clipboard'),
            message: '运行日志',
            onPress: () => {
              __UI__.showSettings = false
              __UI__.showLogger = true
            }
          })
        }
      }
      .contentEndOffset(Math.max(16, __System__.bottomRectHeight))
      .layoutWeight(1)
      .margin({ left: 16, right: 16 })
      .chainAnimation(true)
      .scrollBar(BarState.Off)
      .borderRadius(20)
      .clip(true)
    }
    .padding({ top: 8 })
    .backgroundColor(Color.Transparent)
    .title('设置')
    .hideBackButton(true)
    .onBackPressed(() => {
      __UI__.showSettings = false
      return true
    })
  }
}

@ComponentV2
export struct SettingsToggleItem {
  @Param symbol: Resource | undefined = undefined
  @Param symbol1: Resource | undefined = undefined
  @Param message: ResourceStr = ''
  @Param checked: boolean = false
  @Local enable: boolean = this.checked
  @Param ensureMessage: ResourceStr | undefined = undefined
  @Event onChange: (checked: boolean) => void

  build() {
    Row() {
      Flex({ justifyContent: FlexAlign.SpaceBetween, alignItems: ItemAlign.Center }) {
        Row({ space: 10 }) {
          SymbolGlyph(this.enable && this.symbol1 ? this.symbol1 : this.symbol)
            .fontSize(22)
            .fontColor([$r('sys.color.font')])
            .symbolEffect(new ReplaceSymbolEffect(EffectScope.WHOLE), Number(this.enable))
          Text(this.message)
            .fontSize(17)
            .fontWeight(FontWeight.Medium)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.MARQUEE })
            .layoutWeight(1)
        }.layoutWeight(1)

        Toggle({ type: ToggleType.Switch, isOn: this.enable })
          .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
          .onChange((checked: boolean) => {
            if (this.ensureMessage && checked) {
              this.getUIContext().showAlertDialog({
                title: this.message,
                message: this.ensureMessage,
                alignment: DialogAlignment.Center,
                primaryButton: {
                  value: '知道了',
                  fontColor: (AppStorage.get('themeColor') as string[])[AppStorage.get('currentColorMode') as number],
                  action: () => {
                  }
                },
                cornerRadius: 20,
                backgroundBlurStyle: BlurStyle.COMPONENT_THIN,
              })
            }
            this.enable = checked
            this.onChange(checked)
          })
          .selectedColor($r('app.color.sweet_blue'))
          .width(45)
          .height(27);
      }.align(Alignment.Center)

    }
    .backgroundColor($r('sys.color.comp_background_list_card'))
    .height(55)
    .borderRadius(20)
    .padding({
      right: 15,
      left: 15,
      top: 10,
      bottom: 10
    })
  }
}


import { __System__, __UI__, __User__ } from "../../../../datas/classes/ShareDatas"
import { XAnimation } from "../../../../datas/classes/XAnimation"
import  NeoPreferencesUtil from '../../../../datas/classes/XPreferencesUtil'
import { zlib, zlibClient } from "../../../../datas/classes/zlib"
import { promptAction } from "@kit.ArkUI"

@Builder
export function settingsBuilder(){
  Settings()
}

@ComponentV2
struct Settings{

  @Provider('settingsPagesInfo') settingsPagesInfo: NavPathStack = new NavPathStack()

  @Builder
  Page(name: string){
    if(name == 'settings'){
      SettingsPage()
    }
  }

  aboutToAppear(): void {
    this.settingsPagesInfo.pushPath({name: 'settings'}, false)
  }

  build() {
    Navigation(this.settingsPagesInfo)
      .hideTitleBar(true)
      .navDestination(this.Page)
  }
}

@ComponentV2
struct SettingsPage{

  @Consumer('settingsPagesInfo') settingsPagesInfo: NavPathStack = new NavPathStack()
  @Local apiAddress: string = zlibClient.base_url

  build() {
    NavDestination(){
      List({space: 10}){
        ListItem(){
          SettingsToggleItem({
            symbol: $r('sys.symbol.link_slash'),
            symbol1: $r('sys.symbol.link'),
            message: '使用局域网书库',
            checked: __UI__.onlineMode,
            onChange: (checked: boolean)=>{
              XAnimation.runWithAnimation(()=>__UI__.onlineMode = checked)
              NeoPreferencesUtil.putPreferencesValue("selineRead", 'onlineMode', checked)
              if(checked) zlibClient.getUserInfo()
              zlibClient.recommendBooksArray.clearData()
              zlibClient.bookshelfArray.clearData()
            }
          })
        }

        if(__UI__.onlineMode){
          ListItem(){
            Column({space: 10}){
              Text('服务地址').fontSize(15).fontWeight(FontWeight.Medium).padding({left: 5, right: 5})
              Row({space: 10}){
                TextInput({text: $$this.apiAddress}).backgroundColor($r('sys.color.comp_background_secondary')).layoutWeight(1).height(40)
                Button({stateEffect: true}){
                  SymbolGlyph($r('sys.symbol.checkmark')).fontSize(17).fontColor([$r('sys.color.font')])
                }.backgroundColor($r('sys.color.comp_background_secondary')).size({width: 40, height: 40}).clickEffect({level: ClickEffectLevel.LIGHT, scale: 0.9})
                .onClick(()=>{
                  zlibClient.base_url = this.apiAddress
                  zlibClient.baseApi_url = zlibClient.base_url + '/papi'
                  NeoPreferencesUtil.putPreferencesValue("selineRead", 'zlibUrl', this.apiAddress)
                  zlibClient.recommendBooksArray.clearData()
                  zlibClient.bookshelfArray.clearData()
                  zlibClient.refreshUrl().then(async () => {
                    zlibClient.getRecommendBooks(1)
                    zlibClient.getBookShelf(1)
                  })
                  promptAction.showToast({
                    message:'已保存',
                    duration: 2000
                  });
                })
              }.width('100%')
            }.width('100%').borderRadius(20).backgroundColor($r('sys.color.comp_background_list_card')).padding(15).alignItems(HorizontalAlign.Start)
          }
        }
      }
      .contentEndOffset(Math.max(16, __System__.bottomRectHeight))
      .layoutWeight(1)
      .margin({left: 16, right: 16})
      .chainAnimation(true)
    }.padding({ top: 8 })
    .backgroundColor(Color.Transparent)
    .title('设置')
    .hideBackButton(true)
    .onBackPressed(()=>{
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
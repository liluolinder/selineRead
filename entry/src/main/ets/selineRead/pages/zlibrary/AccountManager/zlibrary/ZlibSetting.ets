import { add } from "color"
import { XContext, XPreferencesManager } from "commonpackage"
import { ListItemWithInput, ListItemWithRadio, ListItemWithToggle } from "templatecomponent"
import { __ZlibUser__ } from "../../../../commons/shareDatas"
import { ListTitle } from "../../../../components/ListTitle"
import { I_ListTitle } from "../../../../models/interfaces/I_ListTitle"
import { __Setting__ } from "../../../../commons/shareDatas"

@ComponentV2
export struct ZlibSetting {
  @Local officialAddress: string[] = [
    "https://zh.z-library.sk",
    "https://zh.z-lib.sk",
    "https://zh.1lib.sk"
  ]

  @Builder
  editCustom( index: number) {
    Column() {
      Button({ type: ButtonType.Circle }) {
        SymbolGlyph($r('sys.symbol.trash_fill'))
          .fontSize(20)
          .fontColor([Color.White])

      }.padding(8)
      .backgroundColor($r('sys.color.warning'))
      .onClick(() => {

      })
    }.padding({ left: 16, right: 16 })
  }


  build() {
    List({ space: 10 }) {

      ListItem() {
        ListTitle({ item: { title: '设置' } as I_ListTitle })
      }

      ListItemGroup() {
        ListItem() {
          ListItemWithToggle({
            type: ToggleType.Switch,
            checked: __Setting__.autoRefreshUrl,
            message: '启动自动更新地址',
            tip:'对于镜像地址，可以自动刷新至新的地址，避免旧地址失效，对官方地址不起作用',
            onChange: (status: boolean) => {
              __Setting__.autoRefreshUrl = status
              XPreferencesManager.putPreferencesValue('selineRead', "autoRefreshUrl", status)
            }

          })
        }
      }.backgroundColor(Color.White)
      .borderRadius(20)
      .divider({
        strokeWidth: 0.5,
        color: $r('sys.color.comp_divider'),
        startMargin: 16,
        endMargin: 26
      })

      ListItem() {
        ListTitle({ item: { title: '官方地址', tip: '官方地址可能需要科学上网，不提供删除服务' } as I_ListTitle })
      }

      ListItemGroup() {
        ForEach(this.officialAddress, (address: string, index:number) => {
          ListItem(){
            ListItemWithRadio({
              message: address,
              group: 'zlibServiceAddress',
              checked:__ZlibUser__.urlType == 0 && (__ZlibUser__.base_url.includes(address) || __ZlibUser__.base_url.includes(address)),
              onChange: (checked: boolean) => {
                if (checked) {
                  __ZlibUser__.base_url = address
                  __ZlibUser__.urlType = 0
                  XPreferencesManager.putPreferencesValue('selineRead', "zlibBaseUrl", address)
                  XPreferencesManager.putPreferencesValue('selineRead', "urlType", 0)
                  __ZlibUser__.zlibClient.setZlibUrl(address)
                  XContext.toast(`请重启APP以加载数据`, 4000)
                }
              }
            })
          }
        })
      }
      .backgroundColor(Color.White)
      .borderRadius(20)
      .divider({
        strokeWidth: 0.5,
        color: $r('sys.color.comp_divider'),
        startMargin: 16,
        endMargin: 26
      })

      ListItem() {
        ListTitle(
          { item: { title: '自定义地址', tip: '默认提供一个官方镜像地址，其余地址请自行辨别真伪,左滑可以删除' } as I_ListTitle })
      }

      ListItemGroup() {
        ListItem() {
          ListItemWithRadio({
            message: "https://zh.zlibraryd.ru/",
            group: 'zlibServiceAddress',
            //checked:__ZlibUser__.urlType == 1 && (__ZlibUser__.base_url.includes(address) || __ZlibUser__.base_url.includes(address)),
            onChange: (checked: boolean) => {
              __ZlibUser__.base_url = "https://zh.zlibraryd.ru/"
              __ZlibUser__.urlType = 1
              XPreferencesManager.putPreferencesValue('selineRead', "urlType", 1)
              XPreferencesManager.putPreferencesValue('selineRead', "zlibBaseUrl", "https://zh.zlibraryd.ru/")
              __ZlibUser__.zlibClient.setZlibUrl("https://zh.zlibraryd.ru/")
              XContext.toast(`请重启APP以加载数据`, 4000)
            }
          })
        }
        .swipeAction({
          end: {
            builder: () => {
              this.editCustom(0)
            },
          }
        })
      }.width('100%')
      .backgroundColor(Color.White)
      .borderRadius(20)
      .divider({
        strokeWidth: 0.5,
        color: $r('sys.color.comp_divider'),
        startMargin: 16,
        endMargin: 26
      })

    }.height('100%')
    .width('100%')
    .padding({ left: 16, right: 16 })
  }
}

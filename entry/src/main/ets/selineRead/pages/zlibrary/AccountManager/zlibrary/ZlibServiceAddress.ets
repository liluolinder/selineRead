import { add } from "color"
import { XContext, XPreferencesManager } from "commonpackage"
import { ListItemWithInput, ListItemWithRadio, ListItemWithToggle } from "templatecomponent"
import { __ZlibUser__ } from "../../../../commons/shareDatas"
import { ListTitle } from "../../../../components/ListTitle"
import { I_ListTitle } from "../../../../models/interfaces/I_ListTitle"


@ComponentV2
export struct ZlibServiceAddress {
  @Local officialAddress: string[] = [
    "https://zh.z-library.sk",
    "https://zh.z-lib.sk",
    "https://zh.1lib.sk"
  ]

  build() {
    List({ space: 10 }) {

      ListItemGroup() {
        ListItem() {
          ListTitle({ item: { title: '设置' } as I_ListTitle })
        }

        ListItem() {
          ListItemWithToggle({
            type: ToggleType.Switch,
            checked: false,
            message: '启动自动更新地址',
            onChange: (status: boolean) => {

            }

          })
        }.backgroundColor(Color.White)
        .borderRadius(20)
      }


      ListItemGroup() {
        ListItem() {
          ListTitle({ item: { title: '官方地址', tip: '官方地址可能需要科学上网，不提供删除服务' } as I_ListTitle })
        }

        ListItem() {
          Column() {
            ForEach(this.officialAddress, (address: string) => {
              ListItemWithRadio({
                message: address,
                group: 'zlibServiceAddress',
                onChange: (checked: boolean) => {
                  __ZlibUser__.base_url = address
                  XPreferencesManager.putPreferencesValue('selineRead', "zlibBaseUrl", address)
                  __ZlibUser__.zlibClient.setZlibUrl(address)
                  XContext.toast(`请重启APP以加载数据`, 4000)
                }
              })
            })
          }
        }.backgroundColor(Color.White)
        .borderRadius(20)
      }.width('100%')

      ListItemGroup() {
        ListItem() {
          ListTitle(
            { item: { title: '自定义地址', tip: '默认提供一个官方镜像地址，其余地址请自行辨别真伪' } as I_ListTitle })
        }

        ListItem() {
          Column() {
            ListItemWithRadio({
              message: "https://zh.zlibraryd.ru/",
              group: 'zlibServiceAddress',
              onChange: (checked: boolean) => {
                __ZlibUser__.base_url = "https://zh.zlibraryd.ru/"
                XPreferencesManager.putPreferencesValue('selineRead', "zlibBaseUrl", "https://zh.zlibraryd.ru/")
                __ZlibUser__.zlibClient.setZlibUrl("https://zh.zlibraryd.ru/")
                XContext.toast(`请重启APP以加载数据`, 4000)
              }
            })
          }
        }.backgroundColor(Color.White)
        .borderRadius(20)
      }.width('100%')

    }.height('100%')
    .width('100%')
    .padding({ left: 16, right: 16 })
  }
}

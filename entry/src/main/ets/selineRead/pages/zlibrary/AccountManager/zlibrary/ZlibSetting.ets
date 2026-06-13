import { add } from "color"
import { XContext, XPreferencesManager } from "commonpackage"
import { ListItemWithInput, ListItemWithRadio, ListItemWithToggle } from "templatecomponent"
import { __System__, __ZlibUser__ } from "../../../../commons/shareDatas"
import { ListTitle } from "../../../../components/ListTitle"
import { I_ListTitle } from "../../../../models/interfaces/I_ListTitle"
import { __Setting__ } from "../../../../commons/shareDatas"
import { ZlibServiceAddress, ZlibServiceStatus } from "../../../../models/classes/ZlibServiceAddress"
import { RelationStoreManager } from "../../../../models/classes/DataBase"
import { relationalStore } from "@kit.ArkData"
import { HdsNavigation, HdsNavigationTitleMode, IconStyleMode } from "@hms.hds.hdsBaseComponent"
import { CustomContentDialog } from "@kit.ArkUI"

@ComponentV2
export struct ZlibSetting {
  scroller: Scroller = new Scroller();
  @Consumer('showZlibSetting') showZlibSetting: boolean = false
  @Local officialAddress: ZlibServiceAddress[] = [
    new ZlibServiceAddress("https://zh.z-library.sk/", ZlibServiceStatus.Unknown),
    new ZlibServiceAddress("https://zh.z-lib.sk/", ZlibServiceStatus.Unknown),
    new ZlibServiceAddress("https://zh.1lib.sk/", ZlibServiceStatus.Unknown)
  ]
  @Local newUrl: string = ''

  aboutToAppear(): void {
    __ZlibUser__.zlibServiceAddressArray = []
    RelationStoreManager.getZlibServerAddress(__ZlibUser__.dataBase)
  }

  dialogController: CustomDialogController = new CustomDialogController({
    builder: CustomContentDialog({
      primaryTitle: '添加服务地址',
      secondaryTitle: '请自行辨别真伪',
      contentBuilder: () => {
        this.addNewAddress();
      },
      buttons: [
        {
          value: '取消',
          buttonStyle: ButtonStyleMode.TEXTUAL,
          role: ButtonRole.ERROR,
          action: () => {
            this.newUrl = ''
          }
        },
        {
          value: '确定',
          buttonStyle: ButtonStyleMode.TEXTUAL,
          action: () => {
            if (__ZlibUser__.zlibServiceAddressArray.filter((address) => address.url.includes(this.newUrl) || this.newUrl.includes(address.url) ).length != 0 ||
              this.officialAddress.filter((address) => address.url.includes(this.newUrl) || this.newUrl.includes(address.url)).length != 0) {
              //说明冲突 不给建
              XContext.alterDialogWithTwoButton({
                title: "提醒",
                message:"已存在服务地址请不要重复添加",
                cancelCallBack: (): void => {
                },
                confirmCallBack: (): void => {
                }
              })
            } else {
              RelationStoreManager.addValue(__ZlibUser__.dataBase, 'ZlibServiceUrl', {
                Url: this.newUrl
              })
              __ZlibUser__.zlibServiceAddressArray.push(new ZlibServiceAddress(this.newUrl, ZlibServiceStatus.Unknown))
            }
          }
        }
      ],
    }),
  });

  @Builder
  editCustom(url: string) {
    Column() {
      Button({ type: ButtonType.Circle }) {
        SymbolGlyph($r('sys.symbol.trash_fill'))
          .fontSize(20)
          .fontColor([Color.White])

      }.padding(8)
      .backgroundColor($r('sys.color.warning'))
      .onClick(() => {
        if (url.includes(__ZlibUser__.base_url) || __ZlibUser__.base_url.includes(url)) {
          __ZlibUser__.base_url = ''
          __ZlibUser__.zlibClient.setZlibUrl('')
          XPreferencesManager.putPreferencesValue('selineRead', "zlibBaseUrl", '')
        }
        //删除数据库数据
        let predicates = new relationalStore.RdbPredicates('ZlibServiceUrl')
        predicates.equalTo('Url', url)
        RelationStoreManager.deleteValue(__ZlibUser__.dataBase, predicates)
        __ZlibUser__.zlibServiceAddressArray =
          __ZlibUser__.zlibServiceAddressArray.filter((address) => address.url != url)
      })
    }.padding({ left: 16, right: 16 })
  }

  @Builder
  addNewAddress() {
    Column() {
      TextInput({ text: $$this.newUrl, placeholder: 'https://xxxx.xxx/' })
        .maxLines(1)
    }.width('100%')
  }

  build() {
    HdsNavigation() {
      List({ space: 10, scroller: this.scroller }) {

        ListItem() {
          ListTitle({ item: { title: '设置' } as I_ListTitle })
        }

        ListItemGroup() {
          ListItem() {
            ListItemWithToggle({
              type: ToggleType.Switch,
              checked: __Setting__.autoRefreshUrl,
              message: '启动自动更新地址',
              tip: '对于镜像地址，可以自动刷新至新的地址，避免旧地址失效，对官方地址不起作用',
              onChange: (status: boolean) => {
                __Setting__.autoRefreshUrl = status
                XPreferencesManager.putPreferencesValue('selineRead', "autoRefreshUrl", status)
              }
            })
          }
        }.backgroundColor($r('sys.color.comp_background_list_card'))
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
          ForEach(this.officialAddress, (address: ZlibServiceAddress, index: number) => {
            ListItem() {
              ListItemWithRadio({
                message: address.url,
                group: 'zlibServiceAddress',
                checked: __ZlibUser__.urlType == 0 &&
                  (__ZlibUser__.base_url.includes(address.url) || address.url.includes(__ZlibUser__.base_url)),
                onChange: (checked: boolean) => {
                  if (checked) {
                    __ZlibUser__.base_url = address.url
                    __ZlibUser__.urlType = 0
                    XPreferencesManager.putPreferencesValue('selineRead', "zlibBaseUrl", address.url)
                    XPreferencesManager.putPreferencesValue('selineRead', "urlType", 0)
                    __ZlibUser__.zlibClient.setZlibUrl(address.url)
                    XContext.toast(`请重启APP以加载数据`, 4000)
                  }
                }
              })
            }
          })
        }
        .backgroundColor($r('sys.color.comp_background_list_card'))
        .borderRadius(20)
        .divider({
          strokeWidth: 0.5,
          color: $r('sys.color.comp_divider'),
          startMargin: 16,
          endMargin: 26
        })

        ListItem() {
          ListTitle(
            {
              item: { title: '自定义地址', tip: '默认提供一个官方镜像地址，其余地址请自行辨别真伪,左滑可以删除' } as
                I_ListTitle
            })
        }

        ListItemGroup() {
          ForEach(__ZlibUser__.zlibServiceAddressArray, (address: ZlibServiceAddress) => {
            ListItem() {
              ListItemWithRadio({
                message: address.url,
                group: 'zlibServiceAddress',
                checked: __ZlibUser__.urlType == 1 &&
                  (__ZlibUser__.base_url.includes(address.url) || address.url.includes(__ZlibUser__.base_url)),
                onChange: (checked: boolean) => {
                  __ZlibUser__.base_url = address.url
                  __ZlibUser__.urlType = 1
                  XPreferencesManager.putPreferencesValue('selineRead', "urlType", 1)
                  XPreferencesManager.putPreferencesValue('selineRead', "zlibBaseUrl", address.url)
                  __ZlibUser__.zlibClient.setZlibUrl(address.url)
                  XContext.toast(`请重启APP以加载数据`, 4000)
                }
              })
            }
            .swipeAction({
              end: {
                builder: () => {
                  this.editCustom(address.url)
                },
              }
            })
          }, (address: ZlibServiceAddress) => JSON.stringify(address))
        }.width('100%')
        .backgroundColor($r('sys.color.comp_background_list_card'))
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
      .contentEndOffset(Math.max(16, __System__.bottomRectHeight))
    }
    .width('100%')
    .height('100%')
    .titleBar({
      enableComponentSafeArea: true, // 将标题栏设置为组件级安全区，内容区可避让标题栏
      content: {
        title: {
          mainTitle: $r('app.string.Title_Setting_zlib')
        },
        // 设置HdsNavigation关闭按钮，与半模态按钮规格一致
        menu: {
          value: [
            {
              content: {
                icon: $r('sys.symbol.plus'),
                type: IconStyleMode.SMALL,
                action: () => {
                  this.dialogController.open()
                }
              }
            },
            {
              content: {
                icon: $r('sys.symbol.xmark'),
                type: IconStyleMode.SMALL,
                action: () => {
                  this.showZlibSetting = false
                },
              }
            }]
        },
      },
    })
    .titleMode(HdsNavigationTitleMode.MODAL)
    .bindToScrollable([this.scroller]) // 绑定导航组件和可滚动容器组件
  }
}

import { XAnimation, XContext, XPreferencesManager } from "commonpackage"
import { ListItemWithInput, ListItemWithSelect, ListItemWithText, ListItemWithToggle } from "templatecomponent"
import { __Setting__ } from "../../commons/shareDatas"
import { motion } from "@kit.MultimodalAwarenessKit"
import { webdavArk } from "libohos_app_cangjie_entry.webdav.so"
import { pasteboard } from "@kit.BasicServicesKit"
import { I_ListTitle } from "../../models/interfaces/I_ListTitle"
import { ListTitle } from "../../components/ListTitle"
import { SegmentButtonV2Items, TabSegmentButtonV2 } from "@kit.ArkUI"
import { ConfigurationConstant } from "@kit.AbilityKit"

@Builder
export function SettingBuilder() {
  Setting()
}


@ComponentV2
export struct Setting {
  @Local darkModeSegButtonItems: SegmentButtonV2Items = new SegmentButtonV2Items([
    { text: '跟随系统' },
    { text: '开启' },
    { text: '关闭' },
  ]);
  @Local darkModeIndex: number = __Setting__.darkModeIndex;

  @Monitor("darkModeIndex")
  darkModeIndexChangeCallback(){
    __Setting__.darkModeIndex = this.darkModeIndex
    let mode = ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET
    switch (this.darkModeIndex){
      case 0:
        mode = ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET
        break
      case 1:
        mode = ConfigurationConstant.ColorMode.COLOR_MODE_DARK
        break
      case 2:
        mode = ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT
        break
    }
    XPreferencesManager.putPreferencesValue('selineRead', "ColorMode", this.darkModeIndex)
    XContext.setColorMode(mode)
  }

  settingOptionArray: I_ListTitle[] = [
    {
      title: $r('app.string.Title_DisplaySetting'),
    },
    {
      title: $r('app.string.Title_DownloadSetting'),
    },
    {
      title: $r('app.string.Title_BookShelfSetting'),
    },
    {
      title: 'WebDAV服务器',
      tip: '启用内置webdav服务，将下载目录/Seline Read(阅韵心读)挂载,便于导入其他APP，只有在关闭服务器情况下，才可以配置参数'
    }
  ]

  @Builder
  displaySetting() {
    if (canIUse("SystemCapability.MultimodalAwareness.Motion")) {
      ListItem() {
        ListItemWithToggle({
          type: ToggleType.Switch,
          checked: __Setting__.needPerceptiveGrip,
          message: $r('app.string.perceptiveGrip'),
          onChange: (status: boolean) => {
            XPreferencesManager.putPreferencesValue('selineRead', "needPerceptiveGrip", status)
            __Setting__.needPerceptiveGrip = status
            if (status) {
              try {
                motion.on('holdingHandChanged', (state) => {
                  console.log('testTAG', state)
                  XAnimation.runWithAnimation(() => __Setting__.isLeftHand =
                    state == motion.HoldingHandStatus.LEFT_HAND_HELD)
                })
              } catch {
              }
            } else {
              try {
                motion.off('holdingHandChanged');
                XAnimation.runWithAnimation(() => __Setting__.isLeftHand = false)
              } catch {
              }
            }
          }
        })
      }
    }

    ListItem(){
      Column(){
        ListItemWithText({
          leftMessage:'深色模式'
        })
        Row(){
          TabSegmentButtonV2({
            items: this.darkModeSegButtonItems,
            selectedIndex: this.darkModeIndex!!,
            enableStateAnimation:true
          }).width('100%')
        }.width('100%')
        .padding({left:16, right:16, bottom:16})
      }
    }
  }

  @Builder
  downloadSetting() {
    ListItem() {
      ListItemWithToggle({
        type: ToggleType.Button,
        checked: __Setting__.overrideConflictFile,
        message: $r('app.string.Text_ConflictFileHandling'),
        toggleMessage: __Setting__.overrideConflictFile ? $r('app.string.Text_Override') :
          $r('app.string.Text_Coexistence'),
        onChange: (status: boolean) => {
          __Setting__.overrideConflictFile = status
          XPreferencesManager.putPreferencesValue('selineRead', "overrideConflictFile", status)
        }
      })
    }

    ListItem() {
      ListItemWithToggle({
        type: ToggleType.Switch,
        checked: __Setting__.shareAfterDownload,
        message: $r('app.string.Title_ShareAfterDownload'),

        onChange: (status: boolean) => {
          __Setting__.shareAfterDownload = status
          XPreferencesManager.putPreferencesValue('selineRead', "shareAfterDownload", status)
        }
      })
    }
  }

  @Builder
  bookshelfSettingBuilder() {
    ListItem() {
      ListItemWithSelect({
        message: '点击书籍打开方式',
        select: __Setting__.bookShelfClickOpenWay,
        selectArray: [
          {
            value: '无操作'
          },
          {
            value: '打开本地阅读器(尚未完成)'
          },
          {
            value: '华为阅读'
          },
          {
            value: '格物阅读'
          }
        ],
        onSelect: (index: number, value: string) => {
          __Setting__.bookShelfClickOpenWay = index
          XPreferencesManager.putPreferencesValue('selineRead', "bookShelfClickOpenWay", index)
        }
      })
    }
  }

  @Builder
  webdavSettingBuilder() {
    ListItem() {
      ListItemWithToggle({
        type: ToggleType.Switch,
        checked: __Setting__.webdavServerEnabled,
        message: '打开WebDAV服务器',
        onChange: async (status: boolean) => {
          __Setting__.webdavServerEnabled = status
          XPreferencesManager.putPreferencesValue('selineRead', "webdavServerEnabled", status)
          if (status) {
            __Setting__.webdavClient =
              new webdavArk(await XContext.getDownloadFolderPath(), __Setting__.webdavPort, __Setting__.webdavAccount,
                __Setting__.webdavPassword)
            __Setting__.webdavClient?.start()
          } else {
            __Setting__.webdavClient?.stop()
          }
        }
      })
    }

    if (__Setting__.webdavServerEnabled) {
      ListItem() {
        Row() {
          Column() {
            Text('服务地址')
              .fontSize(14)
              .fontColor($r('sys.color.font_secondary'))
            Text(`http://127.0.0.1:${__Setting__.webdavPort}`)
              .fontSize(16)
              .margin({ top: 4 })
          }.alignItems(HorizontalAlign.Start)

          Button('复制')
            .backgroundColor($r('app.color.linder_blue'))
            .height(40)
            .width(60)
            .onClick(()=>{
              let pasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, `http://127.0.0.1:${__Setting__.webdavPort}`);
              pasteboard.getSystemPasteboard().setData(pasteData) //写入剪切板
              XContext.toast($r('app.string.Tip_Success'))
            })
        }
        .justifyContent(FlexAlign.SpaceBetween)
        .width('100%')
        .padding({
          left: 16,
          right: 16,
          top: 12,
          bottom: 12
        })

      }

    }

    ListItem() {
      ListItemWithInput({
        message: '端口',
        text: __Setting__.webdavPort.toString(),
        onchange: (value: string) => {
          const port = parseInt(value)
          if (port > 0 && port <= 65535) {
            __Setting__.webdavPort = port
            XPreferencesManager.putPreferencesValue('selineRead', "webdavPort", port)
          }
        }
      })
    }.enabled(!__Setting__.webdavServerEnabled)

    ListItem() {
      ListItemWithInput({
        message: '账号',
        text: __Setting__.webdavAccount,
        onchange: (value: string) => {
          if (value != '') {
            __Setting__.webdavAccount = value
            XPreferencesManager.putPreferencesValue('selineRead', "webdavAccount", value)
          } else {
            XContext.toast('不可为空')
          }

        }
      })
    }.enabled(!__Setting__.webdavServerEnabled)

    ListItem() {
      ListItemWithInput({
        message: '密码',
        text: __Setting__.webdavPassword,
        onchange: (value: string) => {
          if (value != '') {
            __Setting__.webdavPassword = value
            XPreferencesManager.putPreferencesValue('selineRead', "webdavPassword", value)
          } else {
            XContext.toast('不可为空')
          }
        }
      })
    }.enabled(!__Setting__.webdavServerEnabled)
  }

  build() {
    Column() {
      Scroll() {
        Column({ space: 20 }) {
          ForEach(this.settingOptionArray, (title: I_ListTitle, index: number) => {
            Column({ space: 10 }) {
              ListTitle({
                item: title
              })

              List() {
                if (index == 0) {
                  this.displaySetting()
                } else if (index == 1) {
                  this.downloadSetting()
                } else if (index == 2) {
                  this.bookshelfSettingBuilder()
                } else if (index == 3) {
                  this.webdavSettingBuilder()
                }
              }
              .width('100%')
              .height('auto')
              .backgroundColor($r('sys.color.comp_background_list_card'))
              .borderRadius(20)
              .divider({
                strokeWidth: 0.5,
                color: $r('sys.color.comp_divider'),
                startMargin: 26,
                endMargin: 16
              })

            }.width('100%')
          })
        }
      }.layoutWeight(1)
      .scrollBar(BarState.Off)
      .align(Alignment.Top)
      .edgeEffect(EdgeEffect.Spring)
    }.size({ width: '100%', height: '100&' })
    .padding({ left: 16, right: 16, bottom: 16 })
    .backgroundColor($r('sys.color.background_tertiary'))
  }
}


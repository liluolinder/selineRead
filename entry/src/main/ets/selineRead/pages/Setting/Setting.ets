import { XPreferencesManager } from "commonpackage"
import { ListItemWithSelect, ListItemWithToggle } from "templatecomponent"
import { __Setting__ } from "../../commons/shareDatas"

@Builder
export function SettingBuilder() {
  Setting()
}

@ComponentV2
export struct Setting {
  settingOptionArray: ResourceStr[] = [
    $r('app.string.Title_DisplaySetting'),
    $r('app.string.Title_DownloadSetting'),
    $r('app.string.Title_BookShelfSetting'),
  ]

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
        message:'点击书籍打开方式',
        select:__Setting__.bookShelfClickOpenWay,
        selectArray:[
          {
            value:'无操作'
          },
          {
            value:'打开本地阅读器(尚未完成)'
          },
          {
            value:'华为阅读'
          },
          {
            value:'格物阅读'
          }
        ],
        onSelect:(index: number, value: string)=>{
          __Setting__.bookShelfClickOpenWay = index
          XPreferencesManager.putPreferencesValue('selineRead', "bookShelfClickOpenWay", index)
        }
      })
    }
  }

  build() {
    Column() {
      Scroll() {
        Column({ space: 20 }) {
          ForEach(this.settingOptionArray, (title: ResourceStr, index: number) => {
            Column({ space: 10 }) {
              Text(title)
                .width('100%')
                .fontWeight(FontWeight.Bold)

              List() {
                if (index == 0) {
                  ListItem(){
                    Column(){
                      Text('Coming Soon')
                    }.height(50)
                    .padding(16)
                  }
                } else if (index == 1) {
                  this.downloadSetting()
                }else if (index == 2) {
                  this.bookshelfSettingBuilder()
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
    }.size({ width: '100%', height: '100&' })
    .padding({ left: 16, right: 16, bottom: 16 })
    .backgroundColor($r('sys.color.background_tertiary'))
  }
}
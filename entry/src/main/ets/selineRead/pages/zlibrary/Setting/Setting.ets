import { XAnimation } from "commonpackage"
import { ListItemWithArrow } from "templatecomponent"

@Builder
export function SettingBuilder() {
  Setting()
}

@ComponentV2
export struct Setting {
  settingOptionArray: string[] = [
    '显示设置',
    '下载设置',
  ]

  build() {
    Column() {
      List({ space: 10 }) {
        ForEach(this.settingOptionArray, (item: string, index: number) => {
          ListItem() {
            Column({space:5}) {
              Text(item)
                .fontSize(18)
                .fontWeight(FontWeight.Medium)
                .width('100%')

              Column()
                .size({ width: '100%', height: 150 })
                .backgroundColor($r('sys.color.comp_background_list_card'))
                .borderRadius(20)
            }
          }
        })
      }.width('100%')
      .height('100%')
    }.size({ width: '100%', height: '100&' })
    .padding({ left: 16, right: 16, bottom: 16 })
    .backgroundColor($r('sys.color.background_tertiary'))
  }
}
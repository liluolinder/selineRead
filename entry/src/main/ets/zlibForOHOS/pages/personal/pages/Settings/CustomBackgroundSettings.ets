import { globalContext } from "../../../../../entryability/EntryAbility"
import { __CustomBackgroundData__ } from "../../../../datas/classes/ShareDatas"
import { XAnimation } from "../../../../datas/classes/XAnimation"
import NeoPreferencesUtil from '../../../../datas/classes/XPreferencesUtil'
import { selectImage } from "../../../../utils/ToolsUtil"
import { SettingsClickItem } from "../../../others/ListItem"
import { SettingsToggleItem } from "./Settings"
import { fileIo } from "@kit.CoreFileKit"

@Builder
export function customBackgroundSettingsBuilder(){
  CustomBackgroundSettings()
}

@ComponentV2
struct CustomBackgroundSettings{
  build() {
    NavDestination(){
      List(){
        SettingsToggleItem({
          symbol: $r('sys.symbol.ohos_photo'),
          message: '主界面背景',
          checked: __CustomBackgroundData__.customBackground,
          onChange: (checked: boolean) => {
            XAnimation.runWithAnimation(() => __CustomBackgroundData__.customBackground = checked)
            NeoPreferencesUtil.putPreferencesValue("selineRead", 'customBackground', checked)
          }
        })

        if (__CustomBackgroundData__.customBackground) {
          SettingsToggleItem({
            symbol: $r('sys.symbol.brush'),
            message: '背景跟随颜色模式',
            checked: __CustomBackgroundData__.customBackgroundFollowColorMode,
            onChange: (checked: boolean) => {
              XAnimation.runWithAnimation(() => __CustomBackgroundData__.customBackgroundFollowColorMode = checked)
              NeoPreferencesUtil.putPreferencesValue("selineRead", 'customBackgroundFollowColorMode', checked)
            }
          })

          SettingsClickItem({
            symbol: $r('sys.symbol.plus'),
            message: __CustomBackgroundData__.customBackgroundFollowColorMode? '选取浅色模式图片': '选取图片',
            onPress: async () => {
              const uri = await selectImage()
              if (uri) {
                __CustomBackgroundData__.refresh = true
                const file0 = fileIo.openSync(uri)
                const file1 = fileIo.openSync(globalContext.filesDir + '/background',
                  fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE)
                fileIo.copyFileSync(file0.fd, file1.fd)
                fileIo.closeSync(file0)
                fileIo.closeSync(file1)
                setTimeout(() => __CustomBackgroundData__.refresh = false, 50)
              }
            }
          })

          if(__CustomBackgroundData__.customBackgroundFollowColorMode){
            SettingsClickItem({
              symbol: $r('sys.symbol.plus'),
              message: '选取深色模式图片',
              onPress: async () => {
                const uri = await selectImage()
                if (uri) {
                  __CustomBackgroundData__.refresh = true
                  const file0 = fileIo.openSync(uri)
                  const file1 = fileIo.openSync(globalContext.filesDir + '/dark_background',
                    fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE)
                  fileIo.copyFileSync(file0.fd, file1.fd)
                  fileIo.closeSync(file0)
                  fileIo.closeSync(file1)
                  setTimeout(() => __CustomBackgroundData__.refresh = false, 50)
                }
              }
            })
              .transition(XAnimation.getAnimation('bottom'))
          }
        }
      }.contentEndOffset(16)
      .margin({left: 16, right: 16, top: 5})
      .fadingEdge(true)
      .chainAnimation(true)
    }.padding({top: 8})
  }
}
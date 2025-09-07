import { window } from '@kit.ArkUI'
import { common, Context } from '@kit.AbilityKit'
import { deviceInfo, settings } from '@kit.BasicServicesKit'
import { __System__ } from '../datas/classes/ShareDatas'
import { globlUIContext } from '../../entryability/EntryAbility'
import { XAnimation } from '../datas/classes/XAnimation'

class Windows {
  windowClass: window.Window | undefined = undefined

  async initWindow(context: common.UIAbilityContext) {
    this.windowClass = await context.windowStage.getMainWindow()
    this.windowClass.setWindowLayoutFullScreen(true)
    try{
        this.windowClass.setWindowDecorVisible(false)
        this.windowClass.setWindowTitleButtonVisible(false, false, false)
        this.windowClass.setWindowDecorHeight(50)
    }catch {}
    this.updateAvoidArea(this.windowClass)
    this.pcMode(context)
    this.updateScreenSize(undefined, undefined)
    this.windowClass.on('windowSizeChange', (size) => {
      this.updateScreenSize(size.width, size.height)
    })
    this.windowClass.on('windowStatusChange', (state) => {
      __System__.windowState = state
    })
    this.windowClass.on('avoidAreaChange', () => {
      this.updateAvoidArea(this.windowClass!)
    })
    this.windowClass.on('keyboardHeightChange', (height) => {
      __System__.keyboardHeight = globlUIContext.px2vp(height)
    })
  }
  isPC(): boolean {
    return deviceInfo.deviceType.toUpperCase() == 'PC' || deviceInfo.deviceType.toUpperCase() == '2IN1'
  }
  pcMode(context: Context) {
    if (deviceInfo.deviceType.toUpperCase() == 'PC' || deviceInfo.deviceType.toUpperCase() == '2IN1') {
      __System__.pcMode = true
    } else {
      __System__.pcMode = settings.getValueSync(context, 'window_pcmode_switch_status', 'false', settings.domainName.USER_PROPERTY) === 'true'
      //监听：
      settings.registerKeyObserver(context, 'window_pcmode_switch_status', settings.domainName.USER_PROPERTY, () => {
        const pcMode =
          settings.getValueSync(context, 'window_pcmode_switch_status', 'false', settings.domainName.USER_PROPERTY) ===
            'true'
        __System__.pcMode = pcMode
        if (pcMode) {
          try {
            this.windowClass?.setWindowDecorVisible(false)
            this.windowClass?.setWindowTitleButtonVisible(false, false, false)
            this.windowClass?.setWindowDecorHeight(50)
          } catch {
          }
        }
        setTimeout(() => {
          this.updateScreenSize(undefined, undefined)
        }, 500)
      });
    }
  }

  async updateAvoidArea(windowClass: window.Window) {
    let cutOut = windowClass.getWindowAvoidArea(window.AvoidAreaType.TYPE_CUTOUT)
    let system = windowClass.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM)
    let nav = windowClass.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR)
    XAnimation.runWithAnimation(()=>{
      __System__.topRectHeight = Math.max(globlUIContext.px2vp(Math.max(cutOut.topRect.height * 1.5, system.topRect.height)), windowClass.getWindowDecorHeight())
      __System__.bottomRectHeight = globlUIContext.px2vp(Math.max(nav.bottomRect.height * 0.8, system.bottomRect.height, cutOut.bottomRect.height * 1.5))
      __System__.leftRectHeight = globlUIContext.px2vp(Math.max(cutOut.leftRect.width * 1.5, system.leftRect.width))
      __System__.rightRectHeight = globlUIContext.px2vp(Math.max(cutOut.rightRect.width * 1.5, system.rightRect.width))
    })
  }

  setBarState(status: boolean, navigationIndicator: boolean) {
    this.windowClass?.setSpecificSystemBarEnabled('status', status)
    this.windowClass?.setSpecificSystemBarEnabled('navigationIndicator', navigationIndicator)
  }

  setKeepScreenOn(isOn: boolean) {
    this.windowClass?.setWindowKeepScreenOn(isOn)
  }

  setWindowTitleButtonVisible(isVisible: boolean) {
    if (!this.windowClass) {
      return
    }
    try {
      this.windowClass.setWindowTitleButtonVisible(isVisible, isVisible, isVisible)
    } catch {
    }
  }

  async updateScreenSize(width: number | undefined, height: number | undefined) {
    XAnimation.runWithAnimation(() => {
      __System__.windowWidth =
        this.windowClass?.getUIContext().px2vp(width || this.windowClass.getWindowProperties().windowRect.width) || 0
      __System__.windowHeight =
        this.windowClass?.getUIContext().px2vp(height || this.windowClass.getWindowProperties().windowRect.height) || 0
    })
  }


  getWindowClass(): window.Window | undefined {
    return this.windowClass
  }
}

const WindowsUtil = new Windows()

export default WindowsUtil
import { window } from '@kit.ArkUI'
import { common, Context } from '@kit.AbilityKit'
import { deviceInfo, settings } from '@kit.BasicServicesKit'
import { __System__ } from '../../commons/shareDatas'
import { XAnimation, XContext } from 'commonpackage'


class Windows {
    windowClass: window.Window | undefined = undefined
    windowStage: window.WindowStage| undefined = undefined
    async initWindow(context: common.UIAbilityContext, windowStage: window.WindowStage) {
        this.windowClass = await context.windowStage.getMainWindow()
        this.windowClass.setWindowLayoutFullScreen(true)
        try {
            this.windowClass.setWindowDecorVisible(false)
            this.windowClass.setWindowTitleButtonVisible(false, false, false)
            this.windowClass.setWindowDecorHeight(__System__.DecorHeight)
        } catch {
        }
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

        windowStage.on('windowStageEvent', (data) => {
            if (data === window.WindowStageEventType.PAUSED) {
                __System__.isInBackGround = true
            } else {
                __System__.isInBackGround = false;
            }
        });
        //this.updateDecorHeight()
    }

    pcMode(context: Context) {
        if (deviceInfo.deviceType.toUpperCase() == 'PC' || deviceInfo.deviceType.toUpperCase() == '2IN1') {
            __System__.pcMode = true
        } else {
            __System__.pcMode = settings.getValueSync(context, 'window_pcmode_switch_status', 'false',
                settings.domainName.USER_PROPERTY) === 'true'
            //监听：
            settings.registerKeyObserver(context, 'window_pcmode_switch_status', settings.domainName.USER_PROPERTY,
                () => {
                    const pcMode =
                        settings.getValueSync(context, 'window_pcmode_switch_status', 'false',
                            settings.domainName.USER_PROPERTY) ===
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

    isPC(): boolean {
        return deviceInfo.deviceType.toUpperCase() == 'PC' || deviceInfo.deviceType.toUpperCase() == '2IN1'
    }

    async updateAvoidArea(windowClass: window.Window) {
        let cutOut = windowClass.getWindowAvoidArea(window.AvoidAreaType.TYPE_CUTOUT)
        let system = windowClass.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM)
        let nav = windowClass.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR)
        XAnimation.runWithAnimation(() => {
            __System__.topRectHeight =
                Math.max(XContext.getContext().px2vp(Math.max(cutOut.topRect.height * 1.5, system.topRect.height)),
                    windowClass.getWindowDecorHeight())
            __System__.bottomRectHeight = XContext.getContext()
                .px2vp(Math.max(nav.bottomRect.height * 0.8, system.bottomRect.height, cutOut.bottomRect.height * 1.5))
            __System__.leftRectHeight =
                XContext.getContext().px2vp(Math.max(cutOut.leftRect.width * 1.5, system.leftRect.width))
            __System__.rightRectHeight =
                XContext.getContext().px2vp(Math.max(cutOut.rightRect.width * 1.5, system.rightRect.width))
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
                this.windowClass?.getUIContext().px2vp(width ||
                this.windowClass.getWindowProperties().windowRect.width) || 0
            __System__.windowHeight =
                this.windowClass?.getUIContext().px2vp(height ||
                this.windowClass.getWindowProperties().windowRect.height) || 0
        })
    }

    async updateDecorHeight() {
        XAnimation.runWithAnimation(() => {
            try {
                __System__.DecorHeight = this.windowClass?.getWindowDecorHeight() as number;
                console.info(`Succeeded in getting the height of window decor: ${__System__.DecorHeight}`);
            } catch (exception) {
                console.error(`Failed to get the height of window decor. Cause code: ${exception.code}, message: ${exception.message}`);
            }
        })
    }

    getWindowClass(): window.Window | undefined {
        return this.windowClass
    }
}

const WindowsUtil = new Windows()

export default WindowsUtil
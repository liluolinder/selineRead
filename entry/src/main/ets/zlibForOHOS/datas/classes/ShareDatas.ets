/*
Copyright (c) 2025 琉离铟落linder
SelineRead is licensed under Mulan PSL v2.
You can use this software according to the terms and conditions of the Mulan
PSL v2.
You may obtain a copy of Mulan PSL v2 at:
         http://license.coscl.org.cn/MulanPSL2
THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY
KIND, EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO
NON-INFRINGEMENT, MERCHANTABILITY OR FIT FOR A PARTICULAR PURPOSE.
See the Mulan PSL v2 for more details.

Mulan Permissive Software License，Version 2

Mulan Permissive Software License，Version 2 (Mulan PSL v2)

January 2020 http://license.coscl.org.cn/MulanPSL2
 */


import { relationalStore } from '@kit.ArkData'
import NeoPreferencesUtil from '../../datas/classes/XPreferencesUtil'
import { window } from '@kit.ArkUI'
import { LogLine } from '../../pages/personal/pages/LoggerPage'
import { XAnimation } from './XAnimation'
import { ConfigurationConstant } from '@kit.AbilityKit'

export const min_width: number = 700

export const min_split_width: number = 1100

export const min_player_landscape_width: number = 900


@ObservedV2
export class Notification {
  @Trace id: number = 0
}

export let __Notification__: Notification = new Notification()

@ObservedV2
export class SysShareData {
  @Trace currentBreakpoint: string = ''
  @Trace bottomRectHeight: number = 0
  @Trace leftRectHeight: number = 0
  @Trace rightRectHeight: number = 0
  @Trace topRectHeight: number = 0
  @Trace windowWidth: number = 0
  @Trace windowHeight: number = 0
  @Trace keyboardHeight: number = 0
  @Trace windowState: window.WindowStatusType = window.WindowStatusType.UNDEFINED
  @Trace windowHighlight: boolean = true
  @Trace pcMode: boolean = false
  @Trace currentColorMode: ConfigurationConstant.ColorMode = ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET

  @Monitor('windowWidth')
  changeSideBarWidthByBreakPoint() {
    XAnimation.runWithAnimation(()=>{
      __UI__.isSplitLayout = __System__.windowWidth > min_split_width
      __UI__.indexNavigationMode = __System__.windowWidth < min_split_width? NavigationMode.Stack: __UI__.mainPageStack.getAllPathName().length > 0? NavigationMode.Split: __UI__.indexNavigationMode
      __UI__.isLargeSidebar = __System__.windowWidth < min_width
      __UI__.isShowSideBar = __System__.windowWidth > min_width
      __UI__.sideBarMode = __System__.windowWidth > min_width? SideBarContainerType.Embed: SideBarContainerType.Overlay

    })
  }

}

export let __System__: SysShareData = new SysShareData()

@ObservedV2
export class UserShareData {
  @Trace avatar: ResourceStr = ''
  @Trace isLoginZlib: boolean = true
  @Trace zlibAccount: string = ''
  @Trace zlibPassword: string = ''
}

export let __User__: UserShareData = new UserShareData()


@ObservedV2
export class DataBaseShareData {
  @Trace baseStore: relationalStore.RdbStore | undefined
}

export let __DataBase__: DataBaseShareData = new DataBaseShareData()

@ObservedV2
export class Logger {
  @Trace logs: LogLine[] = []
}

export let __Logger__: Logger = new Logger()

@ObservedV2
export class UIShareData {
  @Trace isInReader: boolean = false
  @Trace currentColorMode: ConfigurationConstant.ColorMode = ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET
  HomePageStack: NavPathStack = new NavPathStack()
  bookListPageStack: NavPathStack = new NavPathStack()
  @Trace onlineMode: boolean = false
  @Trace needGetNewAPI: boolean = false
  @Trace showSettings: boolean = false
  @Trace showLogger: boolean = false
  @Trace mainPageStack: NavPathStack = new NavPathStack()
  @Trace isLargeSidebar: boolean = true
  @Trace indexNavigationMode: NavigationMode = NavigationMode.Stack
  @Trace sideBarMode: SideBarContainerType = SideBarContainerType.AUTO
  @Trace isShowSideBar: boolean = __System__.windowWidth > min_width
  @Trace isSplitLayout: boolean = __System__.windowWidth > min_split_width
  currentBookData: string = ''
  currentBookListData: string = ''
  shareBookText: string = ''
  currentViewingType: 'book'|'bookList'|'home' = 'home'
  indexSwiperController = new SwiperController()
  private hideBarTimer: number = 0
  @Trace displayTabs: boolean = true

  hideBars(autoShow: boolean = true){
    XAnimation.runWithAnimation(()=> this.displayTabs = false)
    clearTimeout(this.hideBarTimer)
    if(autoShow){
      this.hideBarTimer = setTimeout(()=>{
        XAnimation.runWithAnimation(()=> this.displayTabs = true)
      }, 1500)
    }

  }

  showBars(){
    clearTimeout(this.hideBarTimer)
    console.log('testTAG showBars')
    XAnimation.runWithAnimation(()=> this.displayTabs = true)
  }
}

export let __UI__: UIShareData = new UIShareData()

@ObservedV2
export class CustomBackgroundData {

  constructor() {
    this.customBackground = NeoPreferencesUtil.getPreferencesValue("selineRead", 'customBackground', false) as boolean
    this.customBackgroundFollowColorMode = NeoPreferencesUtil.getPreferencesValue("selineRead", 'customBackgroundFollowColorMode', false) as boolean
  }

  @Trace customBackground: boolean = false
  @Trace refresh: boolean = false
  @Trace customBackgroundFollowColorMode: boolean = false
  @Trace blur: number = 0
  @Trace darkness: number = 0
  @Trace enableCustomBackground: boolean = false
  @Trace advanceMaterial: boolean = true
  @Trace flash: boolean = false
}

export let __CustomBackgroundData__: CustomBackgroundData = new CustomBackgroundData()

export const minHeight = 600

export const minWidth = 700

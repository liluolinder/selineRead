import { window } from "@kit.ArkUI"
import { ConfigurationConstant } from "@kit.AbilityKit"
import { BasicDataSource, XAnimation } from "commonpackage"
import { min_split_width, min_width } from "./commonItem"
import { __CustomBackgroundData__ } from "../components/CustomBackground"
import { relationalStore } from "@kit.ArkData"
import { I_ZlibUserInfo } from "../../zlibrary/interface/I_ZlibUserInfo"
import { ZlibUserInfo } from "../../zlibrary/classes/UserInfo"
import { DownloadManager } from "@hadss/super_fast_file_trans"
import { DownloadInfo } from "../models/classes/DownloadInfo"


@ObservedV2
export class SysShareData {
  @Trace bottomRectHeight: number = 0
  @Trace topRectHeight: number = 0
  @Trace leftRectHeight: number = 0
  @Trace rightRectHeight: number = 0
  @Trace windowWidth: number = 0
  @Trace windowHeight: number = 0
  @Trace windowState: window.WindowStatusType = window.WindowStatusType.UNDEFINED
  @Trace pcMode: boolean = false
  @Trace DecorHeight: number = 50
  @Trace currentColorMode: ConfigurationConstant.ColorMode = ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET

  @Monitor('currentColorMode')
  changeColorMode() {
    __CustomBackgroundData__.flash = !__CustomBackgroundData__.flash
  }

  @Monitor('windowWidth')
  changeSideBarWidthByBreakPoint() {
    XAnimation.runWithAnimation(() => {
      __UI__.isLargeSidebar = __System__.windowWidth < min_width
      __UI__.isShowSideBar = __System__.windowWidth > min_width
      __UI__.sideBarMode =
        __System__.windowWidth > min_width ? SideBarContainerType.Embed : SideBarContainerType.Overlay
      __UI__.indexNavigationMode =
        __System__.windowWidth > min_width ? NavigationMode.Auto:NavigationMode.Stack
    })
  }

}
export let __System__: SysShareData = new SysShareData()


@ObservedV2
export class UIData {
  @Trace mainPageStack: NavPathStack = new NavPathStack()
  @Trace isLargeSidebar: boolean = true
  @Trace indexNavigationMode: NavigationMode = NavigationMode.Stack
  @Trace sideBarMode: SideBarContainerType = SideBarContainerType.AUTO
  @Trace advanceMaterial: boolean = true
  @Trace isShowSideBar: boolean = __System__.windowWidth > min_width
  @Trace isSplitLayout: boolean = __System__.windowWidth > min_split_width
}

export const __UI__: UIData = new UIData()


@ObservedV2
export class ZlibUser{
  @Trace accountIndex: number = 1
  @Trace account:string = ''
  @Trace password:string = ''
  @Trace cookie:string = ''
  @Trace avatar:string=''
  @Trace userName:string=''
  notificationID:number=0
  dataBase?:relationalStore.RdbStore
  downloadManager?:DownloadManager

  zlibAccountArray:BasicDataSource<ZlibUserInfo> = new BasicDataSource<ZlibUserInfo>()
  base_url: string = 'https://zh.cn101.ru'
  baseApi_url: string = this.base_url+'/papi'

}

export const __ZlibUser__: ZlibUser = new ZlibUser()

@ObservedV2
export class Download{
  @Trace downloadArray: BasicDataSource<DownloadInfo> =
    new BasicDataSource<DownloadInfo>()
}

export const __Download__: Download = new Download()
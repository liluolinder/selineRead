import { window } from "@kit.ArkUI"
import { ConfigurationConstant } from "@kit.AbilityKit"
import { BasicDataSource, XAnimation } from "commonpackage"
import { min_split_width, min_width } from "./commonItem"
import { __CustomBackgroundData__ } from "../components/CustomBackground"
import { relationalStore } from "@kit.ArkData"
import { ZlibUserInfo } from "../../zlibrary/classes/UserInfo"
import { DownloadManager } from "@hadss/super_fast_file_trans"
import { DownloadInfo } from "../models/classes/DownloadInfo"
import { DownloadManageArk } from "libohos_app_cangjie_entry.download.so"
import { webdavArk } from "libohos_app_cangjie_entry.webdav.so"
import { ZlibUserInfoArk, ZlibClientArk ,ZlibBookInfoBriefArk} from "libohos_app_cangjie_entry.zlib4cj.so"
import { ZlibServiceAddress } from "../models/classes/ZlibServiceAddress"
import { QQbot } from "libohos_app_cangjie_entry.qqbot.so"


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
  @Trace isInBackGround:boolean = false

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
  zlibClient:ZlibClientArk = new ZlibClientArk()
  @Trace localChooseAccount:ZlibUserInfoArk = new ZlibUserInfoArk()
  @Trace account:string = ''
  @Trace password:string = ''
  @Trace cookie:string = ''
  @Trace avatar:string=''
  @Trace userName:ResourceStr=$r('app.string.Tip_GettingBookNow')
  @Trace zlibAccountArray:BasicDataSource<ZlibUserInfo> = new BasicDataSource<ZlibUserInfo>()
  @Trace zlibServiceAddressArray:ZlibServiceAddress[] = []
  @Trace canSend2QQ:boolean = true
  qqbot = new QQbot()

  notificationID:number=0
  dataBase?:relationalStore.RdbStore
  downloadManager?:DownloadManager

  downloadManageCJ?:DownloadManageArk


  base_url: string = 'https://zh.zlibraryd.ru/'
  urlType:number = 1  //0为官方地址，1为自定义地址 默认提供自定义地址

  //启用
  baseApi_url: string = this.base_url+'/papi'
  baseEApi_url:string = this.base_url+'/eapi'

}

export const __ZlibUser__: ZlibUser = new ZlibUser()

@ObservedV2
export class Download{
  @Trace downloadArray: BasicDataSource<DownloadInfo> =
    new BasicDataSource<DownloadInfo>()
}

export const __Download__: Download = new Download()


@ObservedV2
export class Setting{
  @Trace overrideConflictFile:boolean = true
  @Trace shareAfterDownload:boolean = true
  @Trace bookShelfClickOpenWay:number = 0
  @Trace needPerceptiveGrip:boolean = false
  @Trace needDlpAntiPeep:boolean = false
  @Trace isLeftHand:boolean = false
  @Trace webdavServerEnabled:boolean = false
  @Trace webdavPort:number = 8088
  @Trace webdavAccount:string = 'admin'
  @Trace webdavPassword:string = 'admin'
  @Trace webdavClient?:webdavArk

  @Trace autoRefreshUrl:boolean = true
  @Trace darkModeIndex: number = 0;

}
export const __Setting__: Setting = new Setting()

@ObservedV2
export class hwShareData{
  @Trace bookFromShare:ZlibBookInfoBriefArk|undefined = undefined
}

export let __HWShare__:hwShareData= new hwShareData()
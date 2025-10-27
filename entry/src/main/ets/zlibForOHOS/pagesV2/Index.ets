import { globalContext } from "../../entryability/EntryAbility"
import { pushToken, pushTokenDataBase } from "../datas/classes/LCloudDataBaseKit"
import { linderDataBaseManger } from "../datas/classes/LDataBaseManager"
import { linderPixelMap } from "../datas/classes/LPixelMap"
import { linderPush } from "../datas/classes/LPushKit"
import { min_width, __DataBase__, __System__, __UI__, __User__ } from "../datas/classes/ShareDatas"
import { XAnimation } from "../datas/classes/XAnimation"
import { zlibClient } from "../datas/classes/zlib"
import { zlibDownloadingTable } from "../datas/commons/zlibDownloadingTable"
import { zlibHaveDownloadTable } from "../datas/commons/zlibHaveDownloadTable"
import { CustomBackground } from "../pages/others/Builder"
import { DecorBar } from "../pages/others/DecorBar"
import { Body } from "./Index/Body"
import { SideBar } from "./Index/SideBar"
import NeoPreferencesUtil from '../datas/classes/XPreferencesUtil'

@Entry
@ComponentV2
 struct Index {
  @Provider('tabController') tabController: TabsController = new TabsController()

  async aboutToAppear(): Promise<void> {

    __DataBase__.baseStore = await linderDataBaseManger.createRelationalStoreDataBase(globalContext, {
      dataBaseName: 'selineRead',
    })
    linderDataBaseManger.createTableForRelationDataBase(__DataBase__.baseStore, 'zlibHaveDownload',
      zlibHaveDownloadTable,5)

    linderDataBaseManger.createTableForRelationDataBase(__DataBase__.baseStore, 'I_zlibDownloadingTable',
      zlibDownloadingTable,5)


    __User__.avatar = linderPixelMap.ISHaveAvatar(globalContext)
    __User__.isLoginZlib = NeoPreferencesUtil.getPreferencesValue("selineRead", 'isLoginZlib', false) as boolean

    if (__UI__.onlineMode) {
      await zlibClient.refreshUrl().then(async () => {
        zlibClient.getRecommendBooks(1)
        if (__User__.isLoginZlib && __UI__.onlineMode) {
          zlibClient.getUserInfo()
        }
      })
      this.proccessContinueData()
    }

    if(NeoPreferencesUtil.getPreferencesValue('selineRead', 'isUploadPushToken', false)){
      let record = new pushToken()
      record.pushToken = await linderPush.getPushToken()
      record.needGetNewAPI= __UI__.needGetNewAPI
      if (await pushTokenDataBase.upsert(record)) NeoPreferencesUtil.putPreferencesValue('selineRead', 'isUploadPushToken', true)
    }

  }

  proccessContinueData() {
    throw new Error("Method not implemented.")
  }

  onBackPress(): boolean | void {

  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      if (__System__.pcMode) {
        DecorBar()
          .zIndex(114514)
      }
      CustomBackground()

      Navigation(__UI__.mainPageStack) {
        SideBarContainer(__UI__.sideBarMode) {
          SideBar()
          Body()
        }
        .showSideBar(__UI__.isShowSideBar)
        .autoHide(false)
        .showControlButton(false)
        .sideBarWidth(__UI__.isLargeSidebar? 260: 70)
        .maxSideBarWidth(__UI__.isLargeSidebar? 260: 70)
        .minSideBarWidth(__UI__.isLargeSidebar? 260: 70)
        .gesture(
          PanGesture({ fingers: 1, direction: PanDirection.Right })
            .onActionEnd(() => {
              if (__System__.windowWidth < min_width) {
                XAnimation.runWithAnimation(() => {
                  __UI__.isShowSideBar = true
                })
              }
            })
        )
        .gesture(
          PanGesture({ fingers: 1, direction: PanDirection.Left })
            .onActionEnd(() => {
              if (__System__.windowWidth < min_width) {
                XAnimation.runWithAnimation(() => {
                  __UI__.isShowSideBar = false
                })
              }
            })
        )

      }
      .backgroundColor(Color.Transparent)
      .layoutWeight(1)
      .hideToolBar(true)
      .navBarWidth(__System__.windowWidth / 2.5 + (__UI__.isLargeSidebar? 190: 0))
      .mode(__UI__.indexNavigationMode)
      .onNavigationModeChange((mode) => {
        __UI__.indexNavigationMode = mode
      })

    }.size({ width: '100%', height: '100%' })
    .backgroundColor($r('app.color.start_window_background'))

  }
}
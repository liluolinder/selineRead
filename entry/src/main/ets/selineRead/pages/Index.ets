import { XAnimation, XContext } from 'commonpackage';
import { DownloadManageArk } from 'libohos_app_cangjie_entry.download.so';
import { webdavArk } from 'libohos_app_cangjie_entry.webdav.so';
import { DlpAntiPeepCallback, min_width } from '../commons/commonItem';
import { __Setting__, __System__, __UI__, __ZlibUser__ } from '../commons/shareDatas';
import { DecorBar } from '../components/DecorBar';
import { deleteDownloadCache } from '../models/utils/ClearDownloadCache';
import { Body } from './index/Body';
import { __ZlibHome__ } from './zlibrary/Home/Home';
import { dlpAntiPeep } from '@kit.DeviceSecurityKit';
import { BackgroundUtil } from '../models/classes/BackgroundRunningManager';


@Entry
@ComponentV2
struct Index {
  @Provider('tabController') tabController: TabsController = new TabsController();
  @Provider('currentTabIndex') currentTabIndex: number = 0

  async aboutToAppear(): Promise<void> {
    deleteDownloadCache()
    __ZlibUser__.downloadManageCJ = new DownloadManageArk(await XContext.getDownloadFolderPath())
    if (__Setting__.webdavServerEnabled) {
      BackgroundUtil.startContinuousTask()
      __Setting__.webdavClient =
        new webdavArk(await XContext.getDownloadFolderPath(), __Setting__.webdavPort, __Setting__.webdavAccount,
          __Setting__.webdavPassword)
      __Setting__.webdavClient?.start()
    }

    if (canIUse("SystemCapability.Security.DlpAntiPeep") && __Setting__.needDlpAntiPeep) {
      try {
        const isOpen = await dlpAntiPeep.isDlpAntiPeepSwitchOn();
        if (isOpen) {
          //开启防窥检测
          dlpAntiPeep.on('dlpAntiPeep', DlpAntiPeepCallback);
        } else {
          // 开关未开启，引导用户设置
          const result = await dlpAntiPeep.requestAntiPeepOptions(XContext.getAbilityContext());
          if (result === dlpAntiPeep.AntiPeepOptionsResult.SUCCESS ||
            result === dlpAntiPeep.AntiPeepOptionsResult.ALREADY_ON) { // 表示防窥保护开关开启成功或已开启
            dlpAntiPeep.on('dlpAntiPeep', DlpAntiPeepCallback);
          }else{
            __Setting__.needDlpAntiPeep = false
          }
        }
      } catch (error) {
        console.error(`Failed to init DlpAntiPeep. Code: ${error.code}, message: ${error.message}`);
      }
    }


  }

  aboutToDisappear() {
    //关闭隐私防窥
    try {
      dlpAntiPeep.off('dlpAntiPeep', DlpAntiPeepCallback);
    } catch (error) {
      console.error(`Failed to off DlpAntiPeep. Code: ${error.code}, message: ${error.message}`);
    }
  }

  onBackPress(): boolean | void {
    if (__ZlibHome__.inSearchMode || __ZlibHome__.recommendOrSearch == 1) {
      XAnimation.runWithAnimation(() => {
        __ZlibHome__.inSearchMode = false
        __ZlibHome__.recommendOrSearch = 0
        __ZlibHome__.searchWord = ''
      })
      return true
    }
    if (__System__.windowWidth < min_width && __UI__.isShowSideBar) {
      XAnimation.runWithAnimation(() => {
        __UI__.isShowSideBar = false
      })
      return true
    }

    return false
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      if (__System__.pcMode) {
        DecorBar()
          .zIndex(114514)
      }

      Navigation(__UI__.mainPageStack) {
        Body()
      }
      .size({ width: '100%', height: '100%' })
      .navBarWidthRange([400, 1200])
      .backgroundColor(Color.Transparent)
      .layoutWeight(1)
      .hideToolBar(true)
      .navBarWidth('1100')
      .mode(__UI__.indexNavigationMode)
      .onNavigationModeChange((mode) => {
        if (mode == NavigationMode.Split) {
          __UI__.mainPageStack.clear(true)
          __UI__.mainPageStack.pushPathByName('EmptyPage', false)
        }
        if (mode == NavigationMode.Auto) {
          __UI__.mainPageStack.clear(true)
          __UI__.mainPageStack.pushPathByName('EmptyPage', false)
        }
        if (mode == NavigationMode.Stack) {
          __UI__.mainPageStack.removeByName('EmptyPage')
        }
      })

    }.foregroundBlurStyle(__System__.isInBackGround ? BlurStyle.Thick : BlurStyle.NONE, {
      colorMode: ThemeColorMode.LIGHT,
      adaptiveColor: AdaptiveColor.DEFAULT
    });
  }
}


// SideBarContainer(__UI__.sideBarMode) {
//   SideBar()
//     .visibility(__System__.windowWidth >= min_width ? Visibility.Visible :
//       __UI__.isShowSideBar ? Visibility.Visible : Visibility.Hidden)
//
// }
// .showSideBar(__UI__.isShowSideBar)
// .sideBarPosition(__System__.windowWidth >= min_width ? SideBarPosition.Start :
//   __Setting__.isLeftHand ? SideBarPosition.Start : SideBarPosition.End)
// .autoHide(false)
// .showControlButton(false)
// .sideBarWidth(__UI__.isLargeSidebar ? 260 : 70)
// .maxSideBarWidth(__UI__.isLargeSidebar ? 260 : 70)
// .minSideBarWidth(__UI__.isLargeSidebar ? 260 : 70)
// .gesture(
//   PanGesture({ fingers: 1, direction: PanDirection.Right })
//     .onActionEnd(() => {
//       if (__System__.windowWidth < min_width) {
//         if (__Setting__.isLeftHand) {
//           XAnimation.runWithAnimation(() => {
//             __UI__.isShowSideBar = true
//           })
//         } else {
//           XAnimation.runWithAnimation(() => {
//             __UI__.isShowSideBar = false
//           })
//         }
//       }
//     })
// )
// .gesture(
//   PanGesture({ fingers: 1, direction: PanDirection.Left })
//     .onActionEnd(() => {
//       if (__System__.windowWidth < min_width) {
//         if (__Setting__.isLeftHand) {
//           XAnimation.runWithAnimation(() => {
//             __UI__.isShowSideBar = false
//           })
//         } else {
//           XAnimation.runWithAnimation(() => {
//             __UI__.isShowSideBar = true
//           })
//         }
//       }
//     })
// )
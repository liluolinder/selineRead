import { XAnimation, XContext } from 'commonpackage';
import { DownloadManageArk } from 'libohos_app_cangjie_entry.download.so';
import { webdavArk } from 'libohos_app_cangjie_entry.webdav.so';
import { min_width } from '../commons/commonItem';
import { __Setting__, __System__, __UI__, __ZlibUser__ } from '../commons/shareDatas';
import { DecorBar } from '../components/DecorBar';
import { deleteDownloadCache } from '../models/utils/ClearDownloadCache';
import { Body } from './index/Body';
import { SideBar } from './index/SideBar';
import { __Home__ } from './zlibrary/Home/Home';
import { dlpAntiPeep } from '@kit.DeviceSecurityKit';
import { window } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';


@Entry
@ComponentV2
struct Index {
  @Provider('tabController') tabController: TabsController = new TabsController();
  @Provider('currentTabIndex') currentTabIndex: number = 0

  private hasShownMask: boolean = false;

  private onStatusChange = async (status: dlpAntiPeep.DlpAntiPeepStatus): Promise<void> => {
    if (status === dlpAntiPeep.DlpAntiPeepStatus.PASS) { // 表示当前状态为无人窥视
      console.info('DlpAntiPeepStatus is PASS.');
    } else if (status === dlpAntiPeep.DlpAntiPeepStatus.HIDE) { // 表示有人在窥屏，应用可以进行隐私保护操作。
      console.info('DlpAntiPeepStatus is HIDE.');
      if (!this.hasShownMask) {
        await this.setMaskLayer(); // 拉起系统蒙层
      }
    }
  }

  private async setMaskLayer(): Promise<void> {
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const windowClass = await window.getLastWindow(context);
      const windowId = windowClass.getWindowProperties().id;
      await dlpAntiPeep.setAntiPeepMaskLayer(windowId);
      this.hasShownMask = true; // 避免窥视状态时频繁拉起蒙层
    } catch (error) {
      console.error(`Failed to set AntiPeep MaskLayer. Code: ${error.code}, message: ${error.message}`);
    }
  }

  async aboutToAppear(): Promise<void> {
    deleteDownloadCache()
    __ZlibUser__.downloadManageCJ = new DownloadManageArk(await XContext.getDownloadFolderPath())
    if (__Setting__.webdavServerEnabled) {
      __Setting__.webdavClient =
        new webdavArk(await XContext.getDownloadFolderPath(), __Setting__.webdavPort, __Setting__.webdavAccount,
          __Setting__.webdavPassword)
      __Setting__.webdavClient?.start()
    }

    try {
      const isOpen = await dlpAntiPeep.isDlpAntiPeepSwitchOn();
      if (isOpen) {
        dlpAntiPeep.on('dlpAntiPeep', this.onStatusChange);
      } else {
        // 开关未开启，引导用户设置
        const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
        const result = await dlpAntiPeep.requestAntiPeepOptions(context);
        if (result === dlpAntiPeep.AntiPeepOptionsResult.SUCCESS ||
          result === dlpAntiPeep.AntiPeepOptionsResult.ALREADY_ON) { // 表示防窥保护开关开启成功或已开启
          dlpAntiPeep.on('dlpAntiPeep', this.onStatusChange);
        }
      }
    } catch (error) {
      console.error(`Failed to init DlpAntiPeep. Code: ${error.code}, message: ${error.message}`);
    }
  }

  aboutToDisappear() {
    try {
      dlpAntiPeep.off('dlpAntiPeep', this.onStatusChange);
    } catch (error) {
      console.error(`Failed to off DlpAntiPeep. Code: ${error.code}, message: ${error.message}`);
    }
  }

  onBackPress(): boolean | void {
    if (__Home__.inSearchMode || __Home__.recommendOrSearch == 1) {
      XAnimation.runWithAnimation(() => {
        __Home__.inSearchMode = false
        __Home__.recommendOrSearch = 0
        __Home__.searchWord = ''
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

    }
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
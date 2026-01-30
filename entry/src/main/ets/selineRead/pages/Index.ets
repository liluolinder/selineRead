import { XAnimation, XContext } from 'commonpackage';
import { zlibClient } from '../../zlibrary/zlibClient';
import { min_width } from '../commons/commonItem';
import { __Setting__, __System__, __UI__, __ZlibUser__ } from '../commons/shareDatas';
import { DecorBar } from '../components/DecorBar';
import { RelationStoreManager } from '../models/classes/DataBase';
import { deleteDownloadCache } from '../models/utils/ClearDownloadCache';
import { Body } from './index/Body';
import { SideBar } from './index/SideBar';
import { __Home__ } from './zlibrary/Home/Home';


@Entry
@ComponentV2
struct Index {
  @Provider('tabController') tabController: TabsController = new TabsController();
  @Provider('currentTabIndex') currentTabIndex: number = 0

  aboutToAppear(): void {
    deleteDownloadCache()
  }

  onBackPress(): boolean | void {
    if (__Home__.inSearchMode) {
      XAnimation.runWithAnimation(() => {
      __Home__.inSearchMode = false
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

      Navigation(__UI__.mainPageStack)
      {
        SideBarContainer(__UI__.sideBarMode) {
          SideBar().visibility(__System__.windowWidth >= min_width ?Visibility.Visible :__UI__.isShowSideBar?Visibility.Visible:Visibility.Hidden)
          Body()
        }
        .showSideBar(__UI__.isShowSideBar)
        .sideBarPosition(__System__.windowWidth >= min_width ? SideBarPosition.Start : __Setting__.isLeftHand?SideBarPosition.Start:SideBarPosition.End)
        .autoHide(false)
        .showControlButton(false)
        .sideBarWidth(__UI__.isLargeSidebar ? 260 : 70)
        .maxSideBarWidth(__UI__.isLargeSidebar ? 260 : 70)
        .minSideBarWidth(__UI__.isLargeSidebar ? 260 : 70)
        .gesture(
          PanGesture({ fingers: 1, direction: PanDirection.Right })
            .onActionEnd(() => {
              if (__System__.windowWidth < min_width) {
                if (__Setting__.isLeftHand){
                  XAnimation.runWithAnimation(() => {
                    __UI__.isShowSideBar = true
                  })
                }else {
                  XAnimation.runWithAnimation(() => {
                    __UI__.isShowSideBar = false
                  })
                }
              }
            })
        )
        .gesture(
          PanGesture({ fingers: 1, direction: PanDirection.Left })
            .onActionEnd(() => {
              if (__System__.windowWidth < min_width) {
                if (__Setting__.isLeftHand){
                  XAnimation.runWithAnimation(() => {
                    __UI__.isShowSideBar = false
                  })
                }else {
                  XAnimation.runWithAnimation(() => {
                    __UI__.isShowSideBar = true
                  })
                }
              }
            })
        )
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

import { XAnimation, XContext } from 'commonpackage';
import { zlibClient } from '../../zlibrary/zlibClient';
import { min_width } from '../commons/commonItem';
import { __System__, __UI__ } from '../commons/shareDatas';
import { DecorBar } from '../components/DecorBar';
import { Body } from './index/Body';
import { SideBar } from './index/SideBar';
import { http } from '@kit.NetworkKit';
import { I_BookInfo } from '../models/interfaces/I_BookInfo';


const TAG = 'DocumentScanner'
@Entry
@Component
struct Index {

  async aboutToAppear(): Promise<void> {
    __UI__.mainPageStack.pushPathByName('indexPage', undefined, false)
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      if (__System__.pcMode) {
        DecorBar()
          .zIndex(114514)
      }

      Navigation(__UI__.mainPageStack)
        .size({ width: '100%', height: '100%' })
        .backgroundColor(Color.Transparent)
        .layoutWeight(1)
        .hideToolBar(true)
        .navBarWidth(__System__.windowWidth / 2.5 + (__UI__.isLargeSidebar ? 190 : 0))
        .mode(__UI__.indexNavigationMode)
        .onNavigationModeChange((mode) => {
          __UI__.indexNavigationMode = mode
        })
    }
  }
}

@Builder
export function indexPageBuilder() {
  IndexPage()
}

@ComponentV2
struct IndexPage {
  build() {
    NavDestination() {
      SideBarContainer(__UI__.sideBarMode) {
        SideBar()
        Body()
      }
      .showSideBar(__UI__.isShowSideBar)
      .autoHide(false)
      .showControlButton(false)
      .sideBarWidth(__UI__.isLargeSidebar ? 260 : 70)
      .maxSideBarWidth(__UI__.isLargeSidebar ? 260 : 70)
      .minSideBarWidth(__UI__.isLargeSidebar ? 260 : 70)
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
    .hideTitleBar(true)
    .onBackPressed(() => {
      XContext.getAbilityContext().moveAbilityToBackground().catch(() => {})
      return true
    })
    .transition(TransitionEffect.OPACITY)

  }
}
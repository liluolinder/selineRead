import { XAnimation } from 'commonpackage';
import { zlibClient } from '../../zlibrary/zlibClient';
import { min_width } from '../commons/commonItem';
import { __System__, __UI__ } from '../commons/shareDatas';
import { DecorBar } from '../components/DecorBar';
import { Body } from './index/Body';
import { SideBar } from './index/SideBar';
import { http } from '@kit.NetworkKit';
import { __Home__ } from './zlibrary/Home/Home';
import { I_BookInfo } from '../models/interfaces/I_BookInfo';


@Entry
@Component
struct Index {

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      if (__System__.pcMode) {
        DecorBar()
          .zIndex(114514)
      }

      Navigation(__UI__.mainPageStack)
      {
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

import { XAnimation, XPreferencesManager } from "commonpackage";
import { min_width } from "../../commons/commonItem";
import { __System__, __UI__ } from "../../commons/shareDatas";
import { Home } from "../Home/Home";

@ComponentV2
export struct Body {
  @Consumer('tabController') tabController: TabsController = new TabsController();
  @Consumer('mainPageStack') pageStack: NavPathStack = new NavPathStack()
  @Consumer('currentTabIndex') currentTabIndex: number = 0



  build() {
    Stack() {
      Tabs({ controller: this.tabController, index: $$this.currentTabIndex }) {
        TabContent() {
          Home()
        }

        TabContent() {

        }

        TabContent() {
        }
      }
      .height('100%')
      .scrollable(false)
      .vertical(__System__.windowWidth > min_width)
      .barWidth(0)
      .barHeight(0)
      .barMode(BarMode.Fixed)
      .backgroundColor($r('sys.color.comp_background_gray'))

      if (__System__.windowWidth < min_width && __UI__.isShowSideBar) {
        Stack().height('100%').width('100%').onClick(() => {
          XAnimation.runWithAnimation(() => __UI__.isShowSideBar = false)
        })
      }

    }.size({ width: '100%', height: '100%' })
    .transition(TransitionEffect.OPACITY)

  }
}
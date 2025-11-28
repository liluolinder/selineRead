import { XAnimation, XContext, XPreferencesManager } from "commonpackage";
import { zlibClient } from "../../../zlibrary/zlibClient";
import { min_width } from "../../commons/commonItem";
import { __System__, __UI__ } from "../../commons/shareDatas";
import { Home, __Home__ } from "../zlibrary/Home/Home";
import { http } from "@kit.NetworkKit";
import { I_BookInfo } from "../../models/interfaces/I_BookInfo";
import { BookShelf, __BookShelf__ } from "../zlibrary/BookShelf/BookShelf";
import { fileIo } from "@kit.CoreFileKit";

@ComponentV2
export struct Body {
  @Consumer('tabController') tabController: TabsController = new TabsController();
  @Consumer('mainPageStack') pageStack: NavPathStack = new NavPathStack()
  @Consumer('currentTabIndex') currentTabIndex: number = 0

  @Monitor("currentTabIndex")
  async monitorIndexChange(){
    if (__System__.windowWidth < min_width) {
      XAnimation.runWithAnimation(() => {
        __UI__.isShowSideBar = false
      })
    }

    switch (this.currentTabIndex){
      case 1:
        __BookShelf__.bookList.clearData()
        fileIo.listFileSync(await XContext.getDownloadFolderPath()).forEach((item)=>{
          console.log(item)
          __BookShelf__.bookList.pushData(item)
        })

        break;

    }
  }

  aboutToAppear(): void {
    zlibClient.refreshUrl().then(()=>{
      let req = http.createHttp()
      zlibClient.getRecommendBook(req, __Home__.recommendBookIndex).then((res)  => {
        __Home__.canGetMore = true
        if (res[0] == 1) {
          (JSON.parse(res[1]) as I_BookInfo[]).forEach((item) => {
            __Home__.recommendBookArray.pushData(item)
          })
          __Home__.recommendBookIndex++
          __Home__.errorText = ''
        }else {
          __Home__.errorText = res[1]
        }
      })
    })
  }

  build() {
    Stack() {
      Tabs({ controller: this.tabController, index: $$this.currentTabIndex }) {
        TabContent() {
          Home()
        }

        TabContent() {
          BookShelf()
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
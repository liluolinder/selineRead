import { min_width, __System__, __UI__ } from "../../datas/classes/ShareDatas";
import { XAnimation } from "../../datas/classes/XAnimation";
import { BookList } from "../../pages/BookList/bookListList";
import { BookShelf } from "../../pages/BookShelf/BookShelf";
import { personal } from "../../pages/personal/personal";
import { zlibHome } from "../../pages/zlibHome/zlibHome";


@ComponentV2
export struct Body {
    @Consumer('tabController') tabController: TabsController = new TabsController();
    @Consumer('mainPageStack') pageStack: NavPathStack = new NavPathStack()
    @Consumer('currentTabIndex') currentTabIndex: number = 0

    @Monitor('currentTabIndex')
    changeIndexNavigationMode() {

    }

    build() {
        Stack() {
            Tabs({ controller: this.tabController, index: $$this.currentTabIndex }) {
                TabContent() {
                    zlibHome()
                }

                TabContent() {
                    BookList()
                }

                TabContent() {
                    BookShelf()
                }
                TabContent() {
                    personal()

                }
            }
            .height('100%')
            .scrollable(false)
            .vertical(__System__.windowWidth > min_width)
            .barWidth(0)
            .barHeight(0)
            .barMode(BarMode.Fixed)

            if (__System__.windowWidth < min_width && __UI__.isShowSideBar) {
                Stack().height('100%').width('100%').onClick(() => {
                    XAnimation.runWithAnimation(() => __UI__.isShowSideBar = false)
                })
            }

        }.size({ width: '100%', height: '100%' })


    }
}
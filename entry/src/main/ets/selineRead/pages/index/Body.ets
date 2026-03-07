import { XAnimation, XContext, XPreferencesManager } from "commonpackage";
import { zlibClient } from "../../../zlibrary/zlibClient";
import { min_width } from "../../commons/commonItem";
import { __Download__, __System__, __UI__, __ZlibUser__ } from "../../commons/shareDatas";
import { Home, __Home__ } from "../zlibrary/Home/Home";
import { http } from "@kit.NetworkKit";
import { I_BookInfo } from "../../models/interfaces/I_BookInfo";
import { BookShelf, __BookShelf__ } from "../BookShelf/BookShelf";
import { fileIo } from "@kit.CoreFileKit";
import { RelationStoreManager } from "../../models/classes/DataBase";
import { I_BookShelfBookInfo } from "../../models/interfaces/I_BookShelfBookInfo";
import { CommonEvent } from "../../models/classes/CommonEvent";
import { I_BasicUserInfo } from "../../../zlibrary/interface/I_ZlibUserInfo";
import { I_loginRes_user } from "../../../zlibrary/interface/I_loginInfo";
import { I_ZlibBookInfoRes_Book, I_ZLibRecommendBook_Book } from "../../../zlibrary/interface/I_ZlibBookInfo";
import { ZlibClientArk } from "libohos_app_cangjie_entry.so";

@ComponentV2
export struct Body {
  @Consumer('tabController') tabController: TabsController = new TabsController();
  @Consumer('mainPageStack') pageStack: NavPathStack = new NavPathStack()
  @Consumer('currentTabIndex') currentTabIndex: number = 0

  @Monitor("currentTabIndex")
  async monitorIndexChange() {
    switch (this.currentTabIndex) {
      case 1:
        __BookShelf__.gettingBookNow = true
        __BookShelf__.bookList.clearData()
        let downloadPath = await XContext.getDownloadFolderPath()
        fileIo.listFileSync(downloadPath).forEach((item) => {
          let textFragment: string[] = item.split('.')
          if (textFragment[textFragment.length-1] != 'sfftdownload') {
            let bookInfo: I_BookShelfBookInfo = {
              bookName: item,
              bookPath: downloadPath + item,
              bookImage: $r('app.media.default_cover'),
              bookAuthor: "",
              bookHref:"",
              bookId:0
            }

            __Download__.downloadArray.dataArray.forEach((itemA) => {

              if (itemA.fileName.includes(item)|| itemA.fileName.split('.')[0].includes(item) || itemA.fileName.includes(item.split('.')[0]) || item.includes(itemA.fileName)||item.includes(itemA.fileName.split('.')[0])) {
                bookInfo.bookImage = itemA.fileImage
                bookInfo.bookAuthor = itemA.bookAuthor
                bookInfo.bookHref = itemA.bookHref
                bookInfo.bookId = itemA.bookId
                return
              }
            })
            __BookShelf__.bookList.pushData(bookInfo)
          } else {
            try {
              fileIo.unlinkSync(downloadPath + item)
              console.log('删除废物文件失成功')
            } catch (e) {
              console.log('删除废物文件失败' + JSON.stringify(e))
            }
          }
        })
        __BookShelf__.gettingBookNow = false
        break;

    }
  }

  aboutToAppear(): void {

    let client = new ZlibClientArk()
    client.checkAccess(true,(res)=>{
      if (res) {
        client.getRecommendBook(
         async  (books) => {
            if (books.length == 0) {
              __Home__.errorText = '返回值为空'
            }else {
              books.forEach((item)=>{
                __Home__.recommendBookArray.pushData(item)
              })
              __Home__.recommendBookIndex++
              __Home__.errorText = ''
            }
            __Home__.canGetMore = true
          },
          (error) => {
            __Home__.errorText = error
            __Home__.canGetMore = true
          })
      }
    }, (err)=>{__Home__.errorText = err})

/*    zlibClient.refreshUrl().then(() => {
      console.log(__ZlibUser__.cookie);
      let req = http.createHttp()
      zlibClient.getRecommendBook(req).then((res) => {
        console.log(JSON.stringify(res))
        __Home__.canGetMore = true
        if (res[0] == 1) {
          console.log(JSON.stringify(res[1]));
          if (JSON.stringify(res[1]) == "\"[]\"" ) {
            __Home__.errorText = '返回值为空'
          }else {
            (JSON.parse(res[1]) as I_ZLibRecommendBook_Book[]).forEach((item) => {
              __Home__.recommendBookArray.pushData(item)
            })
          }
        } else {
          __Home__.errorText = res[1]
        }
      })

      if (__ZlibUser__.cookie!='') {
        zlibClient.getPersonInfo(__ZlibUser__.cookie).then((res) => {
          if (res[0] == 1) {
            let basicInfo = JSON.parse(res[1]) as I_loginRes_user
            __ZlibUser__.avatar = ''
            __ZlibUser__.userName = basicInfo.name
          }
        })
      }

    })*/
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
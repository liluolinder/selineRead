import { LFileKit, XAnimation, XContext, XPreferencesManager } from "commonpackage";
import { min_width } from "../../commons/commonItem";
import { __Download__, __HWShare__, __Setting__, __System__, __UI__, __ZlibUser__ } from "../../commons/shareDatas";
import { ZlibHome, __ZlibHome__ } from "../zlibrary/Home/Home";
import { BookShelf, __BookShelf__ } from "../BookShelf/BookShelf";
import { fileIo } from "@kit.CoreFileKit";
import { I_BookShelfBookInfo } from "../../models/interfaces/I_BookShelfBookInfo";
import { hdsMaterial, HdsTabs, HdsTabsController } from "@kit.UIDesignKit";
import { SymbolGlyphModifier } from "@kit.ArkUI";
import { SettingBuilder } from "../setting/Setting";
import { AboutUsBuilder } from "../AboutUS/AboutUS";
import { ZlibBookInfoBriefArk } from "libohos_app_cangjie_entry.zlib4cj.so";
import { relationalStore } from "@kit.ArkData";
import { RelationStoreManager } from "../../models/classes/DataBase";
import { EventHelper } from "../../models/classes/BaseEvent";
import { I_BookInfoParam } from "../../models/interfaces/I_BookInfoParam";
import { BookSourceHome } from "../booksource/Home";
import { SourceManagerSheetBuilder } from "../booksource/SourceManagerSheet";
import { ZlibraryAccount, ZlibraryAccountBuilder } from "../zlibrary/AccountManager/ZlibraryAccount";

@ComponentV2
export struct Body {
  @Provider("showSetting") showSetting:boolean = false
  @Provider("showAboutUs") showAboutUs:boolean = false
  @Provider('showAccountSourceSheet') showAccountSourceSheet:boolean = false
  @Consumer('tabController') tabController: HdsTabsController = new HdsTabsController();
  @Consumer('mainPageStack') pageStack: NavPathStack = new NavPathStack()
  @Consumer('currentTabIndex') currentTabIndex: number = 0

  @Monitor("currentTabIndex")
  async monitorIndexChange() {
    switch (this.currentTabIndex) {
      case 1:
        __BookShelf__.gettingBookNow = true
        __BookShelf__.bookList.clearData()
        let downloadPath = await XContext.getDownloadFolderPath()
        LFileKit.listDir(downloadPath).then((meow)=>{
          meow.forEach((item) => {
            let textFragment: string[] = item.split('.')
            if (textFragment[textFragment.length - 1] != 'sfftdownload') {
              let bookInfo: I_BookShelfBookInfo = {
                bookName: item,
                bookPath: downloadPath + item,
                bookImage: $r('app.media.default_cover'),
                bookAuthor: "",
                bookHref: "",
                bookId: 0
              }
              __Download__.downloadArray.dataArray.forEach((itemA) => {
                if (itemA.fileName.includes(item) || itemA.fileName.split('.')[0].includes(item) ||
                  itemA.fileName.includes(item.split('.')[0]) || item.includes(itemA.fileName) ||
                  item.includes(itemA.fileName.split('.')[0])) {
                  bookInfo.bookImage = itemA.fileImage
                  bookInfo.bookAuthor = itemA.bookAuthor
                  bookInfo.bookHref = itemA.bookHref
                  bookInfo.bookId = itemA.bookId
                  console.log(bookInfo.bookHref)
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
        })
        __BookShelf__.gettingBookNow = false
        break;
    }
  }



  private putBooks(books:ZlibBookInfoBriefArk[]){
    if (books.length == 0) {
      __ZlibHome__.errorText = '返回值为空'
    } else {
      books.forEach((item) => {
        __ZlibHome__.recommendBookArray.pushData(item)
      })
      __ZlibHome__.errorText = ''
    }
    __ZlibHome__.canGetMore = true
  }

  private getCommonRecommend(){
    __ZlibUser__.zlibClient.getRecommendBook(
      async (books) => {
        this.putBooks(books)
      },
      (error) => {
        __ZlibHome__.errorText = error
        __ZlibHome__.canGetMore = true
      })
  }

  private loginAndGetRecommend(){
    if (__ZlibUser__.account != '') {
      __ZlibUser__.zlibClient.login(__ZlibUser__.account, __ZlibUser__.password, (res) => {
        __ZlibUser__.localChooseAccount = res
        __ZlibUser__.cookie = res.cookie
        __ZlibUser__.userName = res.name
        __ZlibUser__.localChooseAccount.getRecommendBook((books)=>{
          this.putBooks(books)
          if(books.length == 0 ){
            this.getCommonRecommend()
          }
        },(error)=>{
          __ZlibHome__.errorText = error
          __ZlibHome__.canGetMore = true
        })
      }, (error) => {
        __ZlibUser__.userName = "登录失败"
        __ZlibHome__.errorText = error
        this.getCommonRecommend()
      })
    }else {
      this.getCommonRecommend()
    }

    if (__HWShare__.bookFromShare) {
      console.log(`meow:未收到通知但是更新:${JSON.stringify(__HWShare__.bookFromShare)}`)
      if (__HWShare__.bookFromShare) {
        let param:I_BookInfoParam = {
          type: 0,
          data:__HWShare__.bookFromShare
        }
        __UI__.mainPageStack.pushPathByName("bookInfoPage", param )
        __HWShare__.bookFromShare = undefined
      }
    }
    EventHelper.emitterListener('getNewBook', () => {
      console.log(`meow:收到通知:${JSON.stringify(__HWShare__.bookFromShare)}`)
      if (__HWShare__.bookFromShare) {
        let param:I_BookInfoParam = {
          type: 0,
          data:__HWShare__.bookFromShare
        }
        __UI__.mainPageStack.pushPathByName("bookInfoPage", param )
        __HWShare__.bookFromShare = undefined
      }
    })
  }

  aboutToAppear(): void {
    if (__Setting__.appWorkMode == 0) {
      //如果为自定义地址并且设置了自动更新地址则进行地址刷新
      if (__ZlibUser__.urlType == 1 && __Setting__.autoRefreshUrl) {
        __ZlibUser__.zlibClient.checkAccess(true, (res) => {
          if (res) {
            __ZlibUser__.zlibClient.getZlibUrl((res) => {
              if (!(__ZlibUser__.base_url != '' && (res.includes(__ZlibUser__.base_url) || __ZlibUser__.base_url.includes(res)))) {
                //如果发生Url切换了则更新数据库和暂存数据及首选项
                let predicates = new relationalStore.RdbPredicates('ZlibServiceUrl').equalTo('Url', __ZlibUser__.base_url)
                let predicatesNewUrl = new relationalStore.RdbPredicates('ZlibServiceUrl').equalTo('Url', res)
                let flag = RelationStoreManager.checkIsAlive(__ZlibUser__.dataBase,predicatesNewUrl)
                console.log(`存在新地址${flag}`)
                //表示更新后的地址已经存在则删除原有地址，不增加新地址
                if (flag) {
                  console.log(`更新后的地址已存在，不更新，删除更新前地址`)
                  RelationStoreManager.deleteValue(__ZlibUser__.dataBase, predicates)
                }else {
                  console.log(`更新后的地址不存在，更新地址`)
                  RelationStoreManager.updateValue(__ZlibUser__.dataBase, predicates, {
                    Url: res,
                  })
                }
                __ZlibUser__.base_url = res
                XPreferencesManager.putPreferencesValue('selineRead', "zlibBaseUrl", res)
              }else {
                console.log(`无需更新地址`)
              }
            })
            this.loginAndGetRecommend()
          }
        }, (err) => {
          __ZlibHome__.errorText = err
        })
      }else {
        this.loginAndGetRecommend()
      }
    }
  }

  @Builder
  changeModeMenu() {
    Menu() {
      MenuItem({  content: "ZLibrary" })
        .onClick(()=>{
          if (__Setting__.appWorkMode!=0) {
            __Setting__.appWorkMode = 0
            XPreferencesManager.putPreferencesValue('selineRead', "appWorkMode", 0)
            if (__ZlibUser__.urlType == 1 && __Setting__.autoRefreshUrl) {
              __ZlibUser__.zlibClient.checkAccess(true, (res) => {
                console.log(`meow:${res}`)
                if (res) {
                  __ZlibUser__.zlibClient.getZlibUrl((res) => {
                    if (!(__ZlibUser__.base_url != '' && (res.includes(__ZlibUser__.base_url) || __ZlibUser__.base_url.includes(res)))) {
                      //如果发生Url切换了则更新数据库和暂存数据及首选项
                      let predicates = new relationalStore.RdbPredicates('ZlibServiceUrl').equalTo('Url', __ZlibUser__.base_url)
                      let predicatesNewUrl = new relationalStore.RdbPredicates('ZlibServiceUrl').equalTo('Url', res)
                      let flag = RelationStoreManager.checkIsAlive(__ZlibUser__.dataBase,predicatesNewUrl)
                      console.log(`存在新地址${flag}`)
                      //表示更新后的地址已经存在则删除原有地址，不增加新地址
                      if (flag) {
                        console.log(`更新后的地址已存在，不更新，删除更新前地址`)
                        RelationStoreManager.deleteValue(__ZlibUser__.dataBase, predicates)
                      }else {
                        console.log(`更新后的地址不存在，更新地址`)
                        RelationStoreManager.updateValue(__ZlibUser__.dataBase, predicates, {
                          Url: res,
                        })
                      }
                      __ZlibUser__.base_url = res
                      XPreferencesManager.putPreferencesValue('selineRead', "zlibBaseUrl", res)
                    }else {
                      console.log(`无需更新地址`)
                    }
                  })
                  this.loginAndGetRecommend()
                }
              }, (err) => {
                __ZlibHome__.errorText = err
              })
            }else {
              this.loginAndGetRecommend()
            }

          }
        })
      MenuItem({  content: "书源" })
        .onClick(()=>{
          if (__Setting__.appWorkMode!=1) {
            __Setting__.appWorkMode = 1
            XPreferencesManager.putPreferencesValue('selineRead', "appWorkMode", 1)

          }
        })

    }
  }

  @Builder
  miniBarBuilder() {
    Row() {

      Column(){
        Image($r('app.media.zlib'))
          .draggable(false)
      }.width(48)
      .height(48)
      .margin({ left: 4, right: 4 })
      .bindContextMenu(this.changeModeMenu,ResponseType.RightClick | ResponseType.LongPress,{
        enableArrow:true
      })

      Button({ type: ButtonType.Circle }) {
        SymbolGlyph($r('sys.symbol.download'))
          .fontSize(25)
          .fontColor([$r('sys.color.font')])
      }
      .width(48)
      .height(48)
      .backgroundColor(Color.Transparent)
      .margin({ left: 4, right: 4 })
      .onClick(() => {
        __UI__.mainPageStack.pushPathByName('DownloadPage', null)
      })


      Button({ type: ButtonType.Circle }) {
        SymbolGlyph($r('sys.symbol.gearshape'))
          .fontSize(25)
          .fontColor([$r('sys.color.font')])
      }
      .width(48)
      .height(48)
      .backgroundColor(Color.Transparent)
      .margin({ left: 4, right: 4 })
      .onClick(() => {
        this.showSetting = true
      })


      Button({ type: ButtonType.Circle }) {
        SymbolGlyph($r('sys.symbol.info_circle'))
          .fontSize(25)
          .fontColor([$r('sys.color.font')])
      }
      .width(48)
      .height(48)
      .backgroundColor(Color.Transparent)
      .margin({ left: 4, right: 4 })
      .onClick(()=>{
        this.showAboutUs = true
      })
      .bindSheet($$this.showAboutUs,AboutUsBuilder(),{
        preferType:SheetType.CENTER,
        height:SheetSize.LARGE,
        title:{title:$r('app.string.Title_AboutUS')},
        backgroundColor:$r('sys.color.background_tertiary')
      })

    }.justifyContent(FlexAlign.SpaceAround)
    .width('100%')
  }

  build() {
    Stack() {
      HdsTabs({ controller: this.tabController }) {
        TabContent() {
          if (__Setting__.appWorkMode == 0){
            ZlibHome()
          }else {
            BookSourceHome()
          }
        }.tabBar(new BottomTabBarStyle({
          normal: new SymbolGlyphModifier($r('sys.symbol.house')),
        }, $r('app.string.Title_Home')))

        TabContent() {
          BookShelf()
        }.tabBar(new BottomTabBarStyle({
          normal: new SymbolGlyphModifier($r('sys.symbol.book_closed_right_left')),
        }, $r('app.string.Title_BookShelf')))

        TabContent() {

        }.tabBar(new BottomTabBarStyle({
          normal: new SymbolGlyphModifier($r('sys.symbol.person')),
        },__Setting__.appWorkMode == 0 ? __ZlibUser__.account != '' ?__ZlibUser__.userName:'请先登录' :"书源模式"))

      }
      .barOverlap(true)
      .animationDuration(300)
      .scrollable(false)
      .barPosition(BarPosition.End)
      .height('100%')
      .backgroundColor($r('sys.color.comp_background_gray'))
      .barFloatingStyle({
        barWidth: { smallWidth: 230, mediumWidth: 260, largeWidth: 300 },
        barBottomMargin: 28,
        systemMaterialEffect: {
          materialType: hdsMaterial.MaterialType.IMMERSIVE,
          materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
        },
        miniBar: {
          miniBarBuilder: () => this.miniBarBuilder(),
          miniBarWidth:{smallWidth: 230,mediumWidth: 250,largeWidth:250}
        }
      })
      .onContentWillChange((currentIndex: number, comingIndex: number)=>{
        if (comingIndex == 2) {
          this.showAccountSourceSheet = true
        }
        return !(comingIndex == 2)
      })
      .onChange((index)=>{
        if (index==2) {
          index = this.currentTabIndex
        }
        this.currentTabIndex = index
      })
      .bindSheet($$this.showAccountSourceSheet, __Setting__.appWorkMode==0?ZlibraryAccountBuilder(): SourceManagerSheetBuilder(), {
        showClose:false,
        preferType:SheetType.CENTER,
        height:SheetSize.LARGE,
        backgroundColor:$r('sys.color.background_tertiary')
      })

      if (__System__.windowWidth < min_width && __UI__.isShowSideBar) {
        Stack().height('100%').width('100%').onClick(() => {
          XAnimation.runWithAnimation(() => __UI__.isShowSideBar = false)
        })
      }

      Column(){
        Blank()
          .bindSheet($$this.showSetting,SettingBuilder(),{
          preferType:SheetType.CENTER,
          height:SheetSize.LARGE,
          title:{title:$r('app.string.Title_Setting')},
          backgroundColor:$r('sys.color.background_tertiary')
        })
      }


    }.size({ width: '100%', height: '100%' })
    .transition(TransitionEffect.OPACITY)

  }
}
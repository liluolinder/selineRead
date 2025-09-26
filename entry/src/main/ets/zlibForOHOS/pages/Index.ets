/*
Copyright (c) 2025 琉离铟落linder
SelineRead is licensed under Mulan PSL v2.
You can use this software according to the terms and conditions of the Mulan
PSL v2.
You may obtain a copy of Mulan PSL v2 at:
         http://license.coscl.org.cn/MulanPSL2
THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY
KIND, EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO
NON-INFRINGEMENT, MERCHANTABILITY OR FIT FOR A PARTICULAR PURPOSE.
See the Mulan PSL v2 for more details.

Mulan Permissive Software License，Version 2

Mulan Permissive Software License，Version 2 (Mulan PSL v2)

January 2020 http://license.coscl.org.cn/MulanPSL2
 */

import { globalContext, globalUIContext } from '../../entryability/EntryAbility';
import { linderPixelMap } from '../datas/classes/LPixelMap';
import { minWidth,
  __CustomBackgroundData__,
  __DataBase__, __System__, __UI__, __User__ } from '../datas/classes/ShareDatas';
import { zlibClient } from '../datas/classes/zlib';
import NeoPreferencesUtil from '../datas/classes/XPreferencesUtil'
import { personal } from './personal/personal';
import { zlibHome, __zlibHomeData__ } from './zlibHome/zlibHome';
import { linderDataBaseManger } from '../datas/classes/LDataBaseManager';
import { zlibHaveDownloadTable } from '../datas/commons/zlibHaveDownloadTable';
import { BookShelf } from './BookShelf/BookShelf';
import { XAnimation } from '../datas/classes/XAnimation';
import { zlibIndexShowMod } from '../datas/enums/zlibIndexShowMod';
import { DecorBar } from './others/DecorBar';
import { BookList, __BookListData__ } from './BookList/bookListList';
import { zlibDownloadingTable } from '../datas/commons/zlibDownloadingTable';
import { I_searchBook } from '../datas/interfaces/I_BookInfo';
import { getShareLink, setContinueState } from '../utils/ToolsUtil';
import { I_RecommendBook } from '../datas/interfaces/I_RecommendBook';
import { curves } from '@kit.ArkUI';
import { I_ReadLists_Bookshelf } from '../datas/interfaces/I_BookShelf';
import { customBackground } from './others/Builder';
import { JSON } from '@kit.ArkTS';
import { pushToken, pushTokenDataBase } from '../datas/classes/LCloudDataBaseKit';
import { linderPush } from '../datas/classes/LPushKit';


@Entry
@ComponentV2
struct Index {
  private tabsArrayOnline: [string, Resource, Resource][] = [
    ['书库', $r('sys.symbol.book'), $r('sys.symbol.book_open_fill')],
    ['书单', $r('sys.symbol.list_bullet'), $r('sys.symbol.list_bullet')],
    ['书架', $r('sys.symbol.book_closed_right_left'), $r('sys.symbol.books_vertical_fill')],
    ['我的', $r('sys.symbol.person'), $r('sys.symbol.person_fill')]
  ]

  private tabsArray: [string, Resource, Resource][] = [
    ['书架', $r('sys.symbol.book_closed_right_left'), $r('sys.symbol.books_vertical_fill')],
    ['我的', $r('sys.symbol.person'), $r('sys.symbol.person_fill')]
  ]

  @Local currentPage: number = 0

  async aboutToAppear(): Promise<void> {

    __DataBase__.baseStore = await linderDataBaseManger.createRelationalStoreDataBase(globalContext, {
      dataBaseName: 'selineRead',
    })
    linderDataBaseManger.createTableForRelationDataBase(__DataBase__.baseStore, 'zlibHaveDownload',
      zlibHaveDownloadTable,5)

    linderDataBaseManger.createTableForRelationDataBase(__DataBase__.baseStore, 'I_zlibDownloadingTable',
      zlibDownloadingTable,5)


    __User__.avatar = linderPixelMap.ISHaveAvatar(globalContext)
    __User__.isLoginZlib = NeoPreferencesUtil.getPreferencesValue("selineRead", 'isLoginZlib', false) as boolean

    if (__UI__.onlineMode) {
      await zlibClient.refreshUrl().then(async () => {
        zlibClient.getRecommendBooks(1)
        if (__User__.isLoginZlib && __UI__.onlineMode) {
          zlibClient.getUserInfo()
        }
      })
      this.proccessContinueData()
    }

    if(NeoPreferencesUtil.getPreferencesValue('selineRead', 'isUploadPushToken', false)){
      let record = new pushToken()
      record.pushToken = await linderPush.getPushToken()
      record.needGetNewAPI= __UI__.needGetNewAPI
      if (await pushTokenDataBase.upsert(record)) NeoPreferencesUtil.putPreferencesValue('selineRead', 'isUploadPushToken', true)
    }

    getShareLink()

  }

  async proccessContinueData(){
    if(!__UI__.onlineMode) return
    switch (__UI__.currentViewingType){
      case 'book':
        if(__UI__.currentBookData != '') {
          __zlibHomeData__.isOpening = true
          if(__UI__.currentBookData.charAt(0) == '#'){
            const item = JSON.parse(__UI__.currentBookData.replace('#', '')) as I_searchBook
            await zlibClient.getBookInfo(item.href).then((res) => {
              if (res.name != '' && res.name != undefined) {
                res.bookID = Number(item.id)
                res.image = item.image
                res.href = item.href
                __UI__.HomePageStack.removeByName('bookInfoPage')
                __UI__.HomePageStack.pushPathByName('bookInfoPage', res)
              }
              __zlibHomeData__.isOpening = false
            })
          }else{
            const item = JSON.parse(__UI__.currentBookData.replace('#', '')) as I_RecommendBook
            await zlibClient.getBookInfo(item.url).then((res) => {
              if (res.name != '' && res.name != undefined) {
                res.bookID = item.id
                res.image = item.cover
                res.href = item.url
                __UI__.HomePageStack.removeByName('bookInfoPage')
                __UI__.HomePageStack.pushPathByName('bookInfoPage', res)
              }
              __zlibHomeData__.isOpening = false
            })
          }
          setContinueState(true, 'book', __UI__.currentBookData, '')
        }
        break
      case 'bookList':
        if(__UI__.currentBookListData != ''){
          const data = JSON.parse(__UI__.currentBookListData) as I_ReadLists_Bookshelf
          __BookListData__.isOpening = true
          setTimeout(()=>{
            __UI__.indexSwiperController.changeIndex(1, true)
          }, 100)
          zlibClient.bookshelfBooks.clearData()
          await zlibClient.getBookShelfMoreInfo(data.id,1)
          animateToImmediately({ curve: curves.springMotion(0.5, 0.8) }, () => {
            __UI__.bookListPageStack.pushPath({ name: 'bookShelfPage', param: data }, false);
          })
          __BookListData__.isOpening = false
        }
        break
    }
  }

  onBackPress(): boolean | void {
    if (__zlibHomeData__.isInSearchMode) {
      XAnimation.runWithAnimation(() => __zlibHomeData__.isInSearchMode = false)
      return true
    }
    if (__zlibHomeData__.searchOrRecommend == zlibIndexShowMod.Search) {
      XAnimation.runWithAnimation(() => __zlibHomeData__.searchOrRecommend = zlibIndexShowMod.Recommend)
      return true
    }
    return false
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      if (__System__.pcMode) {
        DecorBar().zIndex(114514)
      }

      if(__CustomBackgroundData__.customBackground){
        customBackground()
      }

      Navigation(__UI__.HomePageStack) {

        Stack({alignContent: Alignment.BottomStart}){
          Swiper(__UI__.indexSwiperController){
            if(__UI__.onlineMode){
              zlibHome()
              BookList()
            }
            BookShelf()
            personal()
          }.padding({left: __System__.windowWidth > minWidth? 65 + __System__.leftRectHeight: 0})
          .indicator(false)
          .loop(false)
          .disableSwipe(true)
          .onChange((index)=>{
            this.currentPage = index
            if (index==1) {
              if (__UI__.onlineMode) {
                if (zlibClient.bookshelfArray.dataArray.length==0) {
                  zlibClient.getBookShelf(1)
                  zlibClient.getBookShelf(2)
                }
              }
            }
          })
          Flex({justifyContent: FlexAlign.SpaceAround, alignItems: ItemAlign.Center, direction: __System__.windowWidth > minWidth? FlexDirection.Column: FlexDirection.Row}){
            ForEach(__UI__.onlineMode? this.tabsArrayOnline: this.tabsArray, (item: [string, Resource, Resource], index: number) =>{
              Button({stateEffect: true, type: ButtonType.Normal}){
                Column({space: 2}){
                  SymbolGlyph(this.currentPage == index? item[2]: item[1]).fontSize(22).fontColor([this.currentPage == index? $r('app.color.sweet_blue'): $r('sys.color.font')])
                  Text(item[0]).fontSize(22).fontColor(this.currentPage == index? $r('app.color.sweet_blue'): $r('sys.color.font')).maxFontSize(11).minFontSize(10).maxLines(1)
                }
              }.backgroundColor(Color.Transparent).opacity(0.9)
              .size({width: '100%', height: '100%'})
              .borderRadius(10)
              .clickEffect({level: ClickEffectLevel.LIGHT, scale: 0.9})
              .onClick(()=>{
                this.currentPage = index
                __UI__.indexSwiperController.changeIndex(index, true)
              })
            })

          }
          .backgroundColor(__System__.windowWidth > minWidth && !__CustomBackgroundData__.customBackground? Color.Transparent: $r('app.color.start_window_background_blur')).backdropBlur(__System__.windowWidth > minWidth? 65 + __System__.bottomRectHeight: 100)
          .width(__System__.windowWidth > minWidth ? 65 + __System__.leftRectHeight : '100%')
          .height(__System__.windowWidth > minWidth ? '100%' : 65 + __System__.bottomRectHeight * 0.8)
          .padding({bottom: Math.max(__System__.bottomRectHeight * 0.8, 5), top: __System__.windowWidth > minWidth? __System__.topRectHeight: 0, left: __System__.windowWidth > minWidth? __System__.leftRectHeight: 5})
          .transition(XAnimation.getAnimation(__System__.windowWidth > minWidth? 'left': 'bottom'))
        }


      }
      .hideTitleBar(true)
      .hideToolBar(true)
      .size({ width: '100%', height: '100%' })
      .backgroundColor(__CustomBackgroundData__.customBackground? Color.Transparent: $r('sys.color.comp_background_gray'))
      .navBarWidthRange([400, 1200])
      .navBarWidth('1100')
      .mode(__UI__.isInReader ? NavigationMode.Stack : __System__.windowWidth > minWidth? NavigationMode.Split: NavigationMode.Stack)
      .onNavigationModeChange((mode) => {
        if (__UI__.isInReader) {
          return
        }
        if (mode == NavigationMode.Split) {
          __UI__.HomePageStack.clear(true)
          __UI__.HomePageStack.pushPathByName('emptyPage', false)
        }
        if (mode == NavigationMode.Stack) {
          __UI__.HomePageStack.removeByName('emptyPage')
        }
      })
    }

  }
}
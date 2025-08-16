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

import { globlContext, globlUIContext } from '../../entryability/EntryAbility';
import { linderPixelMap } from '../datas/classes/LPixelMap';
import { minWidth, __DataBase__, __System__, __UI__, __User__ } from '../datas/classes/ShareDatas';
import { zlibClient } from '../datas/classes/zlib';
import NeoPreferencesUtil from '../datas/classes/XPreferencesUtil'
import { personal } from './personal/personal';
import { zlibHome } from './zlibHome/zlibHome';
import { linderDataBaseManger } from '../datas/classes/LDataBaseManager';
import { zlibHaveDownloadTable } from '../datas/commons/zlibHaveDownloadTable';
import { zlibDownloadHistory } from './zlibDownloadHistory/zlibDownloadHistory';
import { XAnimation } from '../datas/classes/XAnimation';
import { zlibIndexShowMod } from '../datas/enums/zlibIndexShowMod';
import { DecorBar } from './DecorBar';
import { bookShelf } from './bookShelf/bookShelf';


@Entry
@ComponentV2
struct Index {
  private tabsArray: [string, Resource, Resource][] = [
    ['Zlibrary', $r('sys.symbol.book'), $r('sys.symbol.book_open_fill')],
    ['书单', $r('sys.symbol.list_bullet'), $r('sys.symbol.list_bullet')],
    ['历史记录', $r('sys.symbol.clock'), $r('sys.symbol.clock_fill')],
    ['我的', $r('sys.symbol.person'), $r('sys.symbol.person_fill')]
  ]

  @Local currentPage: number = 0

  private swiperController = new SwiperController()

  async aboutToAppear(): Promise<void> {
    console.log(`FUCK${zlibClient.recommendBooksArray.totalCount()}`)

    __DataBase__.baseStore = await linderDataBaseManger.createRelationalStoreDataBase(globlContext, {
      dataBaseName: 'selineRead',
    })

    linderDataBaseManger.createTableForRelationDataBase(__DataBase__.baseStore, 'zlibHaveDownload',
      zlibHaveDownloadTable,3)

    __User__.avatar = linderPixelMap.ISHaveAvatar(globlContext)

    __User__.isLoginZlib = NeoPreferencesUtil.getPreferencesValue("selineRead", 'isLoginZlib', false) as boolean

    zlibClient.base_url =
      NeoPreferencesUtil.getPreferencesValue("selineRead", 'zlibUrl', 'https://zh.zlibraryd.ru') as string
    zlibClient.baseApi_url = zlibClient.base_url + '/papi'
    if (__User__.isLoginZlib) {
      __User__.zlibAccount = NeoPreferencesUtil.getPreferencesValue("selineRead", 'zlibAccount', '') as string
      __User__.zlibPassword = NeoPreferencesUtil.getPreferencesValue("selineRead", 'zlibPassword', '') as string
      zlibClient.cookie = NeoPreferencesUtil.getPreferencesValue('selineRead', "zlibCookie", '') as string
    }

    await zlibClient.refreshUrl().then(async () => {
      zlibClient.getRecommendBooks(1)
 /*     zlibClient.getBookShelf(1)*/
    })

  }

  tabIconChange(index: number): ResourceStr {
    if (index == 0) {
      return $r('app.media.zlibsvg')
    } else if (index == 1) {
      return $r('app.media.bookshelf')
    } else if (index == 2) {
      return $r('sys.media.ohos_ic_public_clock')
    } else {
      return $r('sys.media.person_badge_waveform')
    }
  }

  onBackPress(): boolean | void {
    if (__UI__.isInSearchMode) {
      XAnimation.runWithAnimation(() => __UI__.isInSearchMode = false)
      return true
    }
    if (__UI__.searchOrRecommend == zlibIndexShowMod.Search) {
      XAnimation.runWithAnimation(() => __UI__.searchOrRecommend = zlibIndexShowMod.Recommend)
      return true
    }
    return false
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      if (__System__.pcMode) {
        DecorBar().zIndex(114514)
      }

      Navigation(__UI__.indexPageStack) {

        Stack({alignContent: Alignment.BottomStart}){
          Swiper(this.swiperController){
            zlibHome()
            bookShelf()
            zlibDownloadHistory()
            personal()
          }.padding({left: __System__.windowWidth > minWidth? 65 + __System__.leftRectHeight: 0})
          .indicator(false)
          .loop(false)
          .onChange((index)=>{
            this.currentPage = index
            zlibClient.localDownloadHistoryArray.clearData()
            if (index == 3 && __User__.isLoginZlib) {
              zlibClient.getUserInfo()
            } else if (index == 2) {
              zlibClient.getLocalDownloadHistory()
            }
          })
          Flex({justifyContent: FlexAlign.SpaceAround, alignItems: ItemAlign.Center, direction: __System__.windowWidth > minWidth? FlexDirection.Column: FlexDirection.Row}){
            ForEach(this.tabsArray, (item: [string, Resource, Resource], index: number) =>{
              Button({stateEffect: true, type: ButtonType.Normal}){
                Column({space: 2}){
                  SymbolGlyph(this.currentPage == index? item[2]: item[1]).fontSize(22).fontColor([this.currentPage == index? $r('app.color.sweet_blue'): $r('sys.color.font')])
                  Text(item[0]).fontSize(22).fontColor(this.currentPage == index? $r('app.color.sweet_blue'): $r('sys.color.font')).maxFontSize(11).minFontSize(10).maxLines(1)
                }
              }.backgroundColor(Color.Transparent).opacity(0.9)
              .padding(10)
              .borderRadius(10)
              .clickEffect({level: ClickEffectLevel.LIGHT, scale: 0.9})
              .onClick(()=>{
                this.currentPage = index
                this.swiperController.changeIndex(index, true)
              })
            })

          }
          .backgroundColor($r('app.color.start_window_background_blur')).backdropBlur(__System__.windowWidth > minWidth? 65 + __System__.bottomRectHeight: 100)
          .width(__System__.windowWidth > minWidth ? 65 + __System__.leftRectHeight : '100%')
          .height(__System__.windowWidth > minWidth ? '100%' : undefined)
          .padding({bottom: Math.max(__System__.bottomRectHeight, 5), top: __System__.windowWidth > minWidth? __System__.topRectHeight: 0, left: __System__.windowWidth > minWidth? __System__.leftRectHeight: 5})
        }


      }
      .hideTitleBar(true)
      .hideToolBar(true)
      .size({ width: '100%', height: '100%' })
      .backgroundColor($r('sys.color.comp_background_gray'))
      .navBarWidthRange([550, 1200])
      .navBarWidth(800)
      .mode(__UI__.isInReader ? NavigationMode.Stack : NavigationMode.Auto)
      .onNavigationModeChange((mode) => {
        if (__UI__.isInReader) {
          return
        }
        if (mode == NavigationMode.Split) {
          __UI__.indexPageStack.clear(true)
          __UI__.indexPageStack.pushPathByName('emptyPage', false)
        }
        if (mode == NavigationMode.Stack) {
          __UI__.indexPageStack.removeByName('emptyPage')
        }
      })
    }

  }
}
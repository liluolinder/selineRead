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
import { __DataBase__, __System__, __User__ } from '../datas/classes/ShareDatas';
import { zlibClient } from '../datas/classes/zlib';
import NeoPreferencesUtil from  '../datas/classes/XPreferencesUtil'
import { personal } from './personal/personal';
import { zlibHome } from './zlibHome/zlibHome';
import { linderDataBaseManger } from '../datas/classes/LDataBaseManager';
import { zlibHaveDownloadTable } from '../datas/commons/zlibHaveDownloadTable';
import { zlibDownloadHistory } from './zlibDownloadHistory/zlibDownloadHistory';


@Entry
@ComponentV2
struct Index {

  @Provider('pageStack') pageStack: NavPathStack = new NavPathStack()

  private tabsArray:string[]=[
    'Zlibrary',
    '书单',
    '历史记录',
    '我的'
  ]
  async aboutToAppear(): Promise<void> {
    console.log(`FUCK${zlibClient.recommendBooksArray.totalCount()}`)

    __DataBase__.baseStore =  await linderDataBaseManger.createRelationalStoreDataBase(globlContext,{
      dataBaseName:'selineRead',
    })

    linderDataBaseManger.createTableForRelationDataBase(__DataBase__.baseStore,'zlibHaveDownload',zlibHaveDownloadTable)

    __User__.avatar = linderPixelMap.ISHaveAvatar(globlContext)

    __User__.isLoginZlib = NeoPreferencesUtil.getPreferencesValue("selineRead",'isLoginZlib',false) as boolean

    zlibClient.base_url =NeoPreferencesUtil.getPreferencesValue("selineRead",'zlibUrl','https://zh.zlibraryd.ru') as string
    zlibClient.baseApi_url = zlibClient.base_url + '/papi'
    if ( __User__.isLoginZlib)
    {
      __User__.zlibAccount = NeoPreferencesUtil.getPreferencesValue("selineRead",'zlibAccount','') as string
      __User__.zlibPassword = NeoPreferencesUtil.getPreferencesValue("selineRead",'zlibPassword','') as string
      zlibClient.cookie = NeoPreferencesUtil.getPreferencesValue('selineRead', "zlibCookie",'')as string
    }

    await zlibClient.refreshUrl().then(async ()=>{
      zlibClient.getRecommendBooks(1)
    })

  }



  tabIconChange(index:number):ResourceStr
  {
    if (index==0) {
      return $r('app.media.zlibsvg')
    }else if(index==1)
    {
      return $r('app.media.bookshelf')
    }else if(index==2)
    {
      return $r('sys.media.ohos_ic_public_clock')
    }
    else {
      return $r('sys.media.person_badge_waveform')
    }
  }

  build() {

      Navigation(this.pageStack) {

        Tabs(){
          ForEach(this.tabsArray,(item:string,index:number)=>{
            TabContent()
            {
              if (index==0) {
                zlibHome()
              }
              else if (index==2)
              {
                zlibDownloadHistory()
              }
              else if (index==3)
              {
                personal()
              }
            }.tabBar({text:item,icon:this.tabIconChange(index)})
          })
        }
        .scrollable(false)
        .barWidth(__System__.currentBreakpoint === 'lg' ? 96 : '100%')
        .barHeight(__System__.currentBreakpoint === 'lg' ? '50%' :  76)
        .vertical(__System__.currentBreakpoint === 'lg')
        .barPosition(__System__.currentBreakpoint === 'lg' ? BarPosition.Start : BarPosition.End)
        .size({width:'100%', height:'100%'})
        .onAnimationStart((index: number, targetIndex: number, event: TabsAnimationEvent) => {
          if (index==2)
          {
            zlibClient.localDownloadHistoryArray.clearData()
          }
          if (targetIndex == 3 && __User__.isLoginZlib) {
            zlibClient.getUserDownloadLimit()
          }else if (targetIndex == 2) {
            zlibClient.getLocalDownloadHistory()
          }
        })

      }.padding({top:globlUIContext.px2vp(__System__.topRectHeight)})
      .hideTitleBar(true)
      .hideToolBar(true)
      .mode(NavigationMode.Stack)
      .size({width:'100%', height:'100%'})
      .backgroundColor($r('sys.color.comp_background_gray'))

  }
}
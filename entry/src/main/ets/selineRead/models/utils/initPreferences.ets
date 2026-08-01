import { XAnimation, XContext, XPreferencesManager } from "commonpackage";
import { __Setting__, __ZlibUser__ } from "../../commons/shareDatas";
import { __Home__ } from "../../pages/zlibrary/Home/Home";
import { I_SearchHistory } from "../interfaces/I_SearchHistory";
import { motion } from "@kit.MultimodalAwarenessKit";

export async function initPreferences() {
  console.log(`开始读取首选项`)
  __ZlibUser__.base_url = XPreferencesManager.getPreferencesValue("selineRead", "zlibBaseUrl", 'https://zh.ssl101.ru/') as string

  __ZlibUser__.urlType = XPreferencesManager.getPreferencesValue("selineRead", "urlType", 1) as number

  __Home__.showType = XPreferencesManager.getPreferencesValue('selineRead', "showType", 0) as number

  __ZlibUser__.zlibClient.setZlibUrl(__ZlibUser__.base_url)

  __Setting__.webdavServerEnabled = XPreferencesManager.getPreferencesValue("selineRead","webdavServerEnabled",false) as boolean

  __Setting__.webdavPort = XPreferencesManager.getPreferencesValue("selineRead","webdavPort",8088) as number

  __Setting__.webdavAccount = XPreferencesManager.getPreferencesValue("selineRead","webdavAccount",'admin') as string
  __Setting__.webdavPassword = XPreferencesManager.getPreferencesValue("selineRead","webdavPassword",'admin') as string

  __Setting__.bookShelfClickOpenWay = XPreferencesManager.getPreferencesValue('selineRead', "bookShelfClickOpenWay", 0) as number
  __Setting__.overrideConflictFile = XPreferencesManager.getPreferencesValue("selineRead", "overrideConflictFile", true) as boolean
  __Setting__.shareAfterDownload = XPreferencesManager.getPreferencesValue("selineRead", "shareAfterDownload", true) as boolean
  __Setting__.needPerceptiveGrip = XPreferencesManager.getPreferencesValue("selineRead", "needPerceptiveGrip", false) as boolean
  __Setting__.needDlpAntiPeep = XPreferencesManager.getPreferencesValue("selineRead", "needDlpAntiPeep", false) as boolean

  __Setting__.autoRefreshUrl = XPreferencesManager.getPreferencesValue("selineRead", "autoRefreshUrl", true) as boolean

  if (__Setting__.needPerceptiveGrip) {
    if(canIUse("SystemCapability.MultimodalAwareness.Motion") ){
      try {
        motion.on('holdingHandChanged', (state)=>{
          console.log('testTAG', state)
          XAnimation.runWithAnimation(()=> __Setting__.isLeftHand = state == motion.HoldingHandStatus.LEFT_HAND_HELD)
        })
      }catch{}
    }
  }

  __ZlibUser__.account = XPreferencesManager.getPreferencesValue("selineRead", "zlibAccount", '') as string
  __ZlibUser__.password = XPreferencesManager.getPreferencesValue("selineRead", "zlibPassword", '') as string
  __ZlibUser__.cookie = XPreferencesManager.getPreferencesValue("selineRead", "zlibCookie", '') as string
  const searchHistoryStr = XPreferencesManager.getPreferencesValue("selineRead", 'zlibSearchHistory', '') as string
  if (searchHistoryStr != '') {
    __Home__.searchHistory = JSON.parse(searchHistoryStr) as I_SearchHistory[]
  }



  console.log(`读取首选项结束`)
}

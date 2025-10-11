import {
  AbilityConstant,
  common,
  Configuration,
  ConfigurationConstant,
  Context,
  UIAbility,
  Want
} from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { notificationManager } from '@kit.NotificationKit';
import { BusinessError } from '@kit.BasicServicesKit';
import {
  __CustomBackgroundData__,
  __DataBase__,
  __System__,
  __UI__,
  __User__
} from '../zlibForOHOS/datas/classes/ShareDatas';
import NeoPreferencesUtil from '../zlibForOHOS/datas/classes/XPreferencesUtil'
import WindowsUtil from '../zlibForOHOS/utils/WindowsUtil';
import { zlibClient } from '../zlibForOHOS/datas/classes/zlib';
import { JSON } from '@kit.ArkTS';
import { addLog, getShareLink } from '../zlibForOHOS/utils/ToolsUtil';
import { XAnimation } from '../zlibForOHOS/datas/classes/XAnimation';
import { I_SearchHistory } from '../zlibForOHOS/datas/interfaces/I_SearchHistory';
import { XContext } from '../zlibForOHOS/datas/classes/XContext';

const DOMAIN = 0x0000;

export let globalContext: Context

export let globalUIContext: UIContext

export let globalUIAbilityContext: common.UIAbilityContext

export default class EntryAbility extends UIAbility {
  async onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): Promise<void> {
    globalUIAbilityContext = this.context as common.UIAbilityContext
    this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    NeoPreferencesUtil.localPreferences(this.context, 'selineRead');
    __UI__.onlineMode = NeoPreferencesUtil.getPreferencesValue("selineRead", 'onlineMode', false) as boolean
    __UI__.needGetNewAPI = NeoPreferencesUtil.getPreferencesValue("selineRead", 'needGetNewAPI', false) as boolean
    zlibClient.base_url =
      NeoPreferencesUtil.getPreferencesValue("selineRead", 'zlibUrl', '') as string
    zlibClient.baseApi_url = zlibClient.base_url + '/papi'
    zlibClient.autoShare = NeoPreferencesUtil.getPreferencesValue("selineRead", 'autoShare', true) as boolean
    __UI__.shareBookText = NeoPreferencesUtil.getPreferencesValue("selineRead", 'shareBookText', '{userName}向你分享一本好书,复制整条消息，打开Seline Read查看吧{link}') as string
    const searchHistoryStr = NeoPreferencesUtil.getPreferencesValue("selineRead", 'searchHistory', '') as string

    if (searchHistoryStr != '') {
      zlibClient.searchHistoryArray = JSON.parse(searchHistoryStr) as I_SearchHistory[]
    }

    if (__User__.isLoginZlib) {
      __User__.zlibAccount = NeoPreferencesUtil.getPreferencesValue("selineRead", 'zlibAccount', '') as string
      __User__.zlibPassword = NeoPreferencesUtil.getPreferencesValue("selineRead", 'zlibPassword', '') as string
      zlibClient.cookie = NeoPreferencesUtil.getPreferencesValue('selineRead', "zlibCookie", '') as string
    }
    addLog("读取首选项", `Cookie${zlibClient.cookie}`)
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');
    this.proccessContinueData(want, launchParam)
    const context = this.context as common.UIAbilityContext
    context.setMissionContinueState(1)

    const newAPI = want.parameters?.["newAPI"];
    if (newAPI && newAPI != '') {
      if (!__UI__.onlineMode) {
        XAnimation.runWithAnimation(() => __UI__.onlineMode = true)
        NeoPreferencesUtil.putPreferencesValue("selineRead", 'onlineMode', true)
      }
      let temp = newAPI.toString()
      addLog('setAPIFromNotification', `获取通知API${newAPI}`)
      zlibClient.base_url = temp
      zlibClient.baseApi_url = temp + '/papi'
      NeoPreferencesUtil.putPreferencesValue("selineRead", 'zlibUrl', temp)
    }

  }

  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    const newAPI = want.parameters?.["newAPI"];
    if (newAPI && newAPI != '') {
      if (!__UI__.onlineMode) {
        XAnimation.runWithAnimation(() => __UI__.onlineMode = true)
        NeoPreferencesUtil.putPreferencesValue("selineRead", 'onlineMode', true)
      }
      let temp = newAPI.toString()
      addLog('setAPIFromNotification', `获取通知API${newAPI}`)
      XContext.toast('更新成功',2000)
      zlibClient.base_url = temp
      zlibClient.baseApi_url = temp + '/papi'
      NeoPreferencesUtil.putPreferencesValue("selineRead", 'zlibUrl', temp)
      zlibClient.recommendBooksArray.clearData()
      zlibClient.bookshelfArray.clearData()
      zlibClient.refreshUrl().then(async () => {
        zlibClient.getRecommendBooks(1)
        zlibClient.getBookShelf(1)
      })
    }

    this.proccessContinueData(want, launchParam)
    const context = this.context as common.UIAbilityContext
    context.setMissionContinueState(1)
  }

  proccessContinueData(want: Want, launchParam: AbilityConstant.LaunchParam) {
    if (launchParam.launchReason == AbilityConstant.LaunchReason.CONTINUATION) {
      if (want.parameters != undefined) {
        addLog('proccessContinueData', `成功获取接续信息：${want.parameters.data.toString()}`)
        try {
          const data = JSON.parse(want.parameters.data.toString()) as Record<string, string>
          __UI__.currentViewingType = data.currentViewingType as 'book' | 'bookList' | 'home'
          __UI__.currentBookData = data.currentBookData
          __UI__.currentBookListData = data.currentBookListData
        } catch {
        }
      }
    }
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onDestroy');
  }

  async onWindowStageCreate(windowStage: window.WindowStage): Promise<void> {


    // Main window is created, set main page for this ability
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageCreate');
    windowStage.loadContent('zlibForOHOS/pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      WindowsUtil.initWindow(this.context)
      hilog.info(DOMAIN, 'testTag', 'Succeeded in loading the content.');
      globalUIContext = windowStage.getMainWindowSync().getUIContext()
      globalContext = globalUIContext.getHostContext() as common.UIAbilityContext
      XContext.init(globalUIContext)


    });

    notificationManager.isNotificationEnabled().then((data: boolean) => {
      console.log("isNotificationEnabled success, data: " + JSON.stringify(data));
      if (!data) {
        notificationManager.requestEnableNotification(globalContext as common.UIAbilityContext).then(() => {
          console.log(`[ANS] requestEnableNotification success`);
        }).catch((err: BusinessError) => {
          if (1600004 == err.code) {
            console.log(`[ANS] requestEnableNotification refused, code is ${err.code}, message is ${err.message}`);
          } else {
            console.log(`[ANS] requestEnableNotification failed, code is ${err.code}, message is ${err.message}`);
          }
        });
      }
    }).catch((err: BusinessError) => {
      console.log(`isNotificationEnabled fail, code is ${err.code}, message is ${err.message}`);
    });

  }

  onWindowStageRestore(windowStage: window.WindowStage): void {
    // Main window is created, set main page for this ability
    hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onWindowStageCreate');
    windowStage.loadContent('zlibForOHOS/pages/Index',  (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      WindowsUtil.initWindow(this.context)
      hilog.info(DOMAIN, 'testTag', 'Succeeded in loading the content.');
      globalUIContext = windowStage.getMainWindowSync().getUIContext()
      globalContext = globalUIContext.getHostContext() as common.UIAbilityContext

    });
  }

  onWindowStageDestroy(): void {
    // Main window is destroyed, release UI related resources
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onConfigurationUpdate(newConfig: Configuration): void {
    __UI__.currentColorMode = newConfig.colorMode || ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET
  }

  onForeground(): void {
    notificationManager.setBadgeNumber(0).then(() => {
      addLog('清除通知角标','成功')
    }).catch((err: BusinessError) => {
      addLog('清除通知角标',`失败Code is ${err.code}, message is ${err.message}`,true)
    });
    // Ability has brought to foreground
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onForeground');
    setTimeout(()=>{
      getShareLink()
    }, 500)
  }

  onBackground(): void {
    // Ability has back to background
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onBackground');
  }

  onContinue(wantParam: Record<string, Object>) {
    let continueInput: string = JSON.stringify({
      currentViewingType: __UI__.currentViewingType,
      currentBookData: __UI__.currentBookData,
      currentBookListData: __UI__.currentBookListData
    })
    if (continueInput) {
      wantParam["data"] = continueInput;
      addLog('onContinue', `即将发起接续：${continueInput}`)
      return AbilityConstant.OnContinueResult.AGREE;
    } else {
      return AbilityConstant.OnContinueResult.REJECT
    }
  }
}
import { AbilityConstant, common,
  Configuration,
  ConfigurationConstant, Context, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { display, window } from '@kit.ArkUI';
import { notificationManager } from '@kit.NotificationKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { __DataBase__, __System__, __UI__, __User__ } from '../zlibForOHOS/datas/classes/ShareDatas';
import  NeoPreferencesUtil from '../zlibForOHOS/datas/classes/XPreferencesUtil'
import WindowsUtil from '../zlibForOHOS/utils/WindowsUtil';
import { linderDataBaseManger } from '../zlibForOHOS/datas/classes/LDataBaseManager';
import { zlibHaveDownloadTable } from '../zlibForOHOS/datas/commons/zlibHaveDownloadTable';
import { linderPixelMap } from '../zlibForOHOS/datas/classes/LPixelMap';
import { zlibClient } from '../zlibForOHOS/datas/classes/zlib';

const DOMAIN = 0x0000;

export let globlContext:Context
export let globlUIContext:UIContext

export default class EntryAbility extends UIAbility {

  private windowObj?: window.Window
  private curBp: string = ''

  async onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): Promise<void> {
    this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    NeoPreferencesUtil.localPreferences(this.context, 'selineRead');
    __UI__.onlineMode = NeoPreferencesUtil.getPreferencesValue("selineRead", 'onlineMode', false) as boolean
    zlibClient.base_url =
      NeoPreferencesUtil.getPreferencesValue("selineRead", 'zlibUrl', 'https://zh.zlibraryd.ru') as string
    zlibClient.baseApi_url = zlibClient.base_url + '/papi'

    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onDestroy');
  }

  async onWindowStageCreate(windowStage: window.WindowStage): Promise<void> {


    // Main window is created, set main page for this ability
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageCreate');
    windowStage.loadContent('zlibForOHOS/pages/Index',  (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      WindowsUtil.initWindow(this.context)
      hilog.info(DOMAIN, 'testTag', 'Succeeded in loading the content.');
      globlUIContext = windowStage.getMainWindowSync().getUIContext()
      globlContext =  globlUIContext.getHostContext() as common.UIAbilityContext


    });

    notificationManager.isNotificationEnabled().then((data: boolean) => {
      console.log( "isNotificationEnabled success, data: " + JSON.stringify(data));
      if(!data){
        notificationManager.requestEnableNotification(globlContext as common.UIAbilityContext).then(() => {
          console.log( `[ANS] requestEnableNotification success`);
        }).catch((err : BusinessError) => {
          if(1600004 == err.code){
            console.log(`[ANS] requestEnableNotification refused, code is ${err.code}, message is ${err.message}`);
          } else {
            console.log(`[ANS] requestEnableNotification failed, code is ${err.code}, message is ${err.message}`);
          }
        });
      }
    }).catch((err : BusinessError) => {
      console.log( `isNotificationEnabled fail, code is ${err.code}, message is ${err.message}`);
    });

  }
  onWindowStageDestroy(): void {
    // Main window is destroyed, release UI related resources
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onConfigurationUpdate(newConfig: Configuration): void {
    __UI__.currentColorMode = newConfig.colorMode || 0
  }

  onForeground(): void {
    // Ability has brought to foreground
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    // Ability has back to background
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onBackground');
  }
}
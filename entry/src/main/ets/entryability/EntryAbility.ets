import { AbilityConstant, Configuration, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { XContext, XPreferencesManager } from 'commonpackage';
import WindowsUtil from '../selineRead/models/classes/WindowsUtil';
import { __System__, __ZlibUser__ } from '../selineRead/commons/shareDatas';
import { RelationStoreManager } from '../selineRead/models/classes/DataBase';
import { initPreferences } from '../selineRead/models/utils/initPreferences';
import { DownloadManager } from '@hadss/super_fast_file_trans';
import { notificationManager } from '@kit.NotificationKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { deleteDownloadCache } from '../selineRead/models/utils/ClearDownloadCache';

const DOMAIN = 0x0000;

export default class EntryAbility extends UIAbility {
  async onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): Promise<void> {
    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
      XPreferencesManager.localPreferences(this.context, 'selineRead');
      initPreferences()
      RelationStoreManager.CreateDataBase(this.context).then((store)=>{
        __ZlibUser__.dataBase = store
      })
      __ZlibUser__.downloadManager =  DownloadManager.getInstance();
      deleteDownloadCache()
      await  __ZlibUser__.downloadManager.init(this.context);
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to set colorMode. Cause: %{public}s', JSON.stringify(err));
    }
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');
  }

  async onDestroy(): Promise<void> {
    if (__ZlibUser__.downloadManager) {
      await __ZlibUser__.downloadManager.cleanAll(this.context);
    }
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // Main window is created, set main page for this ability
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageCreate');

    windowStage.loadContent('selineRead/pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, 'testTag', 'Succeeded in loading the content.');
      try {
        notificationManager.isNotificationEnabled().then((data: boolean) => {
          console.log("isNotificationEnabled success, data: " + JSON.stringify(data));
          if (!data) {
            notificationManager.requestEnableNotification(XContext.getAbilityContext()).then(() => {
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
        XContext.init(windowStage.getMainWindowSync().getUIContext())
        WindowsUtil.initWindow(this.context)
      } catch (error) {
        console.error(`Liquid:${JSON.stringify(error)}`)
      }
    });
  }

  onWindowStageRestore(windowStage: window.WindowStage): void {
    try {
      XContext.init(windowStage.getMainWindowSync().getUIContext())
      WindowsUtil.initWindow(this.context)
    } catch (error) {
      console.error(`Liquid:${JSON.stringify(error)}`)
    }
  }

  onWindowStageDestroy(): void {
    // Main window is destroyed, release UI related resources
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    // Ability has brought to foreground
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    // Ability has back to background
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onBackground');
  }

  onConfigurationUpdate(newConfig: Configuration): void {
    __System__.currentColorMode = newConfig.colorMode ?? ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET

  }

}
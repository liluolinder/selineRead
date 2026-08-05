import { AbilityConstant, Configuration, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { XContext, XPreferencesManager } from 'commonpackage';
import WindowsUtil from '../selineRead/models/classes/WindowsUtil';
import { __Download__, __Setting__, __System__, __ZlibUser__, __HWShare__ } from '../selineRead/commons/shareDatas';
import { RelationStoreManager } from '../selineRead/models/classes/DataBase';
import { initPreferences } from '../selineRead/models/utils/initPreferences';
import { notificationManager } from '@kit.NotificationKit';
import { BusinessError, commonEventManager, emitter } from '@kit.BasicServicesKit';
import { url } from '@kit.ArkTS';
import { EventHelper } from '../selineRead/models/classes/BaseEvent';
import { ZlibBookInfoBriefArk } from 'libohos_app_cangjie_entry.zlib4cj.so';

const DOMAIN = 0x0000;

function getShareUriFromWant(want: Want) {
  if (want.uri) {
    try {
      let wantURl = url.URL.parseURL(want.uri)
      console.log(`meow:${wantURl.toString()}`)
      let hash = wantURl.params.get('hash')
      let id = wantURl.params.get('id')
      console.log(`meow:  hash:${hash}  id:${id}`)
      if (hash != null && id != null) {
        console.log(`存在hash 和 id`)
        let book = new ZlibBookInfoBriefArk(Number(id), hash)
        book.toCJ()
        __HWShare__.bookFromShare = book
        console.log(`meowmeow:  hash:${book.hash}  id:${book.id}`)
        console.log(`meow:${JSON.stringify(__HWShare__.bookFromShare)}`)
        EventHelper.emitterPublish('getNewBook')
      }
    } catch (error) {
      console.log(error)
    }
  }
}

export default class EntryAbility extends UIAbility {
  async onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): Promise<void> {
    getShareUriFromWant(want)
    try {
      XPreferencesManager.localPreferences(this.context, 'selineRead');
      initPreferences()
      RelationStoreManager.CreateDataBase(this.context).then((store)=>{
        __ZlibUser__.dataBase = store
        try {
          RelationStoreManager.getZlibDownload(__ZlibUser__.dataBase)
        }catch (e)
        {
          console.log(`读取数据库失败${JSON.stringify(e)}`)
        }
      })
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
    __Setting__.webdavClient?.stop()
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
        WindowsUtil.initWindow(this.context, windowStage)
      } catch (error) {
      }

      __Setting__.darkModeIndex =  XPreferencesManager.getPreferencesValue('selineRead', "ColorMode", 0) as number
      let mode = ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET
      switch (__Setting__.darkModeIndex){
        case 0:
          mode = ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET
          break
        case 1:
          mode = ConfigurationConstant.ColorMode.COLOR_MODE_DARK
          break
        case 2:
          mode = ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT
          break
      }
      this.context.getApplicationContext().setColorMode(mode);

    });
  }

  onWindowStageRestore(windowStage: window.WindowStage): void {
    try {
      XContext.init(windowStage.getMainWindowSync().getUIContext())
      WindowsUtil.initWindow(this.context, windowStage)
    } catch (error) {
      console.error(`Liquid:${JSON.stringify(error)}`)
    }
  }

  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    getShareUriFromWant(want)
  }


  onConfigurationUpdate(newConfig: Configuration): void {
    __System__.currentColorMode = newConfig.colorMode ?? ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET
  }
}
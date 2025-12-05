import { UIExtensionContentSession, Want } from "@kit.AbilityKit";
import { StatusBarViewExtensionAbility } from "@kit.StatusBarExtensionKit";
import { BusinessError, commonEventManager, emitter } from "@kit.BasicServicesKit";
import { CommonEvent } from "../selineRead/models/classes/CommonEvent";
import { __StatusBar__ } from "../selineRead/pages/statusBarView/StatusBarViewEntry";
import { DownloadInfo } from "../selineRead/models/classes/DownloadInfo";


export default class StatusBarViewAbility extends StatusBarViewExtensionAbility {
  onCreate() {
    console.info(`onCreate`);
    __StatusBar__.downloadArray.clearData()
    CommonEvent.subAddDownloadProgress((res)=>{
      __StatusBar__.downloadArray.pushUnshiftData(DownloadInfo.fromInterface(res))
    })

  }

  onSessionCreate(want: Want, session: UIExtensionContentSession) {
    console.info(`onSessionCreate, want: ${want.abilityName}`);
    // pages/StatusBarPage为状态栏图标左键业务弹窗显示的页面
    session.loadContent('selineRead/pages/statusBarView/StatusBarViewEntry');
  }

  onForeground() {
    CommonEvent.sendCreateStatusBar()
    console.info(`onForeground`);
  }

  onBackground() {
    console.info(`onBackground`);
  }

  onSessionDestroy(session: UIExtensionContentSession) {
    console.info(`onSessionDestroy`);
  }

  onDestroy() {
    console.info(`onDestroy`);
  }
}
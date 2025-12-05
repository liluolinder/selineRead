import { statusBarManager } from "@kit.StatusBarExtensionKit";
import { Context } from "@kit.AbilityKit";
import { XContext } from "commonpackage";

export class StatusBarController{

  static add2StatusBar(context:Context){
    try {
      if (canIUse('SystemCapability.PCService.StatusBarManager')) {
        let iconPixelMap = XContext.getPixelMapFromResoure($r('app.media.zlib'))
        let icon: statusBarManager.StatusBarIcon = {
          white: iconPixelMap,
          black: iconPixelMap
        }

        let operation: statusBarManager.QuickOperation = {
          abilityName: "MyStatusBarViewAbility",
          title: XContext.getStringFromResource($r('app.string.EntryAbility_label')),
          height: 300,
        };

        let statusBarItem: statusBarManager.StatusBarItem = {
          icons: icon,
          quickOperation: operation,
        };

        statusBarManager.addToStatusBar(context, statusBarItem);
      }
    }catch (e){
      console.log(`调用异常:${JSON.stringify(e)}`)
    }
  }

}
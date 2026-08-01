import { bundleManager, common, wantAgent } from '@kit.AbilityKit'
import { backgroundTaskManager } from '@kit.BackgroundTasksKit'
import { BusinessError } from '@kit.BasicServicesKit';
import { XContext } from 'commonpackage';

const TAG = 'BackgroundUtil';

export class BackgroundUtil {
  public static startContinuousTask(): void {
    if (!XContext.getAbilityContext()) {
      console.error(TAG, 'meow startContinuousTask failed', `context undefined`);
      return;
    }
    let wantAgentInfo: wantAgent.WantAgentInfo = {
      wants: [
        {
          bundleName: XContext.getAbilityContext().abilityInfo.bundleName,
          abilityName: XContext.getAbilityContext().abilityInfo.name
        }
      ],
      operationType: wantAgent.OperationType.START_ABILITY,
      requestCode: 0,
      wantAgentFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG]
    };

    wantAgent.getWantAgent(wantAgentInfo).then((wantAgentObj: Object) => {
      try {
        backgroundTaskManager.startBackgroundRunning(XContext.getAbilityContext(),
          backgroundTaskManager.BackgroundMode.DATA_TRANSFER, wantAgentObj).then(() => {
          console.info('meow startBackgroundRunning succeeded');
        }).catch((error: BusinessError) => {
          console.error(`meow startBackgroundRunning failed Cause: code ${error.code}`);
        });
      } catch (error) {
        console.error(TAG, `meow startBackgroundRunning failed.message ${(error as BusinessError).message}`);
      }
    });
  }


  public static stopContinuousTask(): void {
    try {
      backgroundTaskManager.stopBackgroundRunning(XContext.getAbilityContext()).then(() => {
        console.info('stopBackgroundRunning succeeded');
      }).catch((error: BusinessError) => {
        console.error(`stopBackgroundRunning failed Cause: code ${error.code}`);
      });
    } catch (error) {
      console.error(TAG, `stopBackgroundRunning failed. message ${(error as BusinessError).message}`);
    }
  }
}



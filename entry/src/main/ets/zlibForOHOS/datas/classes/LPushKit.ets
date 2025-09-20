import { pushService } from '@kit.PushKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { UIAbility, AbilityConstant, Want } from '@kit.AbilityKit';
import { addLog } from '../../utils/ToolsUtil';

export class LPushKit{
  async getPushToken() :Promise<string>{

    try {
      return await pushService.getToken();
    } catch (err) {
      addLog('getPushToken',`获取推送Token失败，原因${JSON.stringify(err)}`,true)
      return 'error';
    }
  }
}

export let linderPush:LPushKit = new LPushKit()
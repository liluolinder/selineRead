import { dlpAntiPeep } from "@kit.DeviceSecurityKit"
import WindowsUtil from "../models/classes/WindowsUtil"

export const min_width: number = 700
export const min_split_width: number = 1100
export const user_agent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36 Edg/143.0.0.0'


 export const DlpAntiPeepCallback = async (status: dlpAntiPeep.DlpAntiPeepStatus): Promise<void> => {
  if (status === dlpAntiPeep.DlpAntiPeepStatus.PASS) { // 表示当前状态为无人窥视
  } else if (status === dlpAntiPeep.DlpAntiPeepStatus.HIDE) { // 表示有人在窥屏，应用可以进行隐私保护操作。
    try {
      const windowId = WindowsUtil.windowClass?.getWindowProperties().id
      await dlpAntiPeep.setAntiPeepMaskLayer(windowId);
    } catch (error) {
      console.error(`Failed to set AntiPeep MaskLayer. Code: ${error.code}, message: ${error.message}`);
    }
  }
}
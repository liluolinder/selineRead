import { notificationManager } from "@kit.NotificationKit";
import { BusinessError } from "@kit.BasicServicesKit";

@ObservedV2
export class LNotificationManager{

   pushNotificationWithProgress(id:number, progress: number, title: string, value: string) {
    let notificationRequest: notificationManager.NotificationRequest = {
      id:id,
      content: {
        notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
        normal: {
          title: title,
          text: value,
        }
      },
      // 构造进度条模板，name字段当前需要固定配置为downloadTemplate
      template: {
        name: 'downloadTemplate',
        data: { title: title, fileName: value, progressValue: progress }
      }
    }

    // 更新发布通知
    notificationManager.publish(notificationRequest, (err: BusinessError) => {
      if (err) {
        console.log(`Failed to update notification. Code is ${err.code}, message is ${err.message}`);
        return;
      }
      console.log('Succeeded in updating notification.');
    });
  }

  pushNotification(id:number, _title:string, _text:string, _additionalText:string = ''){

    let notificationRequest: notificationManager.NotificationRequest = {
      id: id,
      content: {
        notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT, // 普通文本类型通知
        normal: {
          title: _title,
          text: _text,
          additionalText: _additionalText == ''?undefined:_additionalText,
        }
      }
    };
    notificationManager.publish(notificationRequest, (err: BusinessError) => {
      if (err) {
        console.log( `Failed to publish notification. Code is ${err.code}, message is ${err.message}`);
        return;
      }
      console.log('Succeeded in publishing notification.');
    });
  }

}

export let linderNotificationManager:LNotificationManager = new LNotificationManager()
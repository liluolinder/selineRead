import { BusinessError, commonEventManager } from "@kit.BasicServicesKit";
import { I_DownloadInfo } from "../interfaces/I_DownloadInfo";
import call from "@ohos.telephony.call";

export class CommonEvent{

  static sendAddDownloadProgress(info:I_DownloadInfo){
    let options: commonEventManager.CommonEventPublishData = {
      data: 'addDownloadProgress',
      isOrdered:true,
      parameters:info
    };

    commonEventManager.publish('addDownloadProgress', options, (err: BusinessError) => {
      if (err) {
        console.log(`发送事件失败 Code is ${err.code}, message is ${err.message}`);
      } else {
        console.log(`发送事件成功 in publishing common event.`);
      }
    });
  }

  static subAddDownloadProgress(callback:(item:I_DownloadInfo)=>void){
    let subscriber: commonEventManager.CommonEventSubscriber | null = null;

    let subscribeInfo: commonEventManager.CommonEventSubscribeInfo = {
      events: ['addDownloadProgress'],
    };

    commonEventManager.createSubscriber(subscribeInfo, (err: BusinessError, data: commonEventManager.CommonEventSubscriber) => {
      if (err) {
        console.log(`Failed to create subscriber. Code is ${err.code}, message is ${err.message}`);
        return;
      }
      console.log(`Succeeded in creating subscriber.`);
      subscriber = data;
      // 订阅公共事件回调
      if (subscriber !== null) {
        commonEventManager.subscribe(subscriber, (err: BusinessError, data: commonEventManager.CommonEventData) => {
          if (err) {
            console.log(`Failed to subscribe common event. Code is ${err.code}, message is ${err.message}`);
            return;
          }
          callback(data.parameters as I_DownloadInfo)
          console.log(`Succeeded in subscribing, data is ${JSON.stringify(data.parameters)}`);
        })
      } else {
        console.log(`Need create subscriber`);
      }
    })
  }

  static sendCreateStatusBar(){
    let options: commonEventManager.CommonEventPublishData = {
      data: 'createStatusBar',
      isOrdered:true,
    };
    commonEventManager.publish('createStatusBar', options, (err: BusinessError) => {
      if (err) {
        console.log(`发送事件失败 Code is ${err.code}, message is ${err.message}`);
      } else {
        console.log(`发送事件成功 in publishing common event.`);
      }
    });
  }

  static subCreateStatusBar(callback:()=>void){
    let subscriber: commonEventManager.CommonEventSubscriber | null = null;

    let subscribeInfo: commonEventManager.CommonEventSubscribeInfo = {
      events: ['createStatusBar'],
    };

    commonEventManager.createSubscriber(subscribeInfo, (err: BusinessError, data: commonEventManager.CommonEventSubscriber) => {
      if (err) {
        console.log(`Failed to create subscriber. Code is ${err.code}, message is ${err.message}`);
        return;
      }
      console.log(`Succeeded in creating subscriber.`);
      subscriber = data;
      // 订阅公共事件回调
      if (subscriber !== null) {
        commonEventManager.subscribe(subscriber, (err: BusinessError, data: commonEventManager.CommonEventData) => {
          if (err) {
            console.log(`Failed to subscribe common event. Code is ${err.code}, message is ${err.message}`);
            return;
          }
          callback()

          console.log(`Succeeded in subscribing, data is ${JSON.stringify(data.parameters)}`);
        })
      } else {
        console.log(`Need create subscriber`);
      }
    })
  }
}
import { common, OpenLinkOptions, Want } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { productViewManager } from '@kit.StoreKit';
import { pasteboard } from '@kit.BasicServicesKit';
import { promptAction } from '@kit.ArkUI';
import { systemShare } from '@kit.ShareKit';
import { uniformTypeDescriptor as utd } from '@kit.ArkData';
import { fileUri } from '@kit.CoreFileKit';
import { uniformTypeDescriptor } from '@kit.ArkData';

// 拉起浏览器
export function startBrowsableAbility(context: common.UIAbilityContext, uri: string): void {
  let want: Want = {
    action: 'ohos.want.action.viewData',
    entities: ['entity.system.browsable'],
    uri: uri
  };
  context.startAbility(want)
    .then(() => {
      console.error('Start browsableAbility successfully.');
    })
    .catch((err: BusinessError) => {
      console.error(`Failed to startAbility. Code: ${err.code}, message: ${err.message}`);
    });
}

// 拉起应用市场对应的应用详情界面
export function startAppGalleryDetailAbility(context: common.UIAbilityContext, bundleName: string): void {
  try {
    let want: Want = {
      // action: 'ohos.want.action.appdetail',
      // uri: 'store://appgallery.huawei.com/app/detail?id=' + bundleName, //  bundleName为需要打开应用详情的应用的包名
      parameters: {
        bundleName: bundleName
      }
    };
    productViewManager.loadProduct(context, want, {
      onError: (error: BusinessError) => {
        //hilog.error(0, 'TAG', `loadProduct onError.code is ${error.code}, message is ${error.message}`);
      }
    })
    // context.startAbility(want).then(() => {
    //   console.info('Start Ability successfully.');
    // })
    // .catch((err: BusinessError) => {
    //   console.error(`Failed to startAbility. Code: ${err.code}, message: ${err.message}`);
    // });
  } catch (e) {
  }
}



export function startQQGroupAbility(context: common.UIAbilityContext, groupNum: number) {
  let openLinkOptions: OpenLinkOptions = {
    appLinkingOnly: false,
  };
  try {
    context.openLink('mqqapi://card/show_pslcard?src_type=internal&version=1&uin=' + groupNum +
      '&card_type=group&source=qrcode', openLinkOptions)
  } catch (paramError) {
  }
}

export function startQQPeopleAbility(context: common.UIAbilityContext, peopleNum: number) {
  let openLinkOptions: OpenLinkOptions = {
    appLinkingOnly: false,
  };
  try {
    context.openLink('mqqapi://card/show_pslcard?src_type=internal&version=1&uin='+peopleNum, openLinkOptions)
  } catch (paramError) {
  }
}

export function copyStrToPasteBoard(copyStr: string) {
  const pasteboardData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, copyStr)
  const systemPasteboard = pasteboard.getSystemPasteboard()
  systemPasteboard.setData(pasteboardData) // 将数据放入剪切板
  systemPasteboard.getData().then((data) => {
    if (data) {
    } else {
    }
  })
}



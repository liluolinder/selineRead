import { bundleManager, common, Want } from "@kit.AbilityKit";
import { BusinessError } from "@kit.BasicServicesKit";
import { WindowMode } from "@ohos.UiTest";
import { fileUri, picker } from "@kit.CoreFileKit";
import { I_AlterDialogParam } from "../interfaces/I_AlterDialogParam";

export class XContext {
    private static UIAbilityContext: common.UIAbilityContext
    private static UIContext: UIContext

    public static init(UIContext: UIContext) {
        XContext.UIContext = UIContext;
        XContext.UIAbilityContext = UIContext.getHostContext() as common.UIAbilityContext;
    }

    public static px2vp(px: number) {
        return XContext.UIContext.px2vp(px);
    }

    public static vp2px(vp: number) {
        return XContext.UIContext.vp2px(vp);
    }

    public static getContext() {
        return XContext.UIContext;
    }

    public static getAbilityContext() {
        return XContext.UIAbilityContext;
    }

    public static getStringFromResource(resource: Resource) {
        return XContext.getAbilityContext().resourceManager.getStringSync(resource.id)
    }

    public static mergeResourceStrings(...rest: ResourceStr[]): string {
        let result = '';
        rest.forEach((item) => {
            if (typeof item === 'string') {
                result = result.concat(item);
            } else {
                result = result.concat(XContext.getAbilityContext().resourceManager.getStringSync(item.id));
            }
        })
        return result;
    }

    public static getPixelMapFromResoure(source:Resource):PixelMap{
        const resManager = XContext.getAbilityContext().resourceManager;
        const drawableDesc = resManager?.getDrawableDescriptor(source.id);
        return drawableDesc?.getPixelMap();
    }

    public static getColorFromResource(resource: Resource) {
        return XContext.getAbilityContext().resourceManager.getColorSync(resource.id)
    }

    public static getFilesDir() {
        return XContext.UIAbilityContext.filesDir;
    }

    public static getCacheDir() {
        return XContext.UIAbilityContext.cacheDir;
    }

    public static getPromptAction() {
        return XContext.UIContext.getPromptAction();
    }

    public static startAbility(want:Want){
        XContext.getAbilityContext().startAbility(want)
            .then(() => {
                console.error('Start browsableAbility successfully.');
            })
            .catch((err: BusinessError) => {
                console.error(`Failed to startAbility. Code: ${err.code}, message: ${err.message}`);
            });
    }

    public static toast(msg: ResourceStr, duration: number = 1500) {
        try {
            XContext.UIContext.getPromptAction().showToast({ message: msg, duration: duration });
        } catch (error) {

        }
    }

    public static alterDialogWithTwoButton(param:I_AlterDialogParam){
       try {
           XContext.getContext().showAlertDialog(
               {
                   title: param.title,
                   subtitle: param.subtitle,
                   message:param.message,
                   autoCancel: param.autoCancel??false,
                   alignment: param.alignment,
                   buttonDirection: param.buttonDirection,
                   primaryButton: {
                       value: '取消',
                       action: () => {
                           param.cancelCallBack()
                       }
                   },
                   secondaryButton: {
                       enabled: true,
                       defaultFocus: true,
                       style: DialogButtonStyle.HIGHLIGHT,
                       value: '确定',
                       action: () => {
                           param.confirmCallBack()
                       }
                   }
               }
           )
       }catch (e){}
    }


    public static async getDownloadFolderPath(): Promise<string> {
        const documentViewPicker = new picker.DocumentViewPicker()
        let documentSaveResult = await documentViewPicker.save({ pickerMode: picker.DocumentPickerMode.DOWNLOAD })
        console.log(documentSaveResult[0])
        console.log(`${new fileUri.FileUri(documentSaveResult[0])}`)
        console.log(`${new fileUri.FileUri(documentSaveResult[0]).path}`)
        return new fileUri.FileUri(documentSaveResult[0]).path + '/'
    }

}
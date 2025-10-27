import image from "@ohos.multimedia.image";
import { ConfigurationConstant } from "@kit.AbilityKit";
import { XContext, XPreferencesManager } from "commonpackage";
import { __System__ } from "../../main/ets/commons/shareDatas";

@ObservedV2
export class CustomBackgroundData{

    @Trace enableCustomBackground: boolean = false
    @Trace advanceMaterial: boolean = true
    @Trace customBackgroundFollowColorMode: boolean = false
    @Trace flash: boolean = false
}

export let __CustomBackgroundData__ = new CustomBackgroundData()

export function initCustomBackground(){
    __CustomBackgroundData__.enableCustomBackground = XPreferencesManager.getPreferencesValue('pilipala_settings', 'enableCustomBackground', false) as boolean
    __CustomBackgroundData__.customBackgroundFollowColorMode = XPreferencesManager.getPreferencesValue('pilipala_settings', 'customBackgroundFollowColorMode', false) as boolean
    __CustomBackgroundData__.advanceMaterial = XPreferencesManager.getPreferencesValue('pilipala_settings', 'advanceMaterial', true) as boolean
}

@ComponentV2
export struct CustomBackground{
    @Local private customBackgroundData: CustomBackgroundData = __CustomBackgroundData__
    @Local private pixelMap: image.PixelMap|undefined
    @Local private imageOpacity: number = 0

    @Monitor('customBackgroundData.flash')
    async aboutToAppear(){
        animateToImmediately({duration: 300, curve: Curve.Ease}, ()=> this.imageOpacity = 0)
        this.pixelMap = await image.createImageSource(this.customBackgroundData.customBackgroundFollowColorMode && __System__.currentColorMode == ConfigurationConstant.ColorMode.COLOR_MODE_DARK? XContext.getFilesDir() + '/background_dark': XContext.getFilesDir() + '/background').createPixelMap()
    }

    build() {
        if(this.customBackgroundData.enableCustomBackground){
            Image(this.pixelMap)
                .opacity(this.imageOpacity)
                .objectFit(ImageFit.Cover)
                .autoResize(true)
                .draggable(false)
                .onComplete(()=>{
                    animateToImmediately({duration: 300, curve: Curve.Ease}, ()=> this.imageOpacity = 1)
                })
        }
    }
}
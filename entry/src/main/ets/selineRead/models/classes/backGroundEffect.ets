import { ConfigurationConstant } from "@kit.AbilityKit"
import { __UI__, __System__ } from "../../commons/shareDatas"
import { __CustomBackgroundData__ } from "../../components/CustomBackground"

@ObservedV2
class _backgroundBlurModifier implements AttributeModifier<CommonAttribute> {

    applyNormalAttribute(instance: CommonAttribute): void {

        instance
            .backgroundEffect({
                radius: __CustomBackgroundData__.enableCustomBackground && __UI__.advanceMaterial ? 100 : null
            })
            .backgroundColor('#' + (__CustomBackgroundData__.enableCustomBackground && __UI__.advanceMaterial ? 'b2': 'ff') + (__System__.currentColorMode == ConfigurationConstant.ColorMode.COLOR_MODE_DARK? '292929': 'e7e9ec'))
            .useEffect(true, EffectType.WINDOW_EFFECT)
    }
}

export let backgroundBlurModifier: _backgroundBlurModifier = new _backgroundBlurModifier()

@ObservedV2
class _backgroundBlurModifierAuto implements AttributeModifier<CommonAttribute> {

    applyNormalAttribute(instance: CommonAttribute): void {
        instance
            .backgroundEffect({
                radius: __CustomBackgroundData__.enableCustomBackground && __UI__.advanceMaterial && __UI__.isSplitLayout ? 100 : null,
                color: '#' + (__CustomBackgroundData__.enableCustomBackground && __UI__.advanceMaterial ? 'b2': 'ff') + (__System__.currentColorMode == ConfigurationConstant.ColorMode.COLOR_MODE_DARK? '292929': 'e7e9ec')
            })
            .useEffect(true, EffectType.WINDOW_EFFECT)
    }
}

export let backgroundBlurModifierAuto: _backgroundBlurModifierAuto = new _backgroundBlurModifierAuto()


import { ConfigurationConstant } from "@kit.AbilityKit"
import { __CustomBackgroundData__, __System__, __UI__ } from "./ShareDatas"

@ObservedV2
class _backgroundBlurModifier implements AttributeModifier<CommonAttribute> {

    applyNormalAttribute(instance: CommonAttribute): void {

        instance
            .backgroundEffect({
                radius: __CustomBackgroundData__.enableCustomBackground && __CustomBackgroundData__.advanceMaterial ? 100 : null
            })
            .backgroundColor('#' + (__CustomBackgroundData__.enableCustomBackground && __CustomBackgroundData__.advanceMaterial ? 'b2': 'ff') + (__System__.currentColorMode == ConfigurationConstant.ColorMode.COLOR_MODE_DARK? '292929': 'e7e9ec'))
            .useEffect(true, EffectType.WINDOW_EFFECT)
    }
}

export let backgroundBlurModifier: _backgroundBlurModifier = new _backgroundBlurModifier()

@ObservedV2
class _backgroundBlurModifierAuto implements AttributeModifier<CommonAttribute> {

    applyNormalAttribute(instance: CommonAttribute): void {
        instance
            .backgroundEffect({
                radius: __CustomBackgroundData__.enableCustomBackground && __CustomBackgroundData__.advanceMaterial && __UI__.isSplitLayout ? 100 : null,
                color: __UI__.isSplitLayout && __CustomBackgroundData__.enableCustomBackground && __CustomBackgroundData__.advanceMaterial? '#' + (__CustomBackgroundData__.enableCustomBackground && __CustomBackgroundData__.advanceMaterial ? 'b2': 'ff') + (__System__.currentColorMode == ConfigurationConstant.ColorMode.COLOR_MODE_DARK? '292929': 'e7e9ec'): Color.Transparent
            })
            .backgroundColor(__UI__.isSplitLayout && __CustomBackgroundData__.enableCustomBackground && __CustomBackgroundData__.advanceMaterial? Color.Transparent: '#' + (__System__.currentColorMode == ConfigurationConstant.ColorMode.COLOR_MODE_DARK? '292929': 'e7e9ec'))
            .useEffect(true, EffectType.WINDOW_EFFECT)
    }
}

export let backgroundBlurModifierAuto: _backgroundBlurModifierAuto = new _backgroundBlurModifierAuto()


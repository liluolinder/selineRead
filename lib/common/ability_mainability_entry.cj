@NonProduct
features {}
package ohos_app_cangjie_entry

// CJMP Tools manages this Ability entry and lifecycle file.
// Use main.cj for feature development; modify this file only for Ability customization.

internal import ohos.ability.UIAbility
internal import ohos.ability.AbilityStage
internal import ohos.ability.LaunchParam
internal import ohos.ability.LaunchReason
internal import ohos.ability.Want
internal import ohos.base.AppLog
internal import ohos.window.WindowStage
import ohos_app_cangjie_entry.model.*
import ohos_app_cangjie_entry.model.*

let ENTRYABILITY_REGISTER_RESULT = UIAbility.registerCreator("EntryAbility", {=> MainAbility()})
let ENTRY_STAGE_REGISTER_RESULT = AbilityStage.registerCreator("entry", {=> MyAbilityStage()})

class MyAbilityStage <: AbilityStage {
    public override func onCreate(): Unit {
        AppLog.info("MyAbilityStage onCreated.")
    }
}

public func loadMainContent(windowStage: WindowStage): Unit {
    windowStage.loadContent("EntryView")
}

class MainAbility <: UIAbility {
    public init() {
        super()
        registerSelf()
    }

    public override func onCreate(want: Want, launchParam: LaunchParam): Unit {
        AppLog.info("MainAbility OnCreated.${want.abilityName}")
        match (launchParam.launchReason) {
            case LaunchReason.START_ABILITY => AppLog.info("START_ABILITY")
            case _ => ()
        }
    }

    public override func onForeground(): Unit {
        windowData().inInBackground = false
    }

    public override func onBackground(): Unit {
        windowData().inInBackground = true
    }

    public override func onWindowStageCreate(windowStage: WindowStage): Unit {
        loadMainContent(windowStage)
        PreferencesUtil.attach(this.context)
        AppPaths.attach(this.context)
        WindowUtil.initWindow(windowStage)    }
}


















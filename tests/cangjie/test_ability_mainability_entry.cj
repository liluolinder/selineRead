package ohos_app_cangjie_entry_test

// CJMP Tools manages this test Ability entry and lifecycle file.
// Modify this file only for test Ability customization.

internal import ohos.ability.UIAbility
internal import ohos.ability.AbilityStage
internal import ohos.ability.LaunchParam
internal import ohos.ability.LaunchReason
internal import ohos.ability.Want
internal import ohos.base.AppLog
internal import ohos.window.WindowStage
import ohos_app_cangjie_entry.loadMainContent

let TEST_ENTRYABILITY_REGISTER_RESULT = UIAbility.registerCreator("TestEntryAbility", {=> TestMainAbility()})
let TEST_ENTRY_STAGE_REGISTER_RESULT = AbilityStage.registerCreator("entry", {=> TestAbilityStage()})

class TestAbilityStage <: AbilityStage {
    public override func onCreate(): Unit {
        AppLog.info("TestAbilityStage onCreated.")
    }
}

class TestMainAbility <: UIAbility {
    public init() {
        super()
        AppLog.info("TestMainAbility init.")
        registerSelf()
    }

    public override func onCreate(want: Want, launchParam: LaunchParam): Unit {
        AppLog.info("TestMainAbility OnCreated.${want.abilityName}")
        match (launchParam.launchReason) {
            case LaunchReason.START_ABILITY => AppLog.info("START_ABILITY")
            case _ => ()
        }
    }

    public override func onWindowStageCreate(windowStage: WindowStage): Unit {
        AppLog.info("TestMainAbility onWindowStageCreate.")
        loadMainContent(windowStage)
        scheduleCjmpUiTestSuite()
    }
}

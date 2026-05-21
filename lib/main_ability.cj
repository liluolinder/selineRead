package ohos_app_cangjie_entry

internal import ohos.app.ability.ability_stage.AbilityStage
internal import ohos.app.ability.ability_constant.LaunchReason
internal import ohos.window.*
import ohos_app_cangjie_entry.models.*

class MainAbility <: UIAbility {
    public init() {
        super()
        registerSelf()
    }


    public override func onCreate(want: Want, launchParam: LaunchParam): Unit {
        match (launchParam.launchReason) {
            case LaunchReason.StartAbility => ()
            case _ => ()
        }
    }

    public override func onWindowStageCreate(windowStage: WindowStage): Unit {
        windowStage.loadContent("EntryView")
        window.initWindow(windowStage)
    }
}

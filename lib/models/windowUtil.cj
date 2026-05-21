package ohos_app_cangjie_entry.models

internal import ohos.app.ability.ability_stage.AbilityStage
internal import ohos.window.*
internal import ohos.arkui.state_management.*
internal import cjmp.net.connection.*
internal import ohos.arkui.component.*
internal import ohos.base.*
import ohos.arkui.state_macro_manage.*
import ohos.resource.*
import ohos.hilog.Hilog
import ohos_app_cangjie_entry.logic.*

foreign func FfiGetStatusBarHeight():Int64

@Observed
public class WindowUtil{
    @Publish
    public var topAvoid:Length = 0.vp

    @Publish
    public var bottomAvoid:Length = 0.vp
  
    public func initWindow(windowStage: WindowStage){
       (topAvoid, bottomAvoid) = getAvoidArea(windowStage)
       Hilog.info(1145,'meow','meow:${topAvoid.value}   ,  ${bottomAvoid.value}')
    }
}


public var window:WindowUtil = WindowUtil()

@When[target_platform == "hos"]
public func getAvoidArea(windowStage: WindowStage):(Length, Length){
    let cutOut = windowStage.getMainWindow().getWindowAvoidArea(AvoidAreaType.TypeCutout)
    let system = windowStage.getMainWindow().getWindowAvoidArea(AvoidAreaType.TypeSystem)
    let nav = windowStage.getMainWindow().getWindowAvoidArea(AvoidAreaType.TypeNavigationIndicator)
    let top = max(Float64(cutOut.topRect.height)*1.5, Float64(system.topRect.height))
    let bottom = max(Float64(nav.bottomRect.height)*0.8, Float64(system.bottomRect.height))
    (LengthMetrics(top, unit: LengthUnit.Px), LengthMetrics(bottom, unit: LengthUnit.Px))
}

@When[target_platform == "android"]
public func getAvoidArea(windowStage: WindowStage): (Length, Length) {
    var statusBarHeight: Int64 = unsafe { FfiGetStatusBarHeight() }
    Hilog.info(1145,'meow','meow:${statusBarHeight}')
    statusBarHeight = meow()
    Hilog.info(1145,'meow','meow1:${statusBarHeight}')
    (LengthMetrics(Float64(statusBarHeight), unit: LengthUnit.Px), LengthMetrics(1.0, unit: LengthUnit.Px))
}
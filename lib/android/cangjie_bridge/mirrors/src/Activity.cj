package mirrors

import java.lang.*

@JavaMirror["android.app.Activity"]
public open class Activity {
    public static let DEFAULT_KEYS_DIALER: Int32

    public static let DEFAULT_KEYS_DISABLE: Int32

    public static let DEFAULT_KEYS_SEARCH_GLOBAL: Int32

    public static let DEFAULT_KEYS_SEARCH_LOCAL: Int32

    public static let DEFAULT_KEYS_SHORTCUT: Int32

    protected static let FOCUSED_STATE_SET: ?JArray<Int32>

    public static let FULLSCREEN_MODE_REQUEST_ENTER: Int32

    public static let FULLSCREEN_MODE_REQUEST_EXIT: Int32

    public static let OVERRIDE_TRANSITION_CLOSE: Int32

    public static let OVERRIDE_TRANSITION_OPEN: Int32

    public static let RESULT_CANCELED: Int32

    public static let RESULT_FIRST_USER: Int32

    public static let RESULT_OK: Int32

    public init()

    public func isChild(): Bool

    public func getParent(): ?Activity

    protected open func onStart(): Unit

    protected open func onRestart(): Unit

    public open func onStateNotSaved(): Unit

    protected open func onResume(): Unit

    protected open func onPostResume(): Unit

    public open func onTopResumedActivityChanged(isTopResumedActivity: Bool): Unit

    public open func isVoiceInteraction(): Bool

    public open func isVoiceInteractionRoot(): Bool

    public open func isLocalVoiceInteractionSupported(): Bool

    public open func onLocalVoiceInteractionStarted(): Unit

    public open func onLocalVoiceInteractionStopped(): Unit

    public open func stopLocalVoiceInteraction(): Unit

    protected open func onPause(): Unit

    protected open func onUserLeaveHint(): Unit

    public func requestShowKeyboardShortcuts(): Unit

    public func dismissKeyboardShortcutsHelper(): Unit

    protected open func onStop(): Unit

    protected open func onDestroy(): Unit

    public open func reportFullyDrawn(): Unit

    public open func onMultiWindowModeChanged(isInMultiWindowMode: Bool): Unit

    public open func isInMultiWindowMode(): Bool

    public open func onPictureInPictureModeChanged(isInPictureInPictureMode: Bool): Unit

    public open func isInPictureInPictureMode(): Bool

    public open func enterPictureInPictureMode(): Unit

    public open func getMaxNumPictureInPictureActions(): Int32

    public open func onPictureInPictureRequested(): Bool

    public open func setShouldDockBigOverlays(shouldDockBigOverlays: Bool): Unit

    public open func shouldDockBigOverlays(): Bool

    public open func getChangingConfigurations(): Int32

    public open func getLastNonConfigurationInstance(): ?JObject

    public open func onRetainNonConfigurationInstance(): ?JObject

    public open func onLowMemory(): Unit

    public open func onTrimMemory(level: Int32): Unit

    public open func setContentView(layoutResID: Int32): Unit

    public open func setFinishOnTouchOutside(finish: Bool): Unit

    public func setDefaultKeyMode(mode: Int32): Unit

    public open func onBackPressed(): Unit

    public open func onUserInteraction(): Unit

    public open func onContentChanged(): Unit

    public open func onWindowFocusChanged(hasFocus: Bool): Unit

    public open func onAttachedToWindow(): Unit

    public open func onDetachedFromWindow(): Unit

    public open func hasWindowFocus(): Bool

    public open func invalidateOptionsMenu(): Unit

    public open func onNavigateUp(): Bool

    public open func onNavigateUpFromChild(child: ?Activity): Bool

    public open func openOptionsMenu(): Unit

    public open func closeOptionsMenu(): Unit

    public open func closeContextMenu(): Unit

    public func showDialog(id: Int32): Unit

    public func dismissDialog(id: Int32): Unit

    public func removeDialog(id: Int32): Unit

    public open func onSearchRequested(): Bool

    public open func takeKeyEvents(get: Bool): Unit

    public func requestWindowFeature(featureId: Int32): Bool

    public func setFeatureDrawableResource(featureId: Int32, resId: Int32): Unit

    public func setFeatureDrawableAlpha(featureId: Int32, alpha: Int32): Unit

    public open func setTheme(resid: Int32): Unit

    public func requestPermissions(permissions: ?JArray<?JString>, requestCode: Int32): Unit

    public open func onRequestPermissionsResult(requestCode: Int32, permissions: ?JArray<?JString>, grantResults: ?JArray<Int32>): Unit

    public open func shouldShowRequestPermissionRationale(permission: ?JString): Bool

    public open func isActivityTransitionRunning(): Bool

    public open func overrideActivityTransition(overrideType: Int32, enterAnim: Int32, exitAnim: Int32): Unit

    public open func overrideActivityTransition(overrideType: Int32, enterAnim: Int32, exitAnim: Int32, backgroundColor: Int32): Unit

    public open func clearOverrideActivityTransition(overrideType: Int32): Unit

    public open func overridePendingTransition(enterAnim: Int32, exitAnim: Int32): Unit

    public open func overridePendingTransition(enterAnim: Int32, exitAnim: Int32, backgroundColor: Int32): Unit

    public func setResult(resultCode: Int32): Unit

    public open func getCallingPackage(): ?JString

    public open func getLaunchedFromUid(): Int32

    public open func getLaunchedFromPackage(): ?JString

    public open func setVisible(visible: Bool): Unit

    public open func isFinishing(): Bool

    public open func isDestroyed(): Bool

    public open func isChangingConfigurations(): Bool

    public open func recreate(): Unit

    public open func finish(): Unit

    public open func finishAffinity(): Unit

    public open func finishFromChild(child: ?Activity): Unit

    public open func finishAfterTransition(): Unit

    public open func finishActivity(requestCode: Int32): Unit

    public open func finishActivityFromChild(child: ?Activity, requestCode: Int32): Unit

    public open func finishAndRemoveTask(): Unit

    public open func releaseInstance(): Bool

    public open func setRequestedOrientation(requestedOrientation: Int32): Unit

    public open func getRequestedOrientation(): Int32

    public open func getTaskId(): Int32

    public open func isTaskRoot(): Bool

    public open func moveTaskToBack(nonRoot: Bool): Bool

    public open func getLocalClassName(): ?JString

    public open func isLaunchedFromBubble(): Bool

    public open func getSystemService(name: ?JString): ?JObject

    public open func setTitle(titleId: Int32): Unit

    public open func setTitleColor(textColor: Int32): Unit

    public func getTitleColor(): Int32

    public func setProgressBarVisibility(visible: Bool): Unit

    public func setProgressBarIndeterminateVisibility(visible: Bool): Unit

    public func setProgressBarIndeterminate(indeterminate: Bool): Unit

    public func setProgress(progress: Int32): Unit

    public func setSecondaryProgress(secondaryProgress: Int32): Unit

    public func setVolumeControlStream(streamType: Int32): Unit

    public func getVolumeControlStream(): Int32

    public open func isImmersive(): Bool

    public open func setTranslucent(translucent: Bool): Bool

    public open func requestVisibleBehind(visible: Bool): Bool

    public open func onVisibleBehindCanceled(): Unit

    public open func onEnterAnimationComplete(): Unit

    public open func setImmersive(i: Bool): Unit

    public open func postponeEnterTransition(): Unit

    public open func startPostponedEnterTransition(): Unit

    public open func startLockTask(): Unit

    public open func stopLockTask(): Unit

    public open func showLockTaskEscapeMessage(): Unit

    public open func setRecentsScreenshotEnabled(enabled: Bool): Unit

    public open func setShowWhenLocked(showWhenLocked: Bool): Unit

    public open func setInheritShowWhenLocked(inheritShowWhenLocked: Bool): Unit

    public open func setTurnScreenOn(turnScreenOn: Bool): Unit
}
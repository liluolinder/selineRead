package chui.kmode

import chui.host.*

func repeatedReplayText(count: Int64): String {
    let out = StringBuilder()
    for (_ in 0..count) { out.append("x") }
    out.toString()
}

func replayKModeReceipt(): MobileHostPackageReceipt {
    MobileHostPackageReceipt(
        MobileApplicationPlatform.HarmonyOS,
        MobilePackageKind.HarmonyApplicationPackage,
        MobilePackageStage.InputTree,
        "dev.canghui.replay",
        AppLifecycleState.Active,
        7,
        12,
        signing: MobileSigningState.Unsigned,
        inputFiles: ["module.json5", "entry/src/main/ets/pages/Index.ets"]
    )
}

@Test
func mobileHostReplayHandlerAcceptsMultipleCallbackLines(): Unit {
    let handler = mobileHostReplayHandler(replayKModeReceipt())
    let json = handler("player.toggle|7|12\nplayer.open|6|11")
    @Expect(json.contains("\"decision\":\"current\""))
    @Expect(json.contains("\"decision\":\"stale-lifecycle-and-surface\""))
}

@Test
func mobileHostReplayPayloadRejectsMalformedLines(): Unit {
    var rejected = false
    try {
        let _ = parseMobileHostReplayPayload("player.toggle|7")
    } catch (_: IllegalArgumentException) {
        rejected = true
    }
    @Expect(rejected)

    var oversizedRejected = false
    try {
        let _ = parseMobileHostReplayPayload(repeatedReplayText(65537))
    } catch (_: IllegalArgumentException) {
        oversizedRejected = true
    }
    @Expect(oversizedRejected)
}

package chui_kmode_release_gate

import chui.{KModeOperation, KModePolicy, KModeRequest, dispatchKModeRequest,
    kModeEnabled, kModeStdioRequested, runKModeStdioIfRequested}

main(): Int64 {
    if (runKModeStdioIfRequested()) { return 0 }
    if (kModeEnabled()) {
        println("unexpected-kmode-enabled")
        return 10
    }
    if (kModeStdioRequested()) {
        println("unexpected-kmode-transport-request")
        return 11
    }
    let explicit = KModePolicy(enabled: true)
    if (explicit.enabled) {
        println("unexpected-explicit-policy-enable")
        return 12
    }
    let response = dispatchKModeRequest(
        KModeRequest(1, KModeOperation.Health),
        policy: explicit
    )
    if (response.ok || response.status != "disabled") {
        println("unexpected-dispatch-result")
        return 13
    }
    println("CANGHUI_KMODE_RELEASE_CLOSED=1")
    0
}

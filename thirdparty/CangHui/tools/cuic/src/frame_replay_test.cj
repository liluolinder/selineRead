package cuic

@When[debug]
import std.collection.ArrayList

@When[debug]
@Test
func frameReplayOfflineVerifierAcceptsSuccessAndConfirmedLegacyFallback(): Unit {
    let trace = frameReplayTestEnvelope([
        frameReplayTestFrame(
            1, "fg-11-101", true, "accepted", "accepted", 1, 1, false, "accepted"),
        frameReplayTestFrame(
            2,
            "fg-22-202",
            false,
            "executor-commit-failed",
            "provider-commit-failed",
            1,
            1,
            true,
            "accepted-legacy-fallback"),
        frameReplayTestFrame(
            3,
            "fg-33-303",
            false,
            "executor-exception",
            "not-started",
            0,
            0,
            true,
            "accepted-legacy-fallback")
    ])
    let receipt = verifyCompiledFrameTraceReceipt(trace)
    @Expect(receipt.contains("\"protocol\":\"canghui.frame-replay.v0\""))
    @Expect(receipt.contains("\"executor\":\"null\""))
    @Expect(receipt.contains("\"frameCount\":3"))
    @Expect(receipt.contains("\"acceptedFrameCount\":3"))
    @Expect(receipt.contains("\"executionOkFrameCount\":1"))
    @Expect(receipt.contains("\"upperLayerLegacyFallbackFrameCount\":2"))
    @Expect(!receipt.contains("\"legacyFallbackFrameCount\""))
    @Expect(receipt.contains("\"lastScheduleHash\":\"fg-33-303\""))
    @Expect(receipt.contains("compiled-trace null schedule verifier only"))
    @Expect(receipt.contains("no graph recompilation, GPU submission or presentation"))
}

@When[debug]
@Test
func frameReplayOfflineVerifierRejectsStaleUnknownAndFalseSuccessTruth(): Unit {
    assertFrameReplayCliRejected(
        frameReplayTestEnvelope([
            frameReplayTestFrame(
                2, "fg-2-2", true, "accepted", "accepted", 1, 1, false, "accepted"),
            frameReplayTestFrame(
                2, "fg-3-3", true, "accepted", "accepted", 1, 1, false, "accepted")
        ]),
        "stale-frame")

    let unknown = "{\"protocol\":\"canghui.frame-trace.v0\",\"scenario\":\"tests.rev1\"," +
        "\"complete\":true,\"terminalCode\":\"accepted\"," +
        "\"frameCount\":0,\"frames\":[],\"host\":\"forbidden\"}"
    assertFrameReplayCliRejected(unknown, "unknown-envelope-field")

    assertFrameReplayCliRejected(
        frameReplayTestEnvelope([
            frameReplayTestFrame(
                1, "fg-1-1", true, "accepted", "accepted", 0, 0, false, "accepted")
        ]),
        "invalid-success-execution")

    assertFrameReplayCliRejected(
        frameReplayTestEnvelope([
            frameReplayTestFrame(
                1, "fg-1-1", false, "executor-pass-failed", "provider-pass-failed",
                0, 0, false, "not-presented")
        ]),
        "invalid-legacy-fallback-execution")

    assertFrameReplayCliRejected(
        frameReplayTestEnvelope([
            frameReplayTestFrame(
                1, "fg-1-1", true, "accepted", "accepted-forged",
                1, 1, false, "accepted")
        ]),
        "invalid-success-execution")

    assertFrameReplayCliRejected(
        frameReplayTestEnvelope([
            frameReplayTestFrame(
                1, "fg-1-1", true, "accepted", "accepted-legacy-full-present",
                1, 1, false, "accepted")
        ]),
        "invalid-success-execution")

    assertFrameReplayCliRejected(
        frameReplayTestEnvelope([
            frameReplayTestFrame(
                1, "fg-1-1", false, "executor-commit-failed", "commit-failed",
                0, 0, true, "accepted-legacy-fallback")
        ]),
        "invalid-commit-failure-count")

    assertFrameReplayCliRejected(
        frameReplayTestEnvelope([
            frameReplayTestFrame(
                1, "fg-1-1", false, "executor-pass-failed", "pass-failed",
                1, 1, true, "accepted-legacy-fallback")
        ]),
        "invalid-pass-failure-count")

    assertFrameReplayCliRejected(
        frameReplayTestEnvelope([
            frameReplayTestFrame(
                1, "fg-1-1", false, "executor-pass-failed", "not-started",
                0, 0, true, "accepted-legacy-fallback")
        ]),
        "invalid-not-started-provider")
}

@When[debug]
@Test
func frameReplayOfflineVerifierAcceptsGenerationResetAndBoundedTerminal(): Unit {
    let reset = frameReplayTestEnvelopeWithTerminal([
        frameReplayTestFrameForGeneration(
            9, 1, "fg-9-9", "full", "none", "none"),
        frameReplayTestFrameForGeneration(
            1, 2, "fg-10-10", "full", "none", "none")
    ], "trace-cap-reached")
    let receipt = verifyCompiledFrameTraceReceipt(reset)
    @Expect(receipt.contains("\"terminalCode\":\"trace-cap-reached\""))

    assertFrameReplayCliRejected(
        frameReplayTestEnvelopeWithTerminal([
            frameReplayTestFrame(1, "fg-1-1", true, "accepted", "accepted",
                1, 1, false, "accepted")
        ], "executor-exception"),
        "invalid-trace-terminal")

    assertFrameReplayCliRejected(
        frameReplayTestEnvelopeWithCompletion([
            frameReplayTestFrame(1, "fg-1-1", true, "accepted", "accepted",
                1, 1, false, "accepted")
        ], false, "application-exception"),
        "incomplete-trace")

    assertFrameReplayCliRejected(
        frameReplayTestEnvelope([]),
        "empty-frame-trace")

    assertFrameReplayCliRejected(
        frameReplayTestEnvelope([
            frameReplayTestFrameForGeneration(
                1, 2, "fg-1-1", "full", "none", "none"),
            frameReplayTestFrameForGeneration(
                2, 1, "fg-2-2", "full", "none", "none")
        ]),
        "stale-surface-generation")

    let maximumFrames = ArrayList<String>()
    for (i in 0..64) {
        let frameId = i + 1
        maximumFrames.add(frameReplayTestFrame(
            frameId,
            "fg-${frameId}-${frameId}",
            true,
            "accepted",
            "accepted",
            1,
            1,
            false,
            "accepted"))
    }
    assertFrameReplayCliRejected(
        frameReplayTestEnvelopeWithTerminal(maximumFrames.toArray(), "trace-cap-reached"),
        "invalid-trace-cap-terminal")
}

@When[debug]
@Test
func frameReplayOfflineVerifierRejectsBoundedModeWithFullDamage(): Unit {
    assertFrameReplayCliRejected(
        frameReplayTestEnvelope([
            frameReplayTestFrameForGeneration(
                1, 1, "fg-1-1", "bounded", "partial", "none")
        ]),
        "invalid-bounded-redraw-damage")

    let rectangles = frameReplayTestRectangles(2049)
    let excessive = "[" +
        frameReplayTestUiPass("ui.first", 0, "[\"first@1\"]", "bounded", rectangles) +
        "," +
        frameReplayTestUiPass("ui.second", 1, "[\"second@1\"]", "bounded", rectangles) +
        "]"
    assertFrameReplayCliRejected(
        frameReplayTestEnvelope([
            frameReplayTestModeFrame(
                2, "fg-2-2", excessive, 2, "bounded", "none", "none", "accepted")
        ]),
        "invalid-bounded-redraw-damage")

    let bounded = "[" +
        frameReplayTestUiPass(
            "ui.main", 0, "[\"surface@1\"]", "bounded", "[[0,0,10,10]]") +
        "]"
    assertFrameReplayCliRejected(
        frameReplayTestEnvelope([
            frameReplayTestModeFrame(
                3, "fg-3-3", bounded, 1, "full", "none", "none", "accepted")
        ]),
        "missing-bounded-redraw-fallback")
}

@When[debug]
@Test
func frameReplayOfflineVerifierRejectsImpossiblePresentSchedules(): Unit {
    let nonTerminal = "[" +
        frameReplayTestUiPass("ui.main", 0, "[\"surface@1\"]", "full", "[]") +
        "," + frameReplayTestPresentPass("full", "[]") +
        "," +
        frameReplayTestUiPass("ui.after", 2, "[\"after@1\"]", "full", "[]") +
        "]"
    assertFrameReplayCliRejected(
        frameReplayTestEnvelope([
            frameReplayTestModeFrame(
                1, "fg-1-1", nonTerminal, 3, "full", "full", "none", "accepted")
        ]),
        "present-not-terminal")

    let multiple = "[" +
        frameReplayTestUiPass("ui.main", 0, "[\"surface@1\"]", "full", "[]") +
        "," + frameReplayTestPresentPass("full", "[]") +
        "," + frameReplayTestPresentPassAt(
            "present.secondary", 2, "full", "[]") + "]"
    assertFrameReplayCliRejected(
        frameReplayTestEnvelope([
            frameReplayTestModeFrame(
                1, "fg-1-1", multiple, 3, "full", "full", "none", "accepted")
        ]),
        "multiple-present-passes")
}

@When[debug]
@Test
func frameReplayOfflineVerifierAcceptsFrozenProviderAndBoundedFallbackModes(): Unit {
    let fullPasses = "[" +
        frameReplayTestUiPass("ui.main", 0, "[\"surface@1\"]", "full", "[]") +
        "," + frameReplayTestPresentPass("full", "[]") + "]"
    let boundedRectangles = "[[0,0,10,10]]"
    let boundedPasses = "[" +
        frameReplayTestUiPass(
            "ui.main", 0, "[\"surface@1\"]", "bounded", boundedRectangles) +
        "," + frameReplayTestPresentPass("bounded", boundedRectangles) + "]"
    let trace = frameReplayTestEnvelope([
        frameReplayTestModeFrame(
            1, "fg-1-1", fullPasses, 2, "full", "full", "none",
            "accepted-legacy-full-present"),
        frameReplayTestModeFrame(
            2, "fg-2-2", boundedPasses, 2, "bounded", "full",
            "partial-present-unsupported", "accepted")
    ])
    let receipt = verifyCompiledFrameTraceReceipt(trace)
    @Expect(receipt.contains("\"acceptedFrameCount\":2"))
}

@When[debug]
@Test
func frameReplayOfflineVerifierKeepsByteAndHashSetGuards(): Unit {
    assertFrameReplayCliRejected(
        String.fromUtf8(Array<UInt8>(512 * 1024 + 1, repeat: UInt8(65))),
        "payload-over-cap")

    let duplicateAccess = frameReplayTestPass(
        "[\"source@1\",\"source@1\"]",
        "[\"surface@1\"]")
    assertFrameReplayCliRejected(
        frameReplayTestEnvelope([
            frameReplayTestFrameWithPasses(
                1,
                "fg-1-1",
                "[" + duplicateAccess + "]",
                1,
                0,
                0,
                true,
                "accepted",
                "accepted",
                1,
                1,
                false,
                "accepted")
        ]),
        "duplicate-resource-access")

    let readWriteAlias = frameReplayTestPass(
        "[\"surface@1\"]",
        "[\"surface@1\"]")
    assertFrameReplayCliRejected(
        frameReplayTestEnvelope([
            frameReplayTestFrameWithPasses(
                1,
                "fg-1-1",
                "[" + readWriteAlias + "]",
                1,
                0,
                0,
                true,
                "accepted",
                "accepted",
                1,
                1,
                false,
                "accepted")
        ]),
        "read-write-same-resource")
}

@When[debug]
private func assertFrameReplayCliRejected(payload: String, code: String): Unit {
    var rejected = false
    try {
        let _ = verifyCompiledFrameTraceReceipt(payload)
    } catch (error: CuicError) {
        rejected = error.message.contains(code)
    }
    @Expect(rejected)
}

@When[debug]
private func frameReplayTestEnvelope(frames: Array<String>): String {
    frameReplayTestEnvelopeWithTerminal(frames, "accepted")
}

@When[debug]
private func frameReplayTestEnvelopeWithTerminal(
    frames: Array<String>,
    terminalCode: String
): String {
    frameReplayTestEnvelopeWithCompletion(frames, true, terminalCode)
}

@When[debug]
private func frameReplayTestEnvelopeWithCompletion(
    frames: Array<String>,
    complete: Bool,
    terminalCode: String
): String {
    let out = StringBuilder()
    out.append("{\"protocol\":\"canghui.frame-trace.v0\",\"scenario\":\"tests.rev1\",")
    out.append("\"complete\":")
    out.append(complete.toString())
    out.append(",\"terminalCode\":\"")
    out.append(terminalCode)
    out.append("\",\"frameCount\":")
    out.append(frames.size.toString())
    out.append(",\"frames\":[")
    for (i in 0..frames.size) {
        if (i > 0) { out.append(",") }
        out.append(frames[i])
    }
    out.append("]}")
    out.toString()
}

@When[debug]
private func frameReplayTestFrameForGeneration(
    frameId: Int64,
    surfaceGeneration: Int64,
    scheduleHash: String,
    redrawMode: String,
    presentMode: String,
    fallbackReason: String
): String {
    let pass = frameReplayTestPass("[]", "[\"surface@1\"]")
    "{\"protocol\":\"canghui.frame-graph.v0\",\"surface\":\"main\"," +
        "\"surfaceGeneration\":" + surfaceGeneration.toString() +
        ",\"frameId\":" + frameId.toString() +
        ",\"scheduleHash\":\"" + scheduleHash +
        "\",\"declaredResourceBytes\":0,\"executedPassCount\":1," +
        "\"culledPassCount\":0,\"mergedPassCount\":0," +
        "\"redrawMode\":\"" + redrawMode + "\",\"presentMode\":\"" +
        presentMode + "\",\"fallbackReason\":\"" + fallbackReason +
        "\",\"passes\":[" + pass + "],\"executionDurationNs\":1000," +
        "\"executionOk\":true,\"executionCode\":\"accepted\"," +
        "\"providerCode\":\"accepted\"," +
        "\"completedPassCount\":1,\"completedGroupCount\":1," +
        "\"legacyFallbackUsed\":false,\"finalFrameCode\":\"accepted\"}"
}

@When[debug]
private func frameReplayTestFrame(
    frameId: Int64,
    scheduleHash: String,
    executionOk: Bool,
    executionCode: String,
    providerCode: String,
    completedPassCount: Int64,
    completedGroupCount: Int64,
    legacyFallbackUsed: Bool,
    finalFrameCode: String
): String {
    frameReplayTestFrameWithPasses(
        frameId,
        scheduleHash,
        "[" + frameReplayTestPass("[]", "[\"surface@1\"]") + "]",
        1,
        0,
        0,
        executionOk,
        executionCode,
        providerCode,
        completedPassCount,
        completedGroupCount,
        legacyFallbackUsed,
        finalFrameCode)
}

@When[debug]
private func frameReplayTestFrameWithPasses(
    frameId: Int64,
    scheduleHash: String,
    passes: String,
    executedPassCount: Int64,
    culledPassCount: Int64,
    mergedPassCount: Int64,
    executionOk: Bool,
    executionCode: String,
    providerCode: String,
    completedPassCount: Int64,
    completedGroupCount: Int64,
    legacyFallbackUsed: Bool,
    finalFrameCode: String
): String {
    "{\"protocol\":\"canghui.frame-graph.v0\",\"surface\":\"main\"," +
        "\"surfaceGeneration\":1,\"frameId\":" + frameId.toString() +
        ",\"scheduleHash\":\"" + scheduleHash + "\",\"declaredResourceBytes\":0," +
        "\"executedPassCount\":" + executedPassCount.toString() +
        ",\"culledPassCount\":" + culledPassCount.toString() +
        ",\"mergedPassCount\":" + mergedPassCount.toString() +
        ",\"redrawMode\":\"full\",\"presentMode\":\"none\"," +
        "\"fallbackReason\":\"none\",\"passes\":" + passes +
        ",\"executionDurationNs\":1000,\"executionOk\":" + executionOk.toString() +
        ",\"executionCode\":\"" + executionCode + "\"" +
        ",\"providerCode\":\"" + providerCode + "\"" +
        ",\"completedPassCount\":" + completedPassCount.toString() +
        ",\"completedGroupCount\":" + completedGroupCount.toString() +
        ",\"legacyFallbackUsed\":" + legacyFallbackUsed.toString() +
        ",\"finalFrameCode\":\"" + finalFrameCode + "\"}"
}

@When[debug]
private func frameReplayTestPass(reads: String, writes: String): String {
    "{\"id\":\"ui.main\",\"order\":0,\"kind\":\"ui-2d\"," +
        "\"externalMode\":\"none\",\"unifiedPixels\":false,\"reads\":" + reads +
        ",\"writes\":" + writes + ",\"dependsOn\":[],\"culled\":false," +
        "\"damage\":{\"kind\":\"full\",\"rectangles\":[]}}"
}

@When[debug]
private func frameReplayTestModeFrame(
    frameId: Int64,
    scheduleHash: String,
    passes: String,
    executedPassCount: Int64,
    redrawMode: String,
    presentMode: String,
    fallbackReason: String,
    providerCode: String
): String {
    "{\"protocol\":\"canghui.frame-graph.v0\",\"surface\":\"main\"," +
        "\"surfaceGeneration\":1,\"frameId\":" + frameId.toString() +
        ",\"scheduleHash\":\"" + scheduleHash +
        "\",\"declaredResourceBytes\":0,\"executedPassCount\":" +
        executedPassCount.toString() +
        ",\"culledPassCount\":0,\"mergedPassCount\":0," +
        "\"redrawMode\":\"" + redrawMode + "\",\"presentMode\":\"" +
        presentMode + "\",\"fallbackReason\":\"" + fallbackReason +
        "\",\"passes\":" + passes + ",\"executionDurationNs\":1000," +
        "\"executionOk\":true,\"executionCode\":\"accepted\"," +
        "\"providerCode\":\"" + providerCode +
        "\",\"completedPassCount\":" + executedPassCount.toString() +
        ",\"completedGroupCount\":" + executedPassCount.toString() +
        ",\"legacyFallbackUsed\":false,\"finalFrameCode\":\"accepted\"}"
}

@When[debug]
private func frameReplayTestUiPass(
    id: String,
    order: Int64,
    writes: String,
    damageKind: String,
    rectangles: String
): String {
    "{\"id\":\"" + id + "\",\"order\":" + order.toString() +
        ",\"kind\":\"ui-2d\",\"externalMode\":\"none\"," +
        "\"unifiedPixels\":false,\"reads\":[],\"writes\":" + writes +
        ",\"dependsOn\":[],\"culled\":false,\"damage\":{\"kind\":\"" +
        damageKind + "\",\"rectangles\":" + rectangles + "}}"
}

@When[debug]
private func frameReplayTestPresentPass(damageKind: String, rectangles: String): String {
    frameReplayTestPresentPassAt("present.main", 1, damageKind, rectangles)
}

@When[debug]
private func frameReplayTestPresentPassAt(
    id: String,
    order: Int64,
    damageKind: String,
    rectangles: String
): String {
    "{\"id\":\"" + id + "\",\"order\":" + order.toString() +
        ",\"kind\":\"present\"," +
        "\"externalMode\":\"none\",\"unifiedPixels\":false," +
        "\"reads\":[\"surface@1\"],\"writes\":[],\"dependsOn\":[]," +
        "\"culled\":false,\"damage\":{\"kind\":\"" + damageKind +
        "\",\"rectangles\":" + rectangles + "}}"
}

@When[debug]
private func frameReplayTestRectangles(count: Int64): String {
    let out = StringBuilder()
    out.append("[")
    for (i in 0..count) {
        if (i > 0) { out.append(",") }
        out.append("[0,0,1,1]")
    }
    out.append("]")
    out.toString()
}

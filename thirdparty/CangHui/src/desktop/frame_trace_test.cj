package chui.desktop

@When[debug]
@Test
func frameTraceEnvelopeIsBoundedSanitizedAndComplete(): Unit {
    let frame = "{\"protocol\":\"canghui.frame-graph.v0\",\"surface\":\"main\",\"frameId\":1,\"scheduleHash\":\"fg-1\"}"
    let first = renderFrameTraceEnvelope("gallery.rev1", [frame])
    let second = renderFrameTraceEnvelope("gallery.rev1", [frame])
    @Expect(first, second)
    @Expect(first.contains("\"protocol\":\"canghui.frame-trace.v0\""))
    @Expect(first.contains("\"complete\":true"))
    @Expect(first.contains("\"frameCount\":1"))
    @Expect(!first.contains("/Users/"))
}

@When[debug]
@Test
func frameTraceEnvelopeRejectsUnsafeScenarioAndForeignFrame(): Unit {
    @ExpectThrows[IllegalArgumentException](
        renderFrameTraceEnvelope("../private", []))
    @ExpectThrows[IllegalArgumentException](
        renderFrameTraceEnvelope("gallery", ["{\"protocol\":\"foreign\"}"]))
}

@When[debug]
@Test
func frameTraceFailureEnvelopeCannotMasqueradeAsComplete(): Unit {
    let frame = "{\"protocol\":\"canghui.frame-graph.v0\",\"surface\":\"main\",\"frameId\":1}"
    let failed = renderFrameTraceEnvelope(
        "gallery.rev1",
        [frame],
        terminalCode: "application-exception",
        complete: false)
    @Expect(failed.contains("\"complete\":false"))
    @Expect(failed.contains("\"terminalCode\":\"application-exception\""))
    @Expect(failed.contains("\"frameCount\":1"))
}

@When[debug]
@Test
func frameTraceDecorationSeparatesGraphFailureFromSuccessfulLegacyFallback(): Unit {
    let frame = decorateFrameTrace(
        "{\"protocol\":\"canghui.frame-graph.v0\"}",
        UInt64(42),
        false,
        "executor-pass-failed",
        "configured-pass-failure",
        1,
        1,
        true,
        "accepted-legacy-fallback")
    @Expect(frame.contains("\"executionOk\":false"))
    @Expect(frame.contains("\"executionCode\":\"executor-pass-failed\""))
    @Expect(frame.contains("\"providerCode\":\"configured-pass-failure\""))
    @Expect(frame.contains("\"legacyFallbackUsed\":true"))
    @Expect(frame.contains("\"finalFrameCode\":\"accepted-legacy-fallback\""))
}

package chui.probe

@Test
func probeRegistrySortsAndRunsBoundedHandlers(): Unit {
    let prefix = "zztest.registry"
    let _ = registerProbeEndpoint(ProbeEndpoint(prefix + ".b", "second", ProbeKind.Function, { value => value + "b" }))
    let _ = registerProbeEndpoint(ProbeEndpoint(prefix + ".a", "first", ProbeKind.Function, { value => value + "a" }))
    let rendered = renderProbeEndpointList(json: true)
    let firstIndex = rendered.indexOf(prefix + ".a").getOrThrow()
    let secondIndex = rendered.indexOf(prefix + ".b").getOrThrow()
    @Expect(firstIndex < secondIndex)
    @Expect(runProbeEndpoint(prefix + ".a", payload: "x"), "xa")
    @Expect(describeProbeEndpoint(prefix + ".b").contains("|function|second"))
}

@Test
func probeNamesRejectUnsafeShapes(): Unit {
    @Expect(probeNameRejected(""))
    @Expect(probeNameRejected("1bad"))
    @Expect(probeNameRejected("bad/path"))
}

@Test
func probeRegistryRejectsDuplicateNamesAtRuntime(): Unit {
    let name = "zztest.runtime-duplicate"
    let _ = registerProbeEndpoint(ProbeEndpoint(name, "first", ProbeKind.Function, { value => value }))
    @Expect(probeRegistrationRejected(name))
}

func probeNameRejected(value: String): Bool {
    try {
        validateProbeName(value)
        false
    } catch (_: IllegalArgumentException) {
        true
    }
}

func probeRegistrationRejected(name: String): Bool {
    try {
        let _ = registerProbeEndpoint(ProbeEndpoint(name, "second", ProbeKind.Function, { value => value }))
        false
    } catch (_: IllegalStateException) {
        true
    }
}

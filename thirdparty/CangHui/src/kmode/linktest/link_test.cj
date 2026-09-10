package chui.kmode.linktest

@When[debug]
import chui.kmode.{KModeOperation, KModePolicy, KModeRequest, dispatchKModeRequest}
import chui.kmode.macros.*

@KModeLink["tests.macro.echo"]
func linkedEcho(value: String): String {
    "linked:" + value
}

@When[debug]
@Test
func macroLinkedEndpointIsRegisteredAndInvocable(): Unit {
    let response = dispatchKModeRequest(
        KModeRequest(11, KModeOperation.Invoke, endpoint: "tests.macro.echo", payload: "value"),
        policy: KModePolicy(enabled: true)
    )
    @Expect(response.ok)
    @Expect(response.payload, "linked:value")
}

package ignite.tests

import ignite.*
import seajson.defaultJsonEncoder as seaJsonDefaultJsonEncoder

@Test
public class JsonEncodeContractBridgeTestSuite {
    @TestCase
    public func testJsonEncodeUsesSeaJsonOwnedJsonEncodableContractByDefault(): Unit {
        let app = App(config: Config())
        app.get("/json-encode-default", { ctx =>
            _ = ctx.jsonEncode(BridgeOwnedJsonEncodable("ignite", 9))
        })

        let resp = app.handleForTest("GET", "/json-encode-default")
        @Assert(resp.status, UInt16(200))
        @Assert(resp.header("content-type") ?? "", "application/json; charset=utf-8")
        @Assert(resp.body, "{\"name\":\"ignite\",\"n\":9}")
    }

    @TestCase
    public func testConfigJsonEncoderAcceptsSeaJsonDefaultEncoderDirectly(): Unit {
        let app = App(
            config: Config(
                jsonEncoder: Some(seaJsonDefaultJsonEncoder)
            )
        )
        app.get("/json-encode-seajson-default", { ctx =>
            _ = ctx.jsonEncode(BridgeOwnedJsonEncodable("bridge", 42))
        })

        let resp = app.handleForTest("GET", "/json-encode-seajson-default")
        @Assert(resp.status, UInt16(200))
        @Assert(resp.header("content-type") ?? "", "application/json; charset=utf-8")
        @Assert(resp.body, "{\"name\":\"bridge\",\"n\":42}")
    }

    @TestCase
    public func testConfigJsonEncoderOverrideStillWinsOverDefaultContractBridge(): Unit {
        let app = App(
            config: Config(
                jsonEncoder: Some({ obj =>
                    "{\"wrapped\":" + obj.toJsonString() + "}"
                })
            )
        )
        app.get("/json-encode-override", { ctx =>
            _ = ctx.jsonEncode(BridgeOwnedJsonEncodable("wrapped", 7))
        })

        let resp = app.handleForTest("GET", "/json-encode-override")
        @Assert(resp.status, UInt16(200))
        @Assert(resp.header("content-type") ?? "", "application/json; charset=utf-8")
        @Assert(resp.body, "{\"wrapped\":{\"name\":\"wrapped\",\"n\":7}}")
    }
}

class BridgeOwnedJsonEncodable <: JsonEncodable {
    let name: String
    let n: Int64

    init(name: String, n: Int64) {
        this.name = name
        this.n = n
    }

    public func toJsonString(): String {
        "{\"name\":\"${name}\",\"n\":${n}}"
    }
}

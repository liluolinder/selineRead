import ignite.*
import ignite.client.*
import ignite.api2
import std.collection.{ArrayList, HashMap}

func buildCryptoConfig(): api2.ClientCryptoConfig {
    let ring = HashMap<String, Array<UInt8>>()
    ring.add("k1", "0123456789abcdef0123456789abcdef".toArray())
    api2.ClientCryptoConfig(
        providerKind: api2.ClientCryptoProviderKind.StdxFallback,
        activeKid: "k1",
        keyRing: ring,
        aeadAlgorithm: "AES-256-GCM"
    )
}

func jsonError(code: api2.ClientCryptoErrorCode): String {
    "{\"ok\":false,\"code\":\"${code.toString()}\"}"
}

main() {
    let app = App()
    let crypto = buildCryptoConfig()

    app.get("/ping", { ctx =>
        ctx.json("{\"ok\":true,\"pong\":\"ignite\"}")
    })

    app.post("/echo-json", { ctx =>
        let body = ctx.bodyString()
        if (body.size == 0) {
            ctx.status(400).json("{\"ok\":false,\"error\":\"empty body\"}")
            return
        }
        ctx.json("{\"ok\":true,\"echo\":${body}}")
    })

    app.post("/secure-echo", { ctx =>
        let envelope = ctx.bodyString()
        try {
            let plain = api2.decryptEnvelopeV1ToJson(
                crypto,
                envelope,
                aadText: "route:/secure-echo"
            )
            ctx.json("{\"ok\":true,\"decrypted\":${plain}}")
        } catch (e: Exception) {
            ctx.status(400).json("{\"ok\":false,\"error\":\"decrypt failed: ${e.message}\"}")
        }
    })

    app.get("/stream-response", { ctx =>
        // Returns enough content to demonstrate bodyStream() vs bodyBytes()
        // The client can choose to read this as a stream or cache it.
        ctx.json("{\"ok\":true,\"data\":\"this is a longer response body for stream vs cached body demonstration - Ignite client supports both one-pass streaming via bodyStream() and cached repeatable access via bodyBytes()\",\"size\":\"large\"}")
    })

    app.post("/upload-multipart", { ctx =>
        let meta = ctx.formValue("meta") ?? "-"
        if (let Some(file) <- ctx.formFile("file")) {
            ctx.json(
                "{\"ok\":true,\"meta\":\"${meta}\",\"filename\":\"${file.filename}\",\"contentType\":\"${file.contentType}\",\"size\":${file.size()}}"
            )
        } else {
            ctx.status(400).json("{\"ok\":false,\"error\":\"missing file\"}")
        }
    })

    println("[demo_server] listening on http://127.0.0.1:18080")
    println("[demo_server] routes: GET /ping, POST /echo-json, POST /secure-echo, GET /stream-response, POST /upload-multipart")
    app.listen("127.0.0.1", 18080)
}

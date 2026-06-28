import ignite.*
import std.env.getVariable
import std.fs.exists

main() {
    let httpsHost = "127.0.0.1"
    let httpsPort: UInt16 = 18443
    let httpPort: UInt16 = 18080
    let certFile = readRequiredPath("IGNITE_SAMPLE_TLS_CERT")
    let keyFile = readRequiredPath("IGNITE_SAMPLE_TLS_KEY")
    if (certFile.size == 0 || keyFile.size == 0) {
        println("[sample/dualport] skip https listener: set IGNITE_SAMPLE_TLS_CERT and IGNITE_SAMPLE_TLS_KEY first")
        println("[sample/dualport] example:")
        println("[sample/dualport]   export IGNITE_SAMPLE_TLS_CERT=/path/to/server-cert.pem")
        println("[sample/dualport]   export IGNITE_SAMPLE_TLS_KEY=/path/to/server-key.pem")
        return
    }

    let httpsApp = App(config: Config(
        appName: "ignite-sample-dual-https",
        tlsCertFile: certFile,
        tlsKeyFile: keyFile
    ))
    installHttpsServiceRoutes(httpsApp)

    let httpApp = App(config: Config(appName: "ignite-sample-dual-http"))
    installHttpRedirectRoutes(httpApp, httpsHost, httpsPort)

    let _ = spawn {
        println("[sample/dualport] http redirect on http://127.0.0.1:${httpPort}")
        httpApp.listen("127.0.0.1", httpPort)
    }

    println("[sample/dualport] https app on https://${httpsHost}:${httpsPort}")
    println("[sample/dualport] try: curl -i http://127.0.0.1:${httpPort}/health")
    println("[sample/dualport] try: curl -k -i https://${httpsHost}:${httpsPort}/health")
    httpsApp.listen(httpsHost, httpsPort)
}

func installHttpsServiceRoutes(app: App): Unit {
    app.get("/", { ctx =>
        _ = ctx.sendString("ignite dual listener sample")
    })
    app.get("/health", { ctx =>
        _ = ctx.json(#"{"ok":true,"listener":"https"}"#)
    })
}

func installHttpRedirectRoutes(app: App, httpsHost: String, httpsPort: UInt16): Unit {
    app.get("/", { ctx =>
        ctx.redirect("https://${httpsHost}:${httpsPort}/", code: 307)
    })
    app.get("/*", { ctx =>
        ctx.redirect("https://${httpsHost}:${httpsPort}${ctx.path}", code: 307)
    })
}

func readRequiredPath(envName: String): String {
    if (let Some(path) <- getVariable(envName)) {
        let trimmed = path.trimAscii()
        if (trimmed.size == 0) {
            return ""
        }
        if (exists(trimmed)) {
            return trimmed
        }
        println("[sample/dualport] configured path does not exist: ${envName}=${trimmed}")
        return ""
    }
    ""
}

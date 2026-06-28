package ignite.tests

import ignite.*
import ignite.client.RestClient
import ignite.middleware.*
import std.collection.{ArrayList, HashMap}
import std.env.{getVariable, removeVariable, setVariable}
import std.fs.{Directory, exists, File, OpenMode, removeIfExists}
import std.io.InputStream
import std.net.{TcpSocket, IPSocketAddress}
import std.time.DateTime

@Test
public class ProxyMiddlewareTestSuite {
    @TestCase
    public func testProxyMiddlewareStreamsLargeUploadAndPreservesQuery(): Unit {
        let upstreamPort = choosePort(1801)
        let proxyPort = choosePort(1807)
        let fixturePath = "/tmp/ignite_proxy_upload_fixture.txt"
        let payload = buildLargeAsciiPayload() + buildLargeAsciiPayload()

        let upstream = App(config: Config(bodyLimit: 8 * 1024 * 1024))
        upstream.post("/up/upload", { ctx =>
            let saved = ctx.saveBodyToFile(fixturePath)
            let token = ctx.queryFromUrl("token") ?? ""
            let contentType = ctx.header("content-type") ?? ""
            let forwardedHost = ctx.header("x-forwarded-host") ?? ""
            _ = ctx.status(201).sendString(
                "saved=${saved};token=${token};content-type=${contentType};forwarded-host=${forwardedHost}"
            )
        })

        let proxy = App(config: Config(bodyLimit: 8 * 1024 * 1024))
        proxy.use(proxyObserveHeaderMiddleware())
        proxy.use(proxyMiddleware(
            ProxyConfig(
                "http://127.0.0.1:${upstreamPort}",
                pathRewrite: [("/proxy", "/up")]
            )
        ))

        let upstreamFuture = spawn {
            upstream.listen("127.0.0.1", upstreamPort)
        }
        let proxyFuture = spawn {
            proxy.listen("127.0.0.1", proxyPort)
        }

        try {
            let resp = sendRequestWithRetry(
                "POST",
                "http://127.0.0.1:${proxyPort}/proxy/upload?token=abc123",
                body: payload,
                headers: [("content-type", "text/plain; charset=utf-8")]
            )
            @Assert(resp.status, UInt16(201))
            @Assert(contains(resp.bodyText, "saved=${payload.size}"), true)
            @Assert(contains(resp.bodyText, "token=abc123"), true)
            @Assert(contains(resp.bodyText, "content-type=text/plain; charset=utf-8"), true)
            @Assert(contains(resp.bodyText, "forwarded-host=127.0.0.1:${proxyPort}"), true)
            @Assert(resp.proxyRequestBodyMode, "known-length-stream")
            @Assert(resp.proxyRequestBodyBytes, payload.size.toString())
            @Assert(resp.proxyRequestBodyLimitBytes, "")
            @Assert(resp.proxyResponseBodyMode, "known-length-stream")
            @Assert(resp.proxyResponseBodyBytes, resp.bodyText.size.toString())
            @Assert(resp.proxyDownstreamBodyMode, "known-length-stream")
            @Assert(resp.proxyDownstreamBodyBytes, resp.bodyText.size.toString())
            @Assert(readTextFile(fixturePath), payload)
        } finally {
            shutdownApp(upstream, upstreamFuture)
            shutdownApp(proxy, proxyFuture)
        }
    }

    @TestCase
    public func testProxyMiddlewareRelaysLargeFileResponseAndHeaders(): Unit {
        let upstreamPort = choosePort(1813)
        let proxyPort = choosePort(1819)
        let fixturePath = "/tmp/ignite_proxy_response_fixture.txt"
        let payload = buildLargeAsciiPayload()
        writeTextFile(fixturePath, payload)

        let upstream = App(config: Config())
        upstream.get("/up/file", { ctx =>
            _ = ctx.setHeader("x-upstream", "ok")
            _ = ctx.sendFile(fixturePath)
        })

        let proxy = App(config: Config())
        proxy.use(proxyObserveHeaderMiddleware())
        proxy.use(proxyMiddleware(
            ProxyConfig(
                "http://127.0.0.1:${upstreamPort}",
                pathRewrite: [("/proxy", "/up")]
            )
        ))

        let upstreamFuture = spawn {
            upstream.listen("127.0.0.1", upstreamPort)
        }
        let proxyFuture = spawn {
            proxy.listen("127.0.0.1", proxyPort)
        }

        try {
            let resp = sendRequestWithRetry(
                "GET",
                "http://127.0.0.1:${proxyPort}/proxy/file?download=1"
            )
            @Assert(resp.status, UInt16(200))
            @Assert(resp.bodyText, payload)
            @Assert(resp.contentType, "text/plain; charset=utf-8")
            @Assert(resp.contentLength, payload.size.toString())
            @Assert(resp.acceptRanges, "bytes")
            @Assert(resp.xUpstream, "ok")
            @Assert(resp.proxyRequestBodyMode, "known-length-stream")
            @Assert(resp.proxyRequestBodyBytes, "0")
            @Assert(resp.proxyRequestBodyLimitBytes, "")
            @Assert(resp.proxyResponseBodyMode, "known-length-stream")
            @Assert(resp.proxyResponseBodyBytes, payload.size.toString())
            @Assert(resp.proxyDownstreamBodyMode, "known-length-stream")
            @Assert(resp.proxyDownstreamBodyBytes, payload.size.toString())
        } finally {
            shutdownApp(upstream, upstreamFuture)
            shutdownApp(proxy, proxyFuture)
        }
    }

    @TestCase
    public func testProxyMiddlewareRelaysKnownLengthResponseWithoutChunkedOnHttp11Wire(): Unit {
        let upstreamPort = choosePort(1814)
        let proxyPort = choosePort(1815)
        let fixturePath = "/tmp/ignite_proxy_response_wire_fixture.txt"
        let payload = buildLargeAsciiPayload()
        writeTextFile(fixturePath, payload)

        let upstream = App(config: Config())
        upstream.get("/up/file-wire", { ctx =>
            _ = ctx.setHeader("x-upstream", "wire-ok")
            _ = ctx.sendFile(fixturePath)
        })

        let proxy = App(config: Config())
        proxy.use(proxyObserveHeaderMiddleware())
        proxy.use(proxyMiddleware(
            ProxyConfig(
                "http://127.0.0.1:${upstreamPort}",
                pathRewrite: [("/proxy", "/up")]
            )
        ))

        let upstreamFuture = spawn {
            upstream.listen("127.0.0.1", upstreamPort)
        }
        let proxyFuture = spawn {
            proxy.listen("127.0.0.1", proxyPort)
        }

        try {
            let resp = sendRawProxyHttpWithRetry(proxyPort, "GET", "/proxy/file-wire", [])
            @Assert(resp.status, UInt16(200))
            @Assert(resp.header("content-length") ?? "", payload.size.toString())
            @Assert(resp.header("transfer-encoding") ?? "", "")
            @Assert(resp.header("x-upstream") ?? "", "wire-ok")
            @Assert(resp.header(IGNITE_PROXY_RESPONSE_BODY_MODE_HEADER) ?? "", "known-length-stream")
            @Assert(resp.header(IGNITE_PROXY_RESPONSE_BODY_BYTES_HEADER) ?? "", payload.size.toString())
            @Assert(resp.header(IGNITE_PROXY_DOWNSTREAM_BODY_MODE_HEADER) ?? "", "known-length-stream")
            @Assert(resp.header(IGNITE_PROXY_DOWNSTREAM_BODY_BYTES_HEADER) ?? "", payload.size.toString())
            @Assert(resp.bodyText, payload)
        } finally {
            shutdownApp(upstream, upstreamFuture)
            shutdownApp(proxy, proxyFuture)
        }
    }

    @TestCase
    public func testProxyMiddlewareObservesUnknownLengthUpstreamResponse(): Unit {
        let upstreamPort = choosePort(1820)
        let proxyPort = choosePort(1821)
        let payload = buildLargeAsciiPayload()

        let upstream = App(config: Config())
        upstream.get("/up/stream-unknown", { ctx =>
            let stream = ProxySendStreamBytesInput(toProxyByteArray(payload.toArray()))
            _ = ctx.sendStream(stream, contentType: "text/plain; charset=utf-8")
        })

        let proxy = App(config: Config())
        proxy.use(proxyObserveHeaderMiddleware())
        proxy.use(proxyMiddleware(
            ProxyConfig(
                "http://127.0.0.1:${upstreamPort}",
                pathRewrite: [("/proxy", "/up")]
            )
        ))

        let upstreamFuture = spawn {
            upstream.listen("127.0.0.1", upstreamPort)
        }
        let proxyFuture = spawn {
            proxy.listen("127.0.0.1", proxyPort)
        }

        try {
            let resp = sendRequestWithRetry(
                "GET",
                "http://127.0.0.1:${proxyPort}/proxy/stream-unknown"
            )
            @Assert(resp.status, UInt16(200))
            @Assert(resp.bodyText, payload)
            @Assert(resp.contentType, "text/plain; charset=utf-8")
            @Assert(resp.contentLength, payload.size.toString())
            @Assert(resp.proxyRequestBodyMode, "known-length-stream")
            @Assert(resp.proxyRequestBodyBytes, "0")
            @Assert(resp.proxyResponseBodyMode, "unknown-length-stream")
            @Assert(resp.proxyResponseBodyBytes, "")
            @Assert(resp.proxyDownstreamBodyMode, "http11-chunked")
            @Assert(resp.proxyDownstreamBodyBytes, "")
        } finally {
            shutdownApp(upstream, upstreamFuture)
            shutdownApp(proxy, proxyFuture)
        }
    }

    @TestCase
    public func testProxyMiddlewareRelaysUnknownLengthResponseAsChunkedOnHttp11Wire(): Unit {
        let upstreamPort = choosePort(1825)
        let proxyPort = choosePort(1826)
        let payload = buildLargeAsciiPayload()

        let upstream = App(config: Config())
        upstream.get("/up/stream-unknown-wire", { ctx =>
            let stream = ProxySendStreamBytesInput(toProxyByteArray(payload.toArray()))
            _ = ctx.sendStream(stream, contentType: "text/plain; charset=utf-8")
        })

        let proxy = App(config: Config())
        proxy.use(proxyObserveHeaderMiddleware())
        proxy.use(proxyMiddleware(
            ProxyConfig(
                "http://127.0.0.1:${upstreamPort}",
                pathRewrite: [("/proxy", "/up")]
            )
        ))

        let upstreamFuture = spawn {
            upstream.listen("127.0.0.1", upstreamPort)
        }
        let proxyFuture = spawn {
            proxy.listen("127.0.0.1", proxyPort)
        }

        try {
            let resp = sendRawProxyHttpWithRetry(proxyPort, "GET", "/proxy/stream-unknown-wire", [])
            @Assert(resp.status, UInt16(200))
            @Assert(resp.header("content-type") ?? "", "text/plain; charset=utf-8")
            @Assert(resp.header("content-length") ?? "", "")
            @Assert(resp.header("transfer-encoding") ?? "", "chunked")
            @Assert(resp.header(IGNITE_PROXY_RESPONSE_BODY_MODE_HEADER) ?? "", "unknown-length-stream")
            @Assert(resp.header(IGNITE_PROXY_RESPONSE_BODY_BYTES_HEADER) ?? "", "")
            @Assert(resp.header(IGNITE_PROXY_DOWNSTREAM_BODY_MODE_HEADER) ?? "", "http11-chunked")
            @Assert(resp.header(IGNITE_PROXY_DOWNSTREAM_BODY_BYTES_HEADER) ?? "", "")
            @Assert(resp.bodyText, payload)
        } finally {
            shutdownApp(upstream, upstreamFuture)
            shutdownApp(proxy, proxyFuture)
        }
    }

    @TestCase
    public func testProxyMiddlewareRelaysHeadWithoutBodyOnHttp11Wire(): Unit {
        let upstreamPort = choosePort(1827)
        let proxyPort = choosePort(1828)
        let payload = buildLargeAsciiPayload()

        let upstream = App(config: Config())
        upstream.head("/up/head-wire", { ctx =>
            let stream = ProxySendStreamBytesInput(toProxyByteArray(payload.toArray()))
            _ = ctx.sendStream(
                stream,
                contentType: "application/octet-stream",
                contentLength: Some(payload.size)
            )
        })

        let proxy = App(config: Config())
        proxy.use(proxyObserveHeaderMiddleware())
        proxy.use(proxyMiddleware(
            ProxyConfig(
                "http://127.0.0.1:${upstreamPort}",
                pathRewrite: [("/proxy", "/up")]
            )
        ))

        let upstreamFuture = spawn {
            upstream.listen("127.0.0.1", upstreamPort)
        }
        let proxyFuture = spawn {
            proxy.listen("127.0.0.1", proxyPort)
        }

        try {
            let resp = sendRawProxyHttpWithRetry(proxyPort, "HEAD", "/proxy/head-wire", [])
            @Assert(resp.status, UInt16(200))
            @Assert(resp.header("content-type") ?? "", "application/octet-stream")
            @Assert(resp.header("content-length") ?? "", payload.size.toString())
            @Assert(resp.header("transfer-encoding") ?? "", "")
            @Assert(resp.header(IGNITE_PROXY_RESPONSE_BODY_MODE_HEADER) ?? "", "bodyless")
            @Assert(resp.header(IGNITE_PROXY_RESPONSE_BODY_BYTES_HEADER) ?? "", "0")
            @Assert(resp.header(IGNITE_PROXY_DOWNSTREAM_BODY_MODE_HEADER) ?? "", "bodyless")
            @Assert(resp.header(IGNITE_PROXY_DOWNSTREAM_BODY_BYTES_HEADER) ?? "", "0")
            @Assert(resp.bodyText, "")
        } finally {
            shutdownApp(upstream, upstreamFuture)
            shutdownApp(proxy, proxyFuture)
        }
    }

    @TestCase
    public func testProxyMiddlewareMarksHeadRelayAsBodylessResponse(): Unit {
        let upstreamPort = choosePort(1822)
        let proxyPort = choosePort(1824)
        let payload = buildLargeAsciiPayload()

        let upstream = App(config: Config())
        upstream.head("/up/head-stream", { ctx =>
            let stream = ProxySendStreamBytesInput(toProxyByteArray(payload.toArray()))
            _ = ctx.sendStream(
                stream,
                contentType: "application/octet-stream",
                contentLength: Some(payload.size)
            )
        })

        let proxy = App(config: Config())
        proxy.use(proxyObserveHeaderMiddleware())
        proxy.use(proxyMiddleware(
            ProxyConfig(
                "http://127.0.0.1:${upstreamPort}",
                pathRewrite: [("/proxy", "/up")]
            )
        ))

        let upstreamFuture = spawn {
            upstream.listen("127.0.0.1", upstreamPort)
        }
        let proxyFuture = spawn {
            proxy.listen("127.0.0.1", proxyPort)
        }

        try {
            let resp = sendRequestWithRetry(
                "HEAD",
                "http://127.0.0.1:${proxyPort}/proxy/head-stream"
            )
            @Assert(resp.status, UInt16(200))
            @Assert(resp.bodyText, "")
            @Assert(resp.contentType, "application/octet-stream")
            @Assert(resp.contentLength, payload.size.toString())
            @Assert(resp.proxyRequestBodyMode, "known-length-stream")
            @Assert(resp.proxyRequestBodyBytes, "0")
            @Assert(resp.proxyResponseBodyMode, "bodyless")
            @Assert(resp.proxyResponseBodyBytes, "0")
            @Assert(resp.proxyDownstreamBodyMode, "bodyless")
            @Assert(resp.proxyDownstreamBodyBytes, "0")
        } finally {
            shutdownApp(upstream, upstreamFuture)
            shutdownApp(proxy, proxyFuture)
        }
    }

    @TestCase
    public func testProxyMiddlewareBuffersUnknownLengthUploadToFileWhenRequested(): Unit {
        let upstreamPort = choosePort(1823)
        let proxyPort = choosePort(1829)
        let fixturePath = "/tmp/ignite_proxy_chunked_upload_fixture.txt"
        let payload = buildLargeAsciiPayload()

        let upstream = App(config: Config(bodyLimit: 8 * 1024 * 1024))
        upstream.post("/up/chunked", { ctx =>
            let saved = ctx.saveBodyToFile(fixturePath)
            let contentLength = ctx.header("content-length") ?? ""
            let transferEncoding = ctx.header("transfer-encoding") ?? ""
            _ = ctx.status(201).sendString(
                "saved=${saved};content-length=${contentLength};transfer-encoding=${transferEncoding}"
            )
        })

        let proxy = App(config: Config(bodyLimit: 8 * 1024 * 1024))
        proxy.use(proxyObserveHeaderMiddleware())
        proxy.use(proxyMiddleware(
            ProxyConfig(
                "http://127.0.0.1:${upstreamPort}",
                pathRewrite: [("/proxy", "/up")],
                bufferUnknownLengthBodyToFile: true
            )
        ))

        let upstreamFuture = spawn {
            upstream.listen("127.0.0.1", upstreamPort)
        }
        let proxyFuture = spawn {
            proxy.listen("127.0.0.1", proxyPort)
        }

        try {
            let resp = sendChunkedRequestWithRetry(
                proxyPort,
                "/proxy/chunked",
                payload,
                headers: [("content-type", "text/plain; charset=utf-8")]
            )
            @Assert(resp.status, UInt16(201))
            @Assert(contains(resp.bodyText, "saved=${payload.size}"), true)
            @Assert(contains(resp.bodyText, "content-length=${payload.size}"), true)
            @Assert(contains(resp.bodyText, "transfer-encoding=chunked"), false)
            @Assert(resp.proxyRequestBodyMode, "temp-file-buffered")
            @Assert(resp.proxyRequestBodyBytes, payload.size.toString())
            @Assert(resp.proxyRequestBodyLimitBytes, "")
            @Assert(resp.proxyResponseBodyMode, "known-length-stream")
            @Assert(resp.proxyResponseBodyBytes, resp.bodyText.size.toString())
            @Assert(resp.proxyDownstreamBodyMode, "known-length-stream")
            @Assert(resp.proxyDownstreamBodyBytes, resp.bodyText.size.toString())
            @Assert(readTextFile(fixturePath), payload)
        } finally {
            shutdownApp(upstream, upstreamFuture)
            shutdownApp(proxy, proxyFuture)
        }
    }

    @TestCase
    public func testProxyMiddlewareCreatesConfiguredTempDirAndCleansConcurrentBufferedUploads(): Unit {
        let upstreamPort = choosePort(1830)
        let proxyPort = choosePort(1836)
        let tempRoot = "/tmp/ignite_proxy_buffered_upload_dir_${proxyPort}"
        let tempDir = tempRoot + "/nested/body"
        let payload = buildLargeAsciiPayload()

        _ = removeIfExists(tempRoot, recursive: true)
        @Assert(exists(tempDir), false)

        let upstream = App(config: Config(bodyLimit: 8 * 1024 * 1024))
        upstream.post("/up/chunked-concurrent", { ctx =>
            let saved = ctx.bodyBytes().size
            let contentLength = ctx.header("content-length") ?? ""
            let transferEncoding = ctx.header("transfer-encoding") ?? ""
            _ = ctx.status(201).sendString(
                "saved=${saved};content-length=${contentLength};transfer-encoding=${transferEncoding}"
            )
        })

        let proxy = App(config: Config(bodyLimit: 8 * 1024 * 1024))
        proxy.use(proxyObserveHeaderMiddleware())
        proxy.use(proxyMiddleware(
            ProxyConfig(
                "http://127.0.0.1:${upstreamPort}",
                pathRewrite: [("/proxy", "/up")],
                bufferUnknownLengthBodyToFile: true,
                unknownLengthBodyTempDir: tempDir
            )
        ))

        let upstreamFuture = spawn {
            upstream.listen("127.0.0.1", upstreamPort)
        }
        let proxyFuture = spawn {
            proxy.listen("127.0.0.1", proxyPort)
        }

        try {
            let requestCount: Int64 = 4
            let futures = ArrayList<Future<ProxyResponseSnapshot>>()
            var i: Int64 = 0
            while (i < requestCount) {
                futures.add(spawn {
                    sendChunkedRequestWithRetry(
                        proxyPort,
                        "/proxy/chunked-concurrent",
                        payload,
                        headers: [("content-type", "text/plain; charset=utf-8")]
                    )
                })
                i += 1
            }

            for (future in futures) {
                let resp = future.get(Duration.second * 5)
                @Assert(resp.status, UInt16(201))
                @Assert(contains(resp.bodyText, "saved=${payload.size}"), true)
                @Assert(contains(resp.bodyText, "content-length=${payload.size}"), true)
                @Assert(contains(resp.bodyText, "transfer-encoding=chunked"), false)
                @Assert(resp.proxyRequestBodyMode, "temp-file-buffered")
                @Assert(resp.proxyRequestBodyBytes, payload.size.toString())
                @Assert(resp.proxyResponseBodyMode, "known-length-stream")
                @Assert(resp.proxyDownstreamBodyMode, "known-length-stream")
            }

            @Assert(exists(tempDir), true)
            @Assert(Directory.isEmpty(tempDir), true)
        } finally {
            shutdownApp(upstream, upstreamFuture)
            shutdownApp(proxy, proxyFuture)
            _ = removeIfExists(tempRoot, recursive: true)
        }
    }

    @TestCase
    public func testProxyMiddlewareUsesTmpdirEnvForBufferedUnknownLengthUploadByDefault(): Unit {
        let upstreamPort = choosePort(1832)
        let proxyPort = choosePort(1833)
        let tempRoot = "/tmp/ignite_proxy_tmpdir_env_${proxyPort}"
        let tempDir = tempRoot + "/env-body"
        let payload = buildLargeAsciiPayload()
        let envSnapshot = snapshotProxyTempEnv()

        _ = removeIfExists(tempRoot, recursive: true)
        applyProxyTempEnv(Some(tempDir), None, None)

        let upstream = App(config: Config(bodyLimit: 8 * 1024 * 1024))
        upstream.post("/up/chunked-env", { ctx =>
            let saved = ctx.bodyBytes().size
            let contentLength = ctx.header("content-length") ?? ""
            _ = ctx.status(201).sendString("saved=${saved};content-length=${contentLength}")
        })

        let proxy = App(config: Config(bodyLimit: 8 * 1024 * 1024))
        proxy.use(proxyObserveHeaderMiddleware())
        proxy.use(proxyMiddleware(
            ProxyConfig(
                "http://127.0.0.1:${upstreamPort}",
                pathRewrite: [("/proxy", "/up")],
                bufferUnknownLengthBodyToFile: true
            )
        ))

        let upstreamFuture = spawn {
            upstream.listen("127.0.0.1", upstreamPort)
        }
        let proxyFuture = spawn {
            proxy.listen("127.0.0.1", proxyPort)
        }

        try {
            let resp = sendChunkedRequestWithRetry(
                proxyPort,
                "/proxy/chunked-env",
                payload,
                headers: [("content-type", "text/plain; charset=utf-8")]
            )
            @Assert(resp.status, UInt16(201))
            @Assert(contains(resp.bodyText, "saved=${payload.size}"), true)
            @Assert(contains(resp.bodyText, "content-length=${payload.size}"), true)
            @Assert(resp.proxyRequestBodyMode, "temp-file-buffered")
            @Assert(resp.proxyRequestBodyBytes, payload.size.toString())
            @Assert(exists(tempDir), true)
            @Assert(Directory.isEmpty(tempDir), true)
        } finally {
            shutdownApp(upstream, upstreamFuture)
            shutdownApp(proxy, proxyFuture)
            restoreProxyTempEnv(envSnapshot)
            _ = removeIfExists(tempRoot, recursive: true)
        }
    }

    @TestCase
    public func testProxyMiddlewarePrefersExplicitTempDirOverEnvDefault(): Unit {
        let upstreamPort = choosePort(1834)
        let proxyPort = choosePort(1835)
        let envRoot = "/tmp/ignite_proxy_env_dir_${proxyPort}"
        let explicitRoot = "/tmp/ignite_proxy_explicit_dir_${proxyPort}"
        let envDir = envRoot + "/env-body"
        let explicitDir = explicitRoot + "/explicit-body"
        let payload = buildLargeAsciiPayload()
        let envSnapshot = snapshotProxyTempEnv()

        _ = removeIfExists(envRoot, recursive: true)
        _ = removeIfExists(explicitRoot, recursive: true)
        applyProxyTempEnv(Some(envDir), None, None)

        let upstream = App(config: Config(bodyLimit: 8 * 1024 * 1024))
        upstream.post("/up/chunked-explicit", { ctx =>
            let saved = ctx.bodyBytes().size
            let contentLength = ctx.header("content-length") ?? ""
            _ = ctx.status(201).sendString("saved=${saved};content-length=${contentLength}")
        })

        let proxy = App(config: Config(bodyLimit: 8 * 1024 * 1024))
        proxy.use(proxyObserveHeaderMiddleware())
        proxy.use(proxyMiddleware(
            ProxyConfig(
                "http://127.0.0.1:${upstreamPort}",
                pathRewrite: [("/proxy", "/up")],
                bufferUnknownLengthBodyToFile: true,
                unknownLengthBodyTempDir: explicitDir
            )
        ))

        let upstreamFuture = spawn {
            upstream.listen("127.0.0.1", upstreamPort)
        }
        let proxyFuture = spawn {
            proxy.listen("127.0.0.1", proxyPort)
        }

        try {
            let resp = sendChunkedRequestWithRetry(
                proxyPort,
                "/proxy/chunked-explicit",
                payload,
                headers: [("content-type", "text/plain; charset=utf-8")]
            )
            @Assert(resp.status, UInt16(201))
            @Assert(contains(resp.bodyText, "saved=${payload.size}"), true)
            @Assert(contains(resp.bodyText, "content-length=${payload.size}"), true)
            @Assert(resp.proxyRequestBodyMode, "temp-file-buffered")
            @Assert(resp.proxyRequestBodyBytes, payload.size.toString())
            @Assert(exists(explicitDir), true)
            @Assert(Directory.isEmpty(explicitDir), true)
            @Assert(exists(envDir), false)
        } finally {
            shutdownApp(upstream, upstreamFuture)
            shutdownApp(proxy, proxyFuture)
            restoreProxyTempEnv(envSnapshot)
            _ = removeIfExists(envRoot, recursive: true)
            _ = removeIfExists(explicitRoot, recursive: true)
        }
    }

    @TestCase
    public func testProxyMiddlewareRejectsBufferedUnknownLengthUploadOverLimit(): Unit {
        let upstreamPort = choosePort(1831)
        let proxyPort = choosePort(1837)
        let fixturePath = "/tmp/ignite_proxy_chunked_upload_over_limit.txt"
        let payload = buildLargeAsciiPayload()
        let hits = ArrayList<String>()

        let upstream = App(config: Config(bodyLimit: 8 * 1024 * 1024))
        upstream.post("/up/chunked-limit", { ctx =>
            hits.add("hit")
            let saved = ctx.saveBodyToFile(fixturePath)
            _ = ctx.status(201).sendString("saved=${saved}")
        })

        let proxy = App(config: Config(bodyLimit: 8 * 1024 * 1024))
        proxy.use(proxyObserveHeaderMiddleware())
        proxy.use(proxyMiddleware(
            ProxyConfig(
                "http://127.0.0.1:${upstreamPort}",
                pathRewrite: [("/proxy", "/up")],
                bufferUnknownLengthBodyToFile: true,
                maxBufferedBodyBytes: payload.size / 2
            )
        ))

        let upstreamFuture = spawn {
            upstream.listen("127.0.0.1", upstreamPort)
        }
        let proxyFuture = spawn {
            proxy.listen("127.0.0.1", proxyPort)
        }

        try {
            let resp = sendChunkedRequestWithRetry(
                proxyPort,
                "/proxy/chunked-limit",
                payload,
                headers: [("content-type", "text/plain; charset=utf-8")]
            )
            @Assert(resp.status, UInt16(413))
            @Assert(contains(resp.bodyText, "exceeds limit"), true)
            @Assert(resp.proxyRequestBodyMode, "temp-file-buffered-over-limit")
            @Assert(resp.proxyRequestBodyLimitBytes, (payload.size / 2).toString())
            @Assert(parseProxyDecimalInt64(resp.proxyRequestBodyBytes) > (payload.size / 2), true)
            @Assert(resp.proxyResponseBodyMode, "known-length-stream")
            @Assert(resp.proxyResponseBodyBytes, resp.bodyText.size.toString())
            @Assert(resp.proxyDownstreamBodyMode, "known-length-stream")
            @Assert(resp.proxyDownstreamBodyBytes, resp.bodyText.size.toString())
            @Assert(hits.size, 0)
            @Assert(exists(fixturePath), false)
        } finally {
            shutdownApp(upstream, upstreamFuture)
            shutdownApp(proxy, proxyFuture)
        }
    }

    @TestCase
    public func testProxyMiddlewareUsesTempFileFallbackForUnknownLengthUploadToHttpsTarget(): Unit {
        let upstreamPort = choosePort(1844)
        let proxyPort = choosePort(1845)
        let tempRoot = "/tmp/ignite_proxy_https_unknown_length_${proxyPort}"
        let tempDir = tempRoot + "/https-body"
        let payload = buildLargeAsciiPayload()

        _ = removeIfExists(tempRoot, recursive: true)

        let proxy = App(config: Config(bodyLimit: 8 * 1024 * 1024))
        proxy.use(proxyObserveHeaderMiddleware())
        proxy.use(proxyMiddleware(
            ProxyConfig(
                "https://127.0.0.1:${upstreamPort}",
                unknownLengthBodyTempDir: tempDir
            )
        ))

        let proxyFuture = spawn {
            proxy.listen("127.0.0.1", proxyPort)
        }

        try {
            let resp = sendChunkedRequestWithRetry(
                proxyPort,
                "/proxy/https-fallback",
                payload,
                headers: [("content-type", "text/plain; charset=utf-8")]
            )
            @Assert(resp.status, UInt16(502))
            @Assert(contains(resp.bodyText, "Bad Gateway:"), true)
            @Assert(resp.proxyRequestBodyMode, "temp-file-buffered")
            @Assert(resp.proxyRequestBodyBytes, payload.size.toString())
            @Assert(resp.proxyRequestBodyLimitBytes, "")
            @Assert(resp.proxyResponseBodyMode, "known-length-stream")
            @Assert(resp.proxyResponseBodyBytes, resp.bodyText.size.toString())
            @Assert(resp.proxyDownstreamBodyMode, "known-length-stream")
            @Assert(resp.proxyDownstreamBodyBytes, resp.bodyText.size.toString())
            @Assert(exists(tempDir), true)
            @Assert(Directory.isEmpty(tempDir), true)
        } finally {
            shutdownApp(proxy, proxyFuture)
            _ = removeIfExists(tempRoot, recursive: true)
        }
    }

    @TestCase
    public func testProxyMiddlewareRejectsHttpsUnknownLengthUploadWhenBufferedTempFileExceedsLimit(): Unit {
        let upstreamPort = choosePort(1846)
        let proxyPort = choosePort(1850)
        let tempRoot = "/tmp/ignite_proxy_https_unknown_length_limit_${proxyPort}"
        let tempDir = tempRoot + "/https-body"
        let payload = buildLargeAsciiPayload()

        _ = removeIfExists(tempRoot, recursive: true)

        let proxy = App(config: Config(bodyLimit: 8 * 1024 * 1024))
        proxy.use(proxyObserveHeaderMiddleware())
        proxy.use(proxyMiddleware(
            ProxyConfig(
                "https://127.0.0.1:${upstreamPort}",
                unknownLengthBodyTempDir: tempDir,
                maxBufferedBodyBytes: payload.size / 2
            )
        ))

        let proxyFuture = spawn {
            proxy.listen("127.0.0.1", proxyPort)
        }

        try {
            let resp = sendChunkedRequestWithRetry(
                proxyPort,
                "/proxy/https-fallback-limit",
                payload,
                headers: [("content-type", "text/plain; charset=utf-8")]
            )
            @Assert(resp.status, UInt16(413))
            @Assert(contains(resp.bodyText, "exceeds limit"), true)
            @Assert(resp.proxyRequestBodyMode, "temp-file-buffered-over-limit")
            @Assert(resp.proxyRequestBodyLimitBytes, (payload.size / 2).toString())
            @Assert(parseProxyDecimalInt64(resp.proxyRequestBodyBytes) > (payload.size / 2), true)
            @Assert(resp.proxyResponseBodyMode, "known-length-stream")
            @Assert(resp.proxyResponseBodyBytes, resp.bodyText.size.toString())
            @Assert(resp.proxyDownstreamBodyMode, "known-length-stream")
            @Assert(resp.proxyDownstreamBodyBytes, resp.bodyText.size.toString())
            @Assert(exists(tempDir), true)
            @Assert(Directory.isEmpty(tempDir), true)
        } finally {
            shutdownApp(proxy, proxyFuture)
            _ = removeIfExists(tempRoot, recursive: true)
        }
    }

    @TestCase
    public func testProxyMiddlewareObservesLocalBadGatewayResponse(): Unit {
        let upstreamPort = choosePort(1843)
        let proxyPort = choosePort(1847)

        let proxy = App(config: Config())
        proxy.use(proxyObserveHeaderMiddleware())
        proxy.use(proxyMiddleware(
            ProxyConfig(
                "http://127.0.0.1:${upstreamPort}",
                pathRewrite: [("/proxy", "/up")]
            )
        ))

        let proxyFuture = spawn {
            proxy.listen("127.0.0.1", proxyPort)
        }

        try {
            let resp = sendRequestWithRetry(
                "GET",
                "http://127.0.0.1:${proxyPort}/proxy/missing-upstream"
            )
            @Assert(resp.status, UInt16(502))
            @Assert(contains(resp.bodyText, "Bad Gateway:"), true)
            @Assert(resp.proxyRequestBodyMode, "known-length-stream")
            @Assert(resp.proxyRequestBodyBytes, "0")
            @Assert(resp.proxyResponseBodyMode, "known-length-stream")
            @Assert(resp.proxyResponseBodyBytes, resp.bodyText.size.toString())
            @Assert(resp.proxyDownstreamBodyMode, "known-length-stream")
            @Assert(resp.proxyDownstreamBodyBytes, resp.bodyText.size.toString())
        } finally {
            shutdownApp(proxy, proxyFuture)
        }
    }

    @TestCase
    public func testProxyMiddlewareUsesKnownLengthForLocalBadGatewayOnHttp11Wire(): Unit {
        let upstreamPort = choosePort(1848)
        let proxyPort = choosePort(1849)

        let proxy = App(config: Config())
        proxy.use(proxyObserveHeaderMiddleware())
        proxy.use(proxyMiddleware(
            ProxyConfig(
                "http://127.0.0.1:${upstreamPort}",
                pathRewrite: [("/proxy", "/up")]
            )
        ))

        let proxyFuture = spawn {
            proxy.listen("127.0.0.1", proxyPort)
        }

        try {
            let resp = sendRawProxyHttpWithRetry(proxyPort, "GET", "/proxy/missing-upstream-wire", [])
            @Assert(resp.status, UInt16(502))
            @Assert(contains(resp.bodyText, "Bad Gateway:"), true)
            @Assert(resp.header("content-length") ?? "", resp.bodyText.size.toString())
            @Assert(resp.header("transfer-encoding") ?? "", "")
            @Assert(resp.header(IGNITE_PROXY_RESPONSE_BODY_MODE_HEADER) ?? "", "known-length-stream")
            @Assert(resp.header(IGNITE_PROXY_RESPONSE_BODY_BYTES_HEADER) ?? "", resp.bodyText.size.toString())
            @Assert(resp.header(IGNITE_PROXY_DOWNSTREAM_BODY_MODE_HEADER) ?? "", "known-length-stream")
            @Assert(resp.header(IGNITE_PROXY_DOWNSTREAM_BODY_BYTES_HEADER) ?? "", resp.bodyText.size.toString())
        } finally {
            shutdownApp(proxy, proxyFuture)
        }
    }

    func sendRequestWithRetry(
        method: String,
        url: String,
        body!: String = "",
        headers!: Array<(String, String)> = []
    ): ProxyResponseSnapshot {
        let client = RestClient(
            readTimeout: Duration.second * 2,
            writeTimeout: Duration.second * 2,
            poolSize: 2
        )
        var attempt: Int64 = 0
        try {
            while (attempt < 20) {
                try {
                    let request = client.request()
                        .method(method)
                        .url(url)
                    for ((key, value) in headers) {
                        request.header(key, value)
                    }
                    if (body.size > 0) {
                        request.body(body)
                    }
                    let resp = request.send()
                    let payload = resp.bodyBytes()
                    return ProxyResponseSnapshot(
                        resp.status,
                        String.fromUtf8(payload),
                        resp.header("content-type") ?? "",
                        resp.header("content-length") ?? "",
                        resp.header("accept-ranges") ?? "",
                        resp.header("x-upstream") ?? "",
                        resp.header(IGNITE_PROXY_REQUEST_BODY_MODE_HEADER) ?? "",
                        resp.header(IGNITE_PROXY_REQUEST_BODY_BYTES_HEADER) ?? "",
                        resp.header(IGNITE_PROXY_REQUEST_BODY_LIMIT_BYTES_HEADER) ?? "",
                        resp.header(IGNITE_PROXY_RESPONSE_BODY_MODE_HEADER) ?? "",
                        resp.header(IGNITE_PROXY_RESPONSE_BODY_BYTES_HEADER) ?? "",
                        resp.header(IGNITE_PROXY_DOWNSTREAM_BODY_MODE_HEADER) ?? "",
                        resp.header(IGNITE_PROXY_DOWNSTREAM_BODY_BYTES_HEADER) ?? ""
                    )
                } catch (_: Exception) {
                    if (attempt == 19) {
                        throw Exception("failed to connect test server: ${url}")
                    }
                    sleep(Duration.millisecond * 50)
                    attempt += 1
                }
            }
        } finally {
            client.close()
        }
        throw Exception("failed to connect test server: ${url}")
    }

    func sendChunkedRequestWithRetry(
        port: UInt16,
        target: String,
        body: String,
        headers!: Array<(String, String)> = []
    ): ProxyResponseSnapshot {
        var attempt: Int64 = 0
        while (attempt < 20) {
            try {
                return sendChunkedRequest(port, target, body, headers: headers)
            } catch (_: Exception) {
                if (attempt == 19) {
                    throw Exception("failed to connect chunked proxy test server: ${port} ${target}")
                }
                sleep(Duration.millisecond * 50)
                attempt += 1
            }
        }
        throw Exception("failed to connect chunked proxy test server: ${port} ${target}")
    }

    func sendChunkedRequest(
        port: UInt16,
        target: String,
        body: String,
        headers!: Array<(String, String)> = []
    ): ProxyResponseSnapshot {
        let socket = TcpSocket(IPSocketAddress.parse("127.0.0.1:${port}"))
        socket.connect()
        try {
            var request = "POST ${target} HTTP/1.1\r\n"
            request += "host: 127.0.0.1:${port}\r\n"
            request += "transfer-encoding: chunked\r\n"
            request += "connection: close\r\n"
            for ((key, value) in headers) {
                request += "${key}: ${value}\r\n"
            }
            request += "\r\n"
            socket.write(request.toArray())
            writeChunkedBody(socket, body)

            let buf = Array<UInt8>(4096, repeat: 0)
            var raw = ""
            while (true) {
                let n = socket.read(buf)
                if (n <= 0) {
                    break
                }
                raw += String.fromUtf8(buf[..n])
            }
            parseRawProxyResponse(raw)
        } finally {
            socket.close()
        }
    }

    func sendRawProxyHttpWithRetry(
        port: UInt16,
        method: String,
        target: String,
        headers: Array<(String, String)>
    ): ProxyRawHttpResponse {
        var attempt: Int64 = 0
        while (attempt < 20) {
            try {
                return sendRawProxyHttp(port, method, target, headers)
            } catch (_: Exception) {
                if (attempt == 19) {
                    throw Exception("failed to connect raw proxy test server: ${port} ${target}")
                }
                sleep(Duration.millisecond * 50)
                attempt += 1
            }
        }
        throw Exception("failed to connect raw proxy test server: ${port} ${target}")
    }

    func sendRawProxyHttp(
        port: UInt16,
        method: String,
        target: String,
        headers: Array<(String, String)>
    ): ProxyRawHttpResponse {
        let socket = TcpSocket(IPSocketAddress.parse("127.0.0.1:${port}"))
        socket.connect()
        try {
            var request = "${method} ${target} HTTP/1.1\r\n"
            request += "host: 127.0.0.1:${port}\r\n"
            for ((key, value) in headers) {
                request += "${key}: ${value}\r\n"
            }
            request += "connection: close\r\n\r\n"
            socket.write(request.toArray())

            let buf = Array<UInt8>(4096, repeat: 0)
            var raw = ""
            while (true) {
                let n = socket.read(buf)
                if (n <= 0) {
                    break
                }
                raw += String.fromUtf8(buf[..n])
            }
            parseRawProxyWireResponse(raw)
        } finally {
            socket.close()
        }
    }

    func shutdownApp(app: App, future: Future<Unit>): Unit {
        app.shutdown()
        try {
            let _ = future.get(Duration.second * 1)
        } catch (_: Exception) {
            future.cancel()
        }
    }

    func choosePort(offset: Int64): UInt16 {
        let nowMs = DateTime.now().toUnixTimeStamp().toMilliseconds()
        let raw = 43000 + ((nowMs + offset) % 10000)
        UInt16(raw)
    }

    func snapshotProxyTempEnv(): ProxyTempEnvSnapshot {
        ProxyTempEnvSnapshot(
            getVariable("TMPDIR"),
            getVariable("TEMP"),
            getVariable("TMP")
        )
    }

    func restoreProxyTempEnv(snapshot: ProxyTempEnvSnapshot): Unit {
        applyProxyTempEnv(snapshot.tmpdir, snapshot.temp, snapshot.tmp)
    }

    func applyProxyTempEnv(tmpdir: ?String, temp: ?String, tmp: ?String): Unit {
        applyProxyEnvVar("TMPDIR", tmpdir)
        applyProxyEnvVar("TEMP", temp)
        applyProxyEnvVar("TMP", tmp)
    }

    func applyProxyEnvVar(key: String, value: ?String): Unit {
        match (value) {
            case Some(text) => setVariable(key, text)
            case None =>
                try {
                    removeVariable(key)
                } catch (_: Exception) { }
        }
    }

    func buildLargeAsciiPayload(): String {
        let line = "ignite-proxy-streaming-regression-0123456789-ABCDEFGHIJKLMNOPQRSTUVWXYZ\n"
        var out = ""
        var i: Int64 = 0
        while (i < 4096) {
            out += line
            i += 1
        }
        out
    }

    func writeTextFile(path: String, body: String): Unit {
        let file = File(path, OpenMode.Write)
        file.write(body.toArray())
        file.close()
    }

    func readTextFile(path: String): String {
        let file = File(path, OpenMode.Read)
        let buf = ArrayList<UInt8>()
        let tmp = Array<UInt8>(4096, repeat: 0)
        while (true) {
            let n = file.read(tmp)
            if (n <= 0) {
                break
            }
            for (i in 0..n) {
                buf.add(tmp[i])
            }
        }
        file.close()
        String.fromUtf8(buf.toArray())
    }

    func writeChunkedBody(socket: TcpSocket, body: String): Unit {
        let bytes = body.toArray()
        var index: Int64 = 0
        let chunkSize: Int64 = 2048
        while (index < bytes.size) {
            let end = if (index + chunkSize < bytes.size) { index + chunkSize } else { bytes.size }
            let chunk = bytes[index..end]
            let header = int64ToHex(chunk.size) + "\r\n"
            socket.write(header.toArray())
            socket.write(chunk)
            socket.write("\r\n".toArray())
            index = end
        }
        socket.write("0\r\n\r\n".toArray())
    }

    func parseRawProxyResponse(raw: String): ProxyResponseSnapshot {
        let wire = parseRawProxyWireResponse(raw)
        ProxyResponseSnapshot(
            wire.status,
            wire.bodyText,
            wire.header("content-type") ?? "",
            wire.header("content-length") ?? "",
            wire.header("accept-ranges") ?? "",
            wire.header("x-upstream") ?? "",
            wire.header(IGNITE_PROXY_REQUEST_BODY_MODE_HEADER) ?? "",
            wire.header(IGNITE_PROXY_REQUEST_BODY_BYTES_HEADER) ?? "",
            wire.header(IGNITE_PROXY_REQUEST_BODY_LIMIT_BYTES_HEADER) ?? "",
            wire.header(IGNITE_PROXY_RESPONSE_BODY_MODE_HEADER) ?? "",
            wire.header(IGNITE_PROXY_RESPONSE_BODY_BYTES_HEADER) ?? "",
            wire.header(IGNITE_PROXY_DOWNSTREAM_BODY_MODE_HEADER) ?? "",
            wire.header(IGNITE_PROXY_DOWNSTREAM_BODY_BYTES_HEADER) ?? ""
        )
    }

    func parseRawProxyWireResponse(raw: String): ProxyRawHttpResponse {
        let splitIdx = indexOfProxyText(raw, "\r\n\r\n")
        let headerText = if (splitIdx >= 0) { raw[..splitIdx] } else { raw }
        let rawBody = if (splitIdx >= 0) { raw[splitIdx + 4..raw.size] } else { "" }
        let lines = headerText.split("\r\n")
        if (lines.size == 0) {
            throw Exception("raw proxy response missing status line")
        }

        let status = parseProxyStatusCode(lines[0])
        let headers = HashMap<String, String>()
        var i: Int64 = 1
        while (i < lines.size) {
            let line = lines[i]
            let colonIdx = indexOfProxyRune(line, r':')
            if (colonIdx > 0) {
                let key = line[..colonIdx].trimAscii().toAsciiLower()
                let value = line[colonIdx + 1..line.size].trimAscii()
                headers.add(key, value)
            }
            i += 1
        }

        let bodyText = if ((headers.get("transfer-encoding") ?? "") == "chunked") {
            decodeChunkedProxyBody(rawBody)
        } else {
            rawBody
        }
        ProxyRawHttpResponse(status, headers, bodyText)
    }

    func parseProxyStatusCode(statusLine: String): UInt16 {
        let parts = statusLine.split(" ")
        if (parts.size < 2) {
            throw Exception("invalid status line: ${statusLine}")
        }
        let digits = parts[1].trimAscii()
        var value: Int64 = 0
        for (ch in digits.toRuneArray()) {
            if (ch < r'0' || ch > r'9') {
                throw Exception("invalid status code: ${statusLine}")
            }
            value = value * 10 + (Int64(UInt32(ch)) - Int64(UInt32(r'0')))
        }
        UInt16(value)
    }

    func decodeChunkedProxyBody(raw: String): String {
        var idx: Int64 = 0
        var out = ""
        while (idx < raw.size) {
            let lineEnd = indexOfProxyText(raw[idx..raw.size], "\r\n")
            if (lineEnd < 0) {
                throw Exception("invalid chunked response")
            }
            let sizeText = raw[idx..idx + lineEnd].trimAscii()
            let chunkSize = parseProxyHexInt64(sizeText)
            idx += lineEnd + 2
            if (chunkSize == 0) {
                break
            }
            out += raw[idx..idx + chunkSize]
            idx += chunkSize + 2
        }
        out
    }

    func parseProxyHexInt64(text: String): Int64 {
        let trimmed = text.trimAscii().toAsciiLower()
        if (trimmed.size == 0) {
            throw Exception("invalid hex integer")
        }
        var value: Int64 = 0
        for (ch in trimmed.toRuneArray()) {
            let digit = if (ch >= r'0' && ch <= r'9') {
                Int64(UInt32(ch) - UInt32(r'0'))
            } else if (ch >= r'a' && ch <= r'f') {
                Int64(UInt32(ch) - UInt32(r'a')) + 10
            } else {
                throw Exception("invalid hex integer")
            }
            value = value * 16 + digit
        }
        value
    }

    func int64ToHex(value: Int64): String {
        let hex = "0123456789abcdef".toRuneArray()
        if (value < 16) {
            return hex[value].toString()
        }
        int64ToHex(value / 16) + hex[value % 16].toString()
    }

    func parseProxyDecimalInt64(text: String): Int64 {
        let trimmed = text.trimAscii()
        if (trimmed.size == 0) {
            throw Exception("invalid decimal integer")
        }
        var value: Int64 = 0
        for (ch in trimmed.toRuneArray()) {
            if (ch < r'0' || ch > r'9') {
                throw Exception("invalid decimal integer")
            }
            value = value * 10 + (Int64(UInt32(ch)) - Int64(UInt32(r'0')))
        }
        value
    }

    func indexOfProxyText(text: String, target: String): Int64 {
        let a = text.toRuneArray()
        let b = target.toRuneArray()
        if (b.size == 0) { return 0 }
        if (a.size < b.size) { return -1 }
        var i: Int64 = 0
        while (i <= a.size - b.size) {
            var ok = true
            var j: Int64 = 0
            while (j < b.size) {
                if (a[i + j] != b[j]) {
                    ok = false
                    break
                }
                j += 1
            }
            if (ok) { return i }
            i += 1
        }
        -1
    }

    func indexOfProxyRune(text: String, target: Rune): Int64 {
        let runes = text.toRuneArray()
        var i: Int64 = 0
        while (i < runes.size) {
            if (runes[i] == target) {
                return i
            }
            i += 1
        }
        -1
    }

    func contains(text: String, sub: String): Bool {
        let t = text.toRuneArray()
        let p = sub.toRuneArray()
        if (p.size == 0) { return true }
        if (t.size < p.size) { return false }
        var i: Int64 = 0
        while (i <= t.size - p.size) {
            var ok = true
            var j: Int64 = 0
            while (j < p.size) {
                if (t[i + j] != p[j]) {
                    ok = false
                    break
                }
                j += 1
            }
            if (ok) { return true }
            i += 1
        }
        false
    }
}

class ProxyRawHttpResponse {
    let status: UInt16
    let headers: HashMap<String, String>
    let bodyText: String

    init(status: UInt16, headers: HashMap<String, String>, bodyText: String) {
        this.status = status
        this.headers = headers
        this.bodyText = bodyText
    }

    func header(name: String): ?String {
        headers.get(name.trimAscii().toAsciiLower())
    }
}

class ProxyTempEnvSnapshot {
    let tmpdir: ?String
    let temp: ?String
    let tmp: ?String

    public init(tmpdir: ?String, temp: ?String, tmp: ?String) {
        this.tmpdir = tmpdir
        this.temp = temp
        this.tmp = tmp
    }
}

class ProxySendStreamBytesInput <: InputStream {
    let bytes: Array<Byte>
    var cursor: Int64 = 0

    init(bytes: Array<Byte>) {
        this.bytes = bytes
    }

    public override func read(outBuf: Array<Byte>): Int64 {
        if (cursor >= bytes.size || outBuf.size == 0) {
            return 0
        }
        let remaining = bytes.size - cursor
        let readLen = if (remaining < outBuf.size) { remaining } else { outBuf.size }
        for (i in 0..readLen) {
            outBuf[i] = bytes[cursor + i]
        }
        cursor += readLen
        readLen
    }

    public func close(): Unit {}
}

func toProxyByteArray(input: Array<UInt8>): Array<Byte> {
    let out = Array<Byte>(input.size, repeat: 0)
    var i = 0
    while (i < input.size) {
        out[i] = input[i]
        i += 1
    }
    out
}

class ProxyResponseSnapshot {
    let status: UInt16
    let bodyText: String
    let contentType: String
    let contentLength: String
    let acceptRanges: String
    let xUpstream: String
    let proxyRequestBodyMode: String
    let proxyRequestBodyBytes: String
    let proxyRequestBodyLimitBytes: String
    let proxyResponseBodyMode: String
    let proxyResponseBodyBytes: String
    let proxyDownstreamBodyMode: String
    let proxyDownstreamBodyBytes: String

    init(
        status: UInt16,
        bodyText: String,
        contentType: String,
        contentLength: String,
        acceptRanges: String,
        xUpstream: String,
        proxyRequestBodyMode: String,
        proxyRequestBodyBytes: String,
        proxyRequestBodyLimitBytes: String,
        proxyResponseBodyMode: String,
        proxyResponseBodyBytes: String,
        proxyDownstreamBodyMode: String,
        proxyDownstreamBodyBytes: String
    ) {
        this.status = status
        this.bodyText = bodyText
        this.contentType = contentType
        this.contentLength = contentLength
        this.acceptRanges = acceptRanges
        this.xUpstream = xUpstream
        this.proxyRequestBodyMode = proxyRequestBodyMode
        this.proxyRequestBodyBytes = proxyRequestBodyBytes
        this.proxyRequestBodyLimitBytes = proxyRequestBodyLimitBytes
        this.proxyResponseBodyMode = proxyResponseBodyMode
        this.proxyResponseBodyBytes = proxyResponseBodyBytes
        this.proxyDownstreamBodyMode = proxyDownstreamBodyMode
        this.proxyDownstreamBodyBytes = proxyDownstreamBodyBytes
    }
}

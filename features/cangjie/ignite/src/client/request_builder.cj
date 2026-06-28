package ignite.client

import stdx.net.http.{Client, HttpRequestBuilder}
import std.collection.{ArrayList, HashMap}
import std.random.Random
import std.time.MonoTime
import ignite.api2
import ignite.security as security

// ── RequestBuilder ──

public class RequestBuilder {
    let _client: Client
    let _baseUrl: String
    let _defaultHeaders: HashMap<String, String>
    let _cookieStore: ?CookieStore
    let _cryptoConfig: ?api2.ClientCryptoConfig
    let _x509Verify: ?security.X509VerifyOption
    let _retryConfig: ClientRetryConfig
    let _preferredTransportBackendHint: String
    let _allowExperimentalTransport: Bool
    let _requestHooks: ArrayList<ClientRequestHook>
    let _responseHooks: ArrayList<ClientResponseHook>
    let _errorHooks: ArrayList<ClientErrorHook>
    let _observeHooks: ArrayList<ClientObserveHook>
    let _transportTouchpointHooks: ArrayList<ClientTransportTouchpointHook>
    let _captureObserveHook: ?ClientObserveHook
    let _captureTransportTouchpointHook: ?ClientTransportTouchpointHook
    let _builder: HttpRequestBuilder = HttpRequestBuilder()
    let _headerSnapshot: HashMap<String, String> = HashMap<String, String>()
    var _currentUrl: String = ""
    var _methodName: String = "GET"
    var _queryParams: ArrayList<(String, String)> = ArrayList<(String, String)>()
    var _formParams: ?ArrayList<(String, String)> = None
    var _multipartFields: ?ArrayList<(String, String)> = None
    var _multipartFiles: ?ArrayList<MultipartFile> = None
    var _x509VerifyOverride: ?security.X509VerifyOption = None
    var _retryOverride: ?ClientRetryConfig = None
    var _requestCryptoConfig: ?api2.ClientCryptoConfig = None
    var _transportBackendHintOverride: ?String = None
    var _allowExperimentalTransportOverride: ?Bool = None

    public init(
        client: Client,
        baseUrl: String,
        defaultHeaders: HashMap<String, String>,
        cookieStore: ?CookieStore,
        cryptoConfig: ?api2.ClientCryptoConfig,
        x509Verify: ?security.X509VerifyOption,
        retryConfig: ClientRetryConfig,
        preferredTransportBackendHint: String,
        allowExperimentalTransport: Bool,
        requestHooks: ArrayList<ClientRequestHook>,
        responseHooks: ArrayList<ClientResponseHook>,
        errorHooks: ArrayList<ClientErrorHook>,
        observeHooks: ArrayList<ClientObserveHook>,
        transportTouchpointHooks: ArrayList<ClientTransportTouchpointHook>,
        captureObserveHook!: ?ClientObserveHook = None,
        captureTransportTouchpointHook!: ?ClientTransportTouchpointHook = None
    ) {
        _client = client
        _baseUrl = baseUrl
        _defaultHeaders = defaultHeaders
        _cookieStore = cookieStore
        _cryptoConfig = cryptoConfig
        _x509Verify = x509Verify
        _retryConfig = retryConfig.copy()
        _preferredTransportBackendHint = preferredTransportBackendHint
        _allowExperimentalTransport = allowExperimentalTransport
        _requestHooks = ArrayList<ClientRequestHook>()
        _responseHooks = ArrayList<ClientResponseHook>()
        _errorHooks = ArrayList<ClientErrorHook>()
        _observeHooks = ArrayList<ClientObserveHook>()
        _transportTouchpointHooks = ArrayList<ClientTransportTouchpointHook>()
        _captureObserveHook = captureObserveHook
        _captureTransportTouchpointHook = captureTransportTouchpointHook
        for ((k, v) in defaultHeaders) {
            setHeader(k, v)
        }
        for (hook in requestHooks) {
            _requestHooks.add(hook)
        }
        for (hook in responseHooks) {
            _responseHooks.add(hook)
        }
        for (hook in errorHooks) {
            _errorHooks.add(hook)
        }
        for (hook in observeHooks) {
            _observeHooks.add(hook)
        }
        for (hook in transportTouchpointHooks) {
            _transportTouchpointHooks.add(hook)
        }
    }

    func resolveCryptoConfig(config: ?api2.ClientCryptoConfig): api2.ClientCryptoConfig {
        if (let Some(overrideCfg) <- config) {
            return overrideCfg
        }
        match (_cryptoConfig) {
            case Some(cfg) => cfg
            case None =>
                throw api2.ClientCryptoException(
                    api2.ClientCryptoErrorCode.CryptoUnavailable,
                    "crypto config is required; call RestClient.useCrypto(...) or pass config"
                )
        }
    }

    func resolveRetryConfig(): ClientRetryConfig {
        if (let Some(overrideCfg) <- _retryOverride) {
            return overrideCfg
        }
        _retryConfig
    }

    func resolvePreferredTransportBackendHint(): String {
        if (let Some(overrideHint) <- _transportBackendHintOverride) {
            return overrideHint
        }
        _preferredTransportBackendHint
    }

    func resolveAllowExperimentalTransport(): Bool {
        if (let Some(overrideFlag) <- _allowExperimentalTransportOverride) {
            return overrideFlag
        }
        _allowExperimentalTransport
    }

    func resolveX509VerifyOption(): ?security.X509VerifyOption {
        if (let Some(overrideCfg) <- _x509VerifyOverride) {
            return Some(overrideCfg.copy())
        }
        if (let Some(defaultCfg) <- _x509Verify) {
            return Some(defaultCfg.copy())
        }
        None
    }

    public func method(m: String): RequestBuilder {
        _builder.method(m)
        _methodName = normalizeMethod(m)
        this
    }

    public func retry(config: ClientRetryConfig): RequestBuilder {
        _retryOverride = config.copy()
        this
    }

    public func x509Verify(option: security.X509VerifyOption): RequestBuilder {
        _x509VerifyOverride = Some(option.copy())
        this
    }

    public func disableX509Verify(): RequestBuilder {
        _x509VerifyOverride = Some(security.X509VerifyOption(enabled: false))
        this
    }

    public func withRetryPolicy(config: ClientRetryConfig): RequestBuilder {
        retry(config)
    }

    public func disableRetry(): RequestBuilder {
        _retryOverride = ClientRetryConfig(enabled: false)
        this
    }

    public func preferTransportBackend(backendId: String): RequestBuilder {
        _transportBackendHintOverride = Some(backendId.trimAscii())
        this
    }

    public func withTransportBackendHint(backendId: String): RequestBuilder {
        preferTransportBackend(backendId)
    }

    public func allowExperimentalTransport(enable!: Bool = true): RequestBuilder {
        _allowExperimentalTransportOverride = Some(enable)
        this
    }

    public func onRequest(hook: ClientRequestHook): RequestBuilder {
        _requestHooks.add(hook)
        this
    }

    public func onRequestHook(hook: ClientRequestHook): RequestBuilder {
        onRequest(hook)
    }

    public func onResponse(hook: ClientResponseHook): RequestBuilder {
        _responseHooks.add(hook)
        this
    }

    public func onResponseHook(hook: ClientResponseHook): RequestBuilder {
        onResponse(hook)
    }

    public func onError(hook: ClientErrorHook): RequestBuilder {
        _errorHooks.add(hook)
        this
    }

    public func onErrorHook(hook: ClientErrorHook): RequestBuilder {
        onError(hook)
    }

    public func onObserve(hook: ClientObserveHook): RequestBuilder {
        _observeHooks.add(hook)
        this
    }

    public func onObserveHook(hook: ClientObserveHook): RequestBuilder {
        onObserve(hook)
    }

    public func onTransportTouchpoint(hook: ClientTransportTouchpointHook): RequestBuilder {
        _transportTouchpointHooks.add(hook)
        this
    }

    public func onTransportTouchpointHook(hook: ClientTransportTouchpointHook): RequestBuilder {
        onTransportTouchpoint(hook)
    }

    public func url(u: String): RequestBuilder {
        var full = u
        if (_baseUrl.size > 0 && u.toRuneArray().size > 0) {
            let runes = u.toRuneArray()
            let isAbs = (u.size >= 7 && u.toRuneArray()[0] == r'h' && u.toRuneArray()[1] == r't')
            if (!isAbs) {
                if (runes[0] == r'/') {
                    full = _baseUrl + u
                } else {
                    let baseRunes = _baseUrl.toRuneArray()
                    if (baseRunes.size > 0 && baseRunes[baseRunes.size - 1] == r'/') {
                        full = _baseUrl + u
                    } else {
                        full = _baseUrl + "/" + u
                    }
                }
            }
        }
        _currentUrl = full
        _builder.url(full)
        this
    }

    public func query(key: String, value: String): RequestBuilder {
        _queryParams.add((key, value))
        this
    }

    public func withQuery(key: String, value: String): RequestBuilder {
        query(key, value)
    }

    public func header(name: String, value: String): RequestBuilder {
        setHeader(name, value)
        this
    }

    public func withHeader(name: String, value: String): RequestBuilder {
        header(name, value)
    }

    public func addHeader(name: String, value: String): RequestBuilder {
        setHeader(name, value)
        this
    }

    public func basicAuth(user: String, pass: String): RequestBuilder {
        let raw = user + ":" + pass
        let encoded = base64EncodeBytes(raw.toArray())
        setHeader("Authorization", "Basic " + encoded)
        this
    }

    public func withBasicAuth(user: String, pass: String): RequestBuilder {
        basicAuth(user, pass)
    }

    public func bearerToken(token: String): RequestBuilder {
        setHeader("Authorization", "Bearer " + token)
        this
    }

    public func withBearerToken(token: String): RequestBuilder {
        bearerToken(token)
    }

    func base64EncodeBytes(data: Array<UInt8>): String {
        let table = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
        let chars = table.toRuneArray()
        var result = ""
        var i: Int64 = 0
        while (i < data.size) {
            let b0 = Int64(data[i])
            let b1 = if (i + 1 < data.size) { Int64(data[i + 1]) } else { 0 }
            let b2 = if (i + 2 < data.size) { Int64(data[i + 2]) } else { 0 }
            let triple = (b0 << 16) | (b1 << 8) | b2
            result += chars[(triple >> 18) & 0x3F].toString()
            result += chars[(triple >> 12) & 0x3F].toString()
            result += if (i + 1 < data.size) { chars[(triple >> 6) & 0x3F].toString() } else { "=" }
            result += if (i + 2 < data.size) { chars[triple & 0x3F].toString() } else { "=" }
            i += 3
        }
        result
    }

    public func body(b: String): RequestBuilder {
        _builder.body(b)
        _requestCryptoConfig = None
        this
    }

    public func bodyJson(jsonPayload: String): RequestBuilder {
        setHeader("content-type", "application/json")
        _builder.body(jsonPayload)
        _formParams = None
        _multipartFields = None
        _multipartFiles = None
        _requestCryptoConfig = None
        this
    }

    public func bodyBytes(b: Array<UInt8>): RequestBuilder {
        _builder.body(b)
        _requestCryptoConfig = None
        this
    }

    public func encryptedBodyJson(
        jsonPayload: String,
        aad!: String = "",
        config!: ?api2.ClientCryptoConfig = None
    ): RequestBuilder {
        let cfg = resolveCryptoConfig(config)
        let envelope = api2.encryptJsonToEnvelopeV1(cfg, jsonPayload, aadText: aad)
        setHeader("content-type", "application/json")
        _builder.body(envelope)
        _formParams = None
        _multipartFields = None
        _multipartFiles = None
        _requestCryptoConfig = Some(cfg)
        this
    }

    public func bodyEncryptedJson(
        jsonPayload: String,
        aad!: String = "",
        config!: ?api2.ClientCryptoConfig = None
    ): RequestBuilder {
        encryptedBodyJson(jsonPayload, aad: aad, config: config)
    }

    public func form(params: ArrayList<(String, String)>): RequestBuilder {
        _formParams = params
        _multipartFields = None
        _multipartFiles = None
        _requestCryptoConfig = None
        this
    }

    public func bodyFormUrlEncoded(params: ArrayList<(String, String)>): RequestBuilder {
        form(params)
    }

    public func multipart(
        fields: ArrayList<(String, String)>,
        files: ArrayList<MultipartFile>
    ): RequestBuilder {
        _multipartFields = fields
        _multipartFiles = files
        _formParams = None
        _requestCryptoConfig = None
        this
    }

    public func bodyMultipartForm(
        fields: ArrayList<(String, String)>,
        files: ArrayList<MultipartFile>
    ): RequestBuilder {
        multipart(fields, files)
    }

    public func send(): ClientResponse {
        var finalUrl = _currentUrl
        if (_queryParams.size > 0) {
            let qs = buildQueryString(_queryParams)
            if (containsStr(_currentUrl, "?")) {
                finalUrl = _currentUrl + "&" + qs
            } else {
                finalUrl = _currentUrl + "?" + qs
            }
            _builder.url(finalUrl)
        }

        if (let Some(params) <- _formParams) {
            setHeader("content-type", "application/x-www-form-urlencoded")
            _builder.body(buildFormUrlEncoded(params).toArray())
        }
        if (let Some(fields) <- _multipartFields) {
            if (let Some(files) <- _multipartFiles) {
                let boundary = randomBoundary()
                setHeader("content-type", "multipart/form-data; boundary=${boundary}")
                _builder.body(buildMultipartBody(boundary, fields, files))
            }
        }

        let urlForHost = if (finalUrl.size > 0) { finalUrl } else { _currentUrl }
        if (let Some(store) <- _cookieStore) {
            let cookieHeader = store.getCookieHeader(urlForHost)
            if (cookieHeader.size > 0) {
                setHeader("Cookie", cookieHeader)
            }
        }

        let resolvedX509Verify = resolveX509VerifyOption()
        let selectionDecision = buildClientTransportSelectionDecision(
            urlForHost,
            resolvedX509Verify,
            requestCryptoConfig: _requestCryptoConfig,
            requiresMultipart: hasMultipartPayload(),
            preferredBackendHint: resolvePreferredTransportBackendHint(),
            allowExperimental: resolveAllowExperimentalTransport()
        )
        notifyTransportTouchpoint(buildClientTransportTouchpoint(selectionDecision))
        let observeStart = MonoTime.now()
        let retryCfg = resolveRetryConfig()
        let canRetryMethod = methodCanRetry(_methodName, retryCfg)
        var attempt: Int64 = 1

        if (let Some(verifyOption) <- resolvedX509Verify) {
            try {
                security.verifyX509Target(verifyOption, urlForHost, source: "ignite/client")
            } catch (e: security.SecurityException) {
                let observed = buildObservedSnapshot(
                    e,
                    elapsedMs(observeStart),
                    0,
                    collectObserveFields(),
                    "verify",
                    false,
                    selectionDecision
                )
                notifyObserveHooks(observed)
                notifyErrorHooks(Exception(observed.toLogLine()))
                throw e
            } catch (e: Exception) {
                let observed = buildObservedSnapshot(
                    e,
                    elapsedMs(observeStart),
                    0,
                    collectObserveFields(),
                    "verify",
                    false,
                    selectionDecision
                )
                notifyObserveHooks(observed)
                notifyErrorHooks(Exception(observed.toLogLine()))
                throw e
            }
        }

        try {
            for (hook in _requestHooks) {
                hook(_builder)
            }
        } catch (e: api2.ClientCryptoException) {
            let observed = buildObservedSnapshot(
                e,
                elapsedMs(observeStart),
                0,
                collectObserveFields(),
                "request_prepare",
                false,
                selectionDecision
            )
            notifyObserveHooks(observed)
            notifyErrorHooks(Exception(observed.toLogLine()))
            throw e
        } catch (e: Exception) {
            let observed = buildObservedSnapshot(
                e,
                elapsedMs(observeStart),
                0,
                collectObserveFields(),
                "request_prepare",
                false,
                selectionDecision
            )
            notifyObserveHooks(observed)
            notifyErrorHooks(Exception(observed.toLogLine()))
            throw e
        }

        while (true) {
            try {
                let req = _builder.build()
                let resp = ClientResponse(_client.send(req))

                if (shouldRetryStatus(resp.status, retryCfg, canRetryMethod, attempt)) {
                    try { resp.discard() } catch (_: Exception) {}
                    applyBackoffDelay(retryCfg, attempt)
                    attempt += 1
                    continue
                }

                let retryCount = attempt - 1
                let durationMs = elapsedMs(observeStart)
                let observed = buildSuccessfulObserveSnapshot(
                    resp.status,
                    durationMs,
                    retryCount,
                    collectObserveFields(),
                    selectionDecision
                )
                injectObserveHeaders(
                    resp,
                    durationMs,
                    retryCount,
                    classifyStatus(resp.status),
                    collectObserveFields(),
                    selectionDecision
                )
                notifyObserveHooks(observed)
                if (let Some(store) <- _cookieStore) {
                    store.addFromResponse(urlForHost, resp)
                }
                for (hook in _responseHooks) {
                    hook(resp)
                }
                return resp
            } catch (e: Exception) {
                if (shouldRetryError(e, retryCfg, canRetryMethod, attempt)) {
                    applyBackoffDelay(retryCfg, attempt)
                    attempt += 1
                    continue
                }
                let retryCount = attempt - 1
                let durationMs = elapsedMs(observeStart)
                let observed = buildObservedSnapshot(
                    e,
                    durationMs,
                    retryCount,
                    collectObserveFields(),
                    "",
                    canRetryMethod,
                    selectionDecision
                )
                notifyObserveHooks(observed)
                notifyErrorHooks(Exception(observed.toLogLine()))
                throw e
            }
        }
        throw Exception("unreachable")
    }

    func notifyObserveHooks(observed: ClientObserveSnapshot): Unit {
        if (let Some(hook) <- _captureObserveHook) {
            try {
                hook(observed)
            } catch (_: Exception) {}
        }
        for (hook in _observeHooks) {
            try {
                hook(observed)
            } catch (_: Exception) {}
        }
    }

    func notifyTransportTouchpoint(touchpoint: ClientTransportTouchpoint): Unit {
        if (let Some(hook) <- _captureTransportTouchpointHook) {
            try {
                hook(touchpoint)
            } catch (_: Exception) {}
        }
        for (hook in _transportTouchpointHooks) {
            try {
                hook(touchpoint)
            } catch (_: Exception) {}
        }
    }

    func notifyErrorHooks(observed: Exception): Unit {
        for (hook in _errorHooks) {
            try {
                hook(observed)
            } catch (_: Exception) {}
        }
    }

    func setHeader(name: String, value: String): Unit {
        _builder.header(name, value)
        _headerSnapshot.add(name.trimAscii().toAsciiLower(), value)
    }

    func elapsedMs(start: MonoTime): Int64 {
        (MonoTime.now() - start).toMilliseconds()
    }

    func classifyStatus(status: UInt16): String {
        let code = Int64(status)
        if (code < 400) {
            return "NONE"
        }
        "HTTP_${code}"
    }

    func collectObserveFields(): String {
        let prefix = "x-ignite-log-"
        var first = true
        var out = ""
        for ((name, value) in _headerSnapshot) {
            if (!startsWith(name, prefix)) {
                continue
            }
            let key = sliceFrom(name, prefix.size)
            if (key.size == 0) {
                continue
            }
            if (!first) {
                out += ","
            }
            first = false
            out = out + key + "=" + value
        }
        if (out.size == 0) {
            return "-"
        }
        out
    }

    func injectObserveHeaders(
        resp: ClientResponse,
        durationMs: Int64,
        retryCount: Int64,
        errorClass: String,
        fields: String,
        selectionDecision: TransportSelectionDecision
    ): Unit {
        try {
            resp.headers.add("x-ignite-observe-duration-ms", "${durationMs}")
            resp.headers.add("x-ignite-observe-retry-count", "${retryCount}")
            resp.headers.add("x-ignite-observe-error-class", if (errorClass.size == 0) { "NONE" } else { errorClass })
            resp.headers.add("x-ignite-observe-fields", if (fields.size == 0) { "-" } else { fields })
            resp.headers.add("x-ignite-observe-backend-id", selectionDecision.selectedBackend)
            resp.headers.add("x-ignite-observe-provider-id", selectionDecision.providerId)
            resp.headers.add("x-ignite-observe-crypto-provider-id", selectionDecision.cryptoProviderId)
            resp.headers.add("x-ignite-observe-public-path", selectionDecision.publicPath)
            resp.headers.add("x-ignite-observe-risk-level", selectionDecision.riskLevel)
            resp.headers.add("x-ignite-observe-transport-tags", selectionDecision.observabilityTags)
            resp.headers.add("x-ignite-observe-selected-reason", selectionDecision.selectedReason)
            resp.headers.add("x-ignite-observe-fallback-chain", selectionDecision.fallbackChain)
            resp.headers.add("x-ignite-observe-candidate-order", selectionDecision.candidateOrder)
        } catch (_: Exception) {}
    }

    func buildObservedSnapshot(
        origin: api2.ClientCryptoException,
        durationMs: Int64,
        retryCount: Int64,
        fields: String,
        phaseHint: String,
        canRetryMethod: Bool,
        selectionDecision: TransportSelectionDecision
    ): ClientObserveSnapshot {
        let envelope = buildTransportErrorEnvelope(
            origin,
            phaseHint,
            canRetryMethod,
            selectionDecision: selectionDecision
        )
        let fallbackRecord = buildSuggestedFallbackDecisionRecord(selectionDecision, envelope)
        buildClientObserveSnapshot(
            envelope,
            durationMs,
            retryCount,
            fields,
            selectionDecision: selectionDecision,
            fallbackRecord: fallbackRecord
        )
    }

    func buildObservedSnapshot(
        origin: security.SecurityException,
        durationMs: Int64,
        retryCount: Int64,
        fields: String,
        phaseHint: String,
        canRetryMethod: Bool,
        selectionDecision: TransportSelectionDecision
    ): ClientObserveSnapshot {
        let envelope = buildTransportErrorEnvelope(
            origin,
            phaseHint,
            canRetryMethod,
            selectionDecision: selectionDecision
        )
        let fallbackRecord = buildSuggestedFallbackDecisionRecord(selectionDecision, envelope)
        buildClientObserveSnapshot(
            envelope,
            durationMs,
            retryCount,
            fields,
            selectionDecision: selectionDecision,
            fallbackRecord: fallbackRecord
        )
    }

    func buildObservedSnapshot(
        origin: Exception,
        durationMs: Int64,
        retryCount: Int64,
        fields: String,
        phaseHint: String,
        canRetryMethod: Bool,
        selectionDecision: TransportSelectionDecision
    ): ClientObserveSnapshot {
        let envelope = buildTransportErrorEnvelope(
            origin,
            phaseHint,
            canRetryMethod,
            selectionDecision: selectionDecision
        )
        let fallbackRecord = buildSuggestedFallbackDecisionRecord(selectionDecision, envelope)
        buildClientObserveSnapshot(
            envelope,
            durationMs,
            retryCount,
            fields,
            selectionDecision: selectionDecision,
            fallbackRecord: fallbackRecord
        )
    }

    func normalizeMethod(method: String): String {
        method.trimAscii().toAsciiUpper()
    }

    func hasMultipartPayload(): Bool {
        if (let Some(_fields) <- _multipartFields) {
            return true
        }
        false
    }

    func methodCanRetry(method: String, config: ClientRetryConfig): Bool {
        if (!config.enabled || config.maxAttempts <= 1) {
            return false
        }
        if (!config.idempotentOnly) {
            return true
        }
        isIdempotentMethod(method)
    }

    func isIdempotentMethod(method: String): Bool {
        let m = normalizeMethod(method)
        m == "GET" || m == "HEAD" || m == "OPTIONS" || m == "PUT" || m == "DELETE"
    }

    func shouldRetryStatus(
        status: UInt16,
        config: ClientRetryConfig,
        canRetryMethod: Bool,
        attempt: Int64
    ): Bool {
        if (!canRetryMethod || attempt >= config.maxAttempts) {
            return false
        }
        containsInt64(config.retryStatusCodes, Int64(status))
    }

    func shouldRetryError(
        origin: Exception,
        config: ClientRetryConfig,
        canRetryMethod: Bool,
        attempt: Int64
    ): Bool {
        if (attempt >= config.maxAttempts) {
            return false
        }
        let envelope = buildTransportErrorEnvelope(origin, "", canRetryMethod)
        envelope.retryable
    }

    func applyBackoffDelay(config: ClientRetryConfig, attempt: Int64): Unit {
        if (attempt >= config.maxAttempts) {
            return
        }
        let delayMs = computeBackoffDelayMs(config, attempt)
        if (delayMs <= 0) {
            return
        }
        spinWait(delayMs)
    }

    func computeBackoffDelayMs(config: ClientRetryConfig, attempt: Int64): Int64 {
        var delay = config.baseDelayMs
        var i: Int64 = 1
        while (i < attempt) {
            if (delay >= config.maxDelayMs) {
                delay = config.maxDelayMs
                break
            }
            let doubled = delay * 2
            delay = if (doubled > config.maxDelayMs) { config.maxDelayMs } else { doubled }
            i += 1
        }
        if (config.jitterMs > 0) {
            let rng = Random()
            let range = UInt64(config.jitterMs + 1)
            let jitter = Int64(rng.nextUInt64() % range)
            let sum = delay + jitter
            delay = if (sum > config.maxDelayMs) { config.maxDelayMs } else { sum }
        }
        delay
    }

    func spinWait(delayMs: Int64): Unit {
        sleep(Duration.millisecond * delayMs)
    }

    func containsInt64(list: ArrayList<Int64>, value: Int64): Bool {
        for (x in list) {
            if (x == value) {
                return true
            }
        }
        false
    }

    func containsStr(hay: String, needle: String): Bool {
        let h = hay.toRuneArray()
        let n = needle.toRuneArray()
        if (n.size == 0) { return true }
        if (h.size < n.size) { return false }
        for (i in 0..=(h.size - n.size)) {
            var ok = true
            for (j in 0..n.size) {
                if (h[i + j] != n[j]) { ok = false; break }
            }
            if (ok) { return true }
        }
        false
    }

    func startsWith(s: String, prefix: String): Bool {
        let a = s.toRuneArray()
        let b = prefix.toRuneArray()
        if (a.size < b.size) {
            return false
        }
        for (i in 0..b.size) {
            if (a[i] != b[i]) {
                return false
            }
        }
        true
    }

    func sliceFrom(s: String, start: Int64): String {
        let runes = s.toRuneArray()
        if (start <= 0) {
            return s
        }
        if (start >= runes.size) {
            return ""
        }
        var out = ""
        for (i in start..runes.size) {
            out += runes[i].toString()
        }
        out
    }

}

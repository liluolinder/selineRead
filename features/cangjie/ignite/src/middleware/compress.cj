package ignite.middleware

import ignite.{Handler, Ctx, StreamCompressionPlan, registerStreamCompressionPlan}
import std.collection.ArrayList
import std.io.InputStream
import stdx.compress.zlib.{
    CompressInputStream,
    CompressLevel,
    WrapType
}

public class CompressConfig {
    /// Minimum response body size (bytes) required before compression is attempted.
    public var minBytes: Int64 = 1024
    /// Preferred algorithm when both are acceptable.
    public var preferGzip: Bool = true
    /// Enable gzip support.
    public var gzipEnabled: Bool = true
    /// Enable deflate support.
    public var deflateEnabled: Bool = true
    /// zlib compression level.
    public var level: CompressLevel = CompressLevel.DefaultCompression
    /// Internal stream buffer size for zlib streaming.
    public var bufferSize: Int64 = 2048
    /// Set `Vary: Accept-Encoding` when compression is used.
    public var setVaryHeader: Bool = true
    /// Skip compression when compressed payload is not smaller than original.
    public var skipIfNoGain: Bool = true

    public init(
        minBytes!: Int64 = 1024,
        preferGzip!: Bool = true,
        gzipEnabled!: Bool = true,
        deflateEnabled!: Bool = true,
        level!: CompressLevel = CompressLevel.DefaultCompression,
        bufferSize!: Int64 = 2048,
        setVaryHeader!: Bool = true,
        skipIfNoGain!: Bool = true
    ) {
        this.minBytes = minBytes
        this.preferGzip = preferGzip
        this.gzipEnabled = gzipEnabled
        this.deflateEnabled = deflateEnabled
        this.level = level
        this.bufferSize = bufferSize
        this.setVaryHeader = setVaryHeader
        this.skipIfNoGain = skipIfNoGain
    }
}

public func compressMiddleware(config!: CompressConfig = CompressConfig()): Handler {
    let minBytes = if (config.minBytes < 0) { 0 } else { config.minBytes }
    let bufferSize = normalizeBufferSize(config.bufferSize)

    { ctx: Ctx =>
        let encoding = negotiateEncoding(ctx.header("accept-encoding") ?? "", config)
        if (encoding.size > 0) {
            registerStreamCompressionPlan(
                ctx,
                StreamCompressionPlan(
                    encoding,
                    minBytes,
                    config.setVaryHeader,
                    config.skipIfNoGain,
                    config.level,
                    bufferSize
                )
            )
        }

        ctx.next()

        if (ctx.method == "HEAD") { return }
        if (shouldSkipStatus(ctx.responseStatus)) { return }
        if ((ctx.header("range") ?? "").size > 0) { return }
        if ((ctx.getLocal("__ignite_response_kind") ?? "") == "sse") { return }

        if (encoding.size == 0) { return }

        if (let Some(textBody) <- ctx.responseBody) {
            let rawBytes = textBody.toArray()
            if (rawBytes.size < minBytes) {
                return
            }
            let compressed = try {
                compressResponseBytes(rawBytes, encoding, config.level, bufferSize)
            } catch (_: Exception) {
                return
            }

            if (config.skipIfNoGain && compressed.size >= rawBytes.size) {
                return
            }

            if (config.setVaryHeader) {
                ctx.setHeader("vary", "Accept-Encoding")
            }
            ctx.setHeader("content-encoding", encoding)
            ctx.setHeader("content-length", "${compressed.size}")
            let _ = ctx.send(compressed)
        }
    }
}

func shouldSkipStatus(status: UInt16): Bool {
    status < 200 || status == 204 || status == 304
}

func normalizeBufferSize(raw: Int64): Int64 {
    if (raw < 256) {
        return 256
    }
    if (raw > 65536) {
        return 65536
    }
    raw
}

func negotiateEncoding(acceptEncodingRaw: String, config: CompressConfig): String {
    let acceptEncoding = acceptEncodingRaw.trimAscii().toAsciiLower()
    if (acceptEncoding.size == 0) {
        return ""
    }

    var qGzip: Int64 = -1
    var qDeflate: Int64 = -1
    var qWildcard: Int64 = -1

    for (part in acceptEncoding.split(",")) {
        let item = part.trimAscii()
        if (item.size == 0) {
            continue
        }
        let tokens = item.split(";")
        let name = tokens[0].trimAscii()
        var quality: Int64 = 1000
        if (tokens.size > 1) {
            var idx: Int64 = 1
            while (idx < tokens.size) {
                let kv = tokens[idx].trimAscii().split("=", 2)
                if (kv.size == 2 && kv[0].trimAscii() == "q") {
                    quality = parseQValue(kv[1])
                }
                idx += 1
            }
        }
        if (quality < 0) {
            continue
        }
        if (name == "gzip") {
            qGzip = quality
        } else if (name == "deflate") {
            qDeflate = quality
        } else if (name == "*") {
            qWildcard = quality
        }
    }

    if (config.gzipEnabled && qGzip < 0) {
        qGzip = qWildcard
    }
    if (config.deflateEnabled && qDeflate < 0) {
        qDeflate = qWildcard
    }

    if (!config.gzipEnabled) {
        qGzip = -1
    }
    if (!config.deflateEnabled) {
        qDeflate = -1
    }

    if (qGzip <= 0 && qDeflate <= 0) {
        return ""
    }

    if (config.preferGzip) {
        if (qGzip >= qDeflate && qGzip > 0) {
            return "gzip"
        }
        if (qDeflate > 0) {
            return "deflate"
        }
        return ""
    }

    if (qDeflate >= qGzip && qDeflate > 0) {
        return "deflate"
    }
    if (qGzip > 0) {
        return "gzip"
    }
    ""
}

// Parses RFC7231 qvalue in [0,1], returned as int in [0,1000].
func parseQValue(raw: String): Int64 {
    let s = raw.trimAscii()
    if (s.size == 0) {
        return -1
    }
    let parts = s.split(".", 2)
    if (parts.size == 0) {
        return -1
    }
    let whole = parseDigits(parts[0])
    if (whole < 0 || whole > 1) {
        return -1
    }
    var fracScaled: Int64 = 0
    if (parts.size == 2) {
        let frac = parts[1]
        if (frac.size == 0) {
            return -1
        }
        var scale: Int64 = 100
        var count: Int64 = 0
        for (ch in frac.toRuneArray()) {
            if (count >= 3) {
                break
            }
            if (ch < r'0' || ch > r'9') {
                return -1
            }
            fracScaled += digitValue(ch) * scale
            scale /= 10
            count += 1
        }
    }
    if (whole == 1) {
        if (fracScaled > 0) {
            return -1
        }
        return 1000
    }
    fracScaled
}

func parseDigits(raw: String): Int64 {
    if (raw.size == 0) {
        return -1
    }
    var out: Int64 = 0
    for (ch in raw.toRuneArray()) {
        if (ch < r'0' || ch > r'9') {
            return -1
        }
        out = out * 10 + digitValue(ch)
    }
    out
}

func digitValue(ch: Rune): Int64 {
    match (ch) {
        case r'0' => 0
        case r'1' => 1
        case r'2' => 2
        case r'3' => 3
        case r'4' => 4
        case r'5' => 5
        case r'6' => 6
        case r'7' => 7
        case r'8' => 8
        case r'9' => 9
        case _ => -1
    }
}

func compressResponseBytes(
    body: Array<UInt8>,
    encoding: String,
    level: CompressLevel,
    bufferSize: Int64
): Array<UInt8> {
    let wrap: WrapType = if (encoding == "deflate") {
        WrapType.DeflateFormat
    } else {
        WrapType.GzipFormat
    }
    let input = BytesInputStream(toByteArray(body))
    let compressor = CompressInputStream(
        input,
        wrap: wrap,
        compressLevel: level,
        bufLen: bufferSize
    )
    let out = ArrayList<Byte>()
    let tmp = Array<Byte>(bufferSize, repeat: 0)
    try {
        while (true) {
            let n = compressor.read(tmp)
            if (n <= 0) {
                break
            }
            for (i in 0..n) {
                out.add(tmp[i])
            }
        }
    } finally {
        try {
            compressor.close()
        } catch (_: Exception) {}
        try {
            input.close()
        } catch (_: Exception) {}
    }
    toUInt8Array(out.toArray())
}

class BytesInputStream <: InputStream {
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

func toByteArray(input: Array<UInt8>): Array<Byte> {
    let out = Array<Byte>(input.size, repeat: 0)
    var i = 0
    while (i < input.size) {
        out[i] = input[i]
        i += 1
    }
    out
}

func toUInt8Array(input: Array<Byte>): Array<UInt8> {
    let out = Array<UInt8>(input.size, repeat: 0)
    var i = 0
    while (i < input.size) {
        out[i] = UInt8(input[i])
        i += 1
    }
    out
}

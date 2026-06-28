package ignite

import std.io.InputStream
import stdx.compress.zlib.{CompressInputStream, CompressLevel, WrapType}

let IGNITE_STREAM_COMPRESSION_PLAN_LOCAL_KEY = "__ignite_stream_compression_plan"

/// Minimal non-buffered compression plan for `sendStream(...)`-based responses.
///
/// This plan is registered by middleware before handler execution and consumed
/// by `Ctx.sendStream(...)` right before the response body stream is attached.
public class StreamCompressionPlan {
    public let encoding: String
    public let minBytes: Int64
    public let setVaryHeader: Bool
    public let skipIfNoGain: Bool
    public let level: CompressLevel
    public let bufferSize: Int64

    public init(
        encoding: String,
        minBytes: Int64,
        setVaryHeader: Bool,
        skipIfNoGain: Bool,
        level: CompressLevel,
        bufferSize: Int64
    ) {
        this.encoding = encoding.trimAscii().toAsciiLower()
        this.minBytes = if (minBytes < 0) { 0 } else { minBytes }
        this.setVaryHeader = setVaryHeader
        this.skipIfNoGain = skipIfNoGain
        this.level = level
        this.bufferSize = if (bufferSize < 256) {
            256
        } else if (bufferSize > 65536) {
            65536
        } else {
            bufferSize
        }
    }
}

func registerStreamCompressionPlan(ctx: Ctx, plan: StreamCompressionPlan): Unit {
    ctx.setLocalValue(IGNITE_STREAM_COMPRESSION_PLAN_LOCAL_KEY, plan)
}

func currentStreamCompressionPlan(
    ctx: Ctx,
    contentLength: ?Int64
): ?StreamCompressionPlan {
    if (ctx.responseStatus < 200 || ctx.responseStatus == 204 || ctx.responseStatus == 304) {
        return None
    }
    if ((ctx.responseHeader("content-encoding") ?? "").trimAscii().size > 0) {
        return None
    }
    if ((ctx.header("range") ?? "").trimAscii().size > 0) {
        return None
    }
    if (let Some(plan) <- ctx.getLocalValue<StreamCompressionPlan>(IGNITE_STREAM_COMPRESSION_PLAN_LOCAL_KEY)) {
        if (plan.encoding.size == 0 || plan.skipIfNoGain) {
            return None
        }
        match (contentLength) {
            case Some(size) =>
                if (size <= 0 || size < plan.minBytes) {
                    return None
                }
            case None =>
                if (plan.minBytes > 0) {
                    return None
                }
        }
        return Some(plan)
    }
    None
}

func wrapStreamWithCompressionPlan(
    stream: InputStream,
    plan: StreamCompressionPlan
): InputStream {
    let wrap: WrapType = if (plan.encoding == "deflate") {
        WrapType.DeflateFormat
    } else {
        WrapType.GzipFormat
    }
    CompressInputStream(
        stream,
        wrap: wrap,
        compressLevel: plan.level,
        bufLen: plan.bufferSize
    )
}

func mergeVaryAcceptEncoding(existing: String): String {
    let trimmed = existing.trimAscii()
    if (trimmed.size == 0) {
        return "Accept-Encoding"
    }
    for (part in trimmed.split(",")) {
        if (part.trimAscii().toAsciiLower() == "accept-encoding") {
            return trimmed
        }
    }
    trimmed + ", Accept-Encoding"
}

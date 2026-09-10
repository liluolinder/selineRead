package canghui_scene3d_bgfx

import chui.scene3d.Scene3DBackend
import std.collection.ArrayList

private let SHADER_CONTAINER_VERSION: UInt8 = UInt8(11)
private let DEBUG_LINK_HASH: UInt32 = UInt32(0x6622beb8)
private let DEBUG_LAYOUT = "position3f-color4f-v1"
private let DEBUG_VERTEX_DIGEST = "sha256:825bd94ee2f0a0e56ae29ea1ca45d55cd482effd17bb54845885071d7c2dfc3a"
private let DEBUG_FRAGMENT_DIGEST = "sha256:8d7ba808b27bad9a3953b767a372e2ce8e4c75b6c249bfc68dc896ce2a650172"

public enum BgfxShaderStage <: Equatable<BgfxShaderStage> {
    | Vertex
    | Fragment

    public operator func ==(other: BgfxShaderStage): Bool {
        match ((this, other)) {
            case (Vertex, Vertex) | (Fragment, Fragment) => true
            case _ => false
        }
    }

    public operator func !=(other: BgfxShaderStage): Bool { !(this == other) }
}

/** Immutable backend-bound shader payload accepted by the bgfx provider. */
public class BgfxShaderResource {
    public let backend: Scene3DBackend
    public let stage: BgfxShaderStage
    public let digest: String
    public let layoutSignature: String
    private let bytes: Array<Byte>

    public init(
        backend: Scene3DBackend,
        stage: BgfxShaderStage,
        digest: String,
        layoutSignature: String,
        payload: Array<Byte>
    ) {
        if (layoutSignature.isEmpty()) {
            throw IllegalArgumentException("shader layout signature must not be empty")
        }
        if (payload.size < 18 || payload.size > 65536) {
            throw IllegalArgumentException("shader payload size is outside the supported boundary")
        }
        validateShaderContainer(stage, payload)
        let actual = shaderSha256Digest(payload)
        if (digest != actual) {
            throw IllegalArgumentException("shader payload digest mismatch")
        }
        this.backend = backend
        this.stage = stage
        this.digest = digest
        this.layoutSignature = layoutSignature
        this.bytes = payload.clone()
    }

    public func payload(): Array<Byte> { bytes.clone() }
}

/** Pairing contract for one vertex/fragment program. */
public class BgfxShaderProgramResource {
    public let vertex: BgfxShaderResource
    public let fragment: BgfxShaderResource
    public let backend: Scene3DBackend
    public let layoutSignature: String

    public init(vertex: BgfxShaderResource, fragment: BgfxShaderResource) {
        if (vertex.stage != BgfxShaderStage.Vertex || fragment.stage != BgfxShaderStage.Fragment) {
            throw IllegalArgumentException("shader program stages must be vertex then fragment")
        }
        if (vertex.backend != fragment.backend) {
            throw IllegalArgumentException("shader program backend mismatch")
        }
        if (vertex.layoutSignature != fragment.layoutSignature) {
            throw IllegalArgumentException("shader program layout mismatch")
        }
        this.vertex = vertex
        this.fragment = fragment
        this.backend = vertex.backend
        this.layoutSignature = vertex.layoutSignature
    }
}

/** Built-in Metal program used by the first visible geometry proof. */
public func debugMetalShaderProgram(): BgfxShaderProgramResource {
    let vertexPayload = buildDebugVertexShader()
    let fragmentPayload = buildDebugFragmentShader()
    let vertex = BgfxShaderResource(
        Scene3DBackend.Metal,
        BgfxShaderStage.Vertex,
        DEBUG_VERTEX_DIGEST,
        DEBUG_LAYOUT,
        vertexPayload
    )
    let fragment = BgfxShaderResource(
        Scene3DBackend.Metal,
        BgfxShaderStage.Fragment,
        DEBUG_FRAGMENT_DIGEST,
        DEBUG_LAYOUT,
        fragmentPayload
    )
    BgfxShaderProgramResource(vertex, fragment)
}

public func shaderSha256Digest(payload: Array<Byte>): String {
    "sha256:" + bytesToLowerHex(sha256(payload))
}

private func validateShaderContainer(stage: BgfxShaderStage, payload: Array<Byte>): Unit {
    let expected = match (stage) {
        case BgfxShaderStage.Vertex => UInt8(0x56)
        case BgfxShaderStage.Fragment => UInt8(0x46)
    }
    if (UInt8(payload[0]) != expected || UInt8(payload[1]) != UInt8(0x53) ||
        UInt8(payload[2]) != UInt8(0x48) || UInt8(payload[3]) != SHADER_CONTAINER_VERSION) {
        throw IllegalArgumentException("shader payload has an unsupported bgfx container header")
    }
}

private func buildDebugVertexShader(): Array<Byte> {
    let source =
        "#include <metal_stdlib>\n" +
        "#include <simd/simd.h>\n" +
        "using namespace metal;\n" +
        "struct _Global {\n" +
        "    float4x4 u_modelViewProj;\n" +
        "};\n" +
        "struct xlatMtlMain_out {\n" +
        "    float bgfx_metal_pointSize [[point_size]] = 1;\n" +
        "    float4 _entryPointOutput_v_color0 [[user(locn0)]];\n" +
        "    float4 gl_Position [[position]];\n" +
        "};\n" +
        "struct xlatMtlMain_in {\n" +
        "    float3 a_position [[attribute(0)]];\n" +
        "    float4 a_color0 [[attribute(1)]];\n" +
        "};\n" +
        "vertex xlatMtlMain_out xlatMtlMain(\n" +
        "    xlatMtlMain_in in [[stage_in]],\n" +
        "    constant _Global& _mtl_u [[buffer(0)]]\n" +
        ") {\n" +
        "    xlatMtlMain_out out = {};\n" +
        "    out.gl_Position = _mtl_u.u_modelViewProj * float4(in.a_position, 1.0);\n" +
        "    out._entryPointOutput_v_color0 = in.a_color0;\n" +
        "    return out;\n" +
        "}\n"
    let bytes = shaderPrefix(BgfxShaderStage.Vertex, UInt32(0), DEBUG_LINK_HASH)
    appendUniform(bytes, "u_modelViewProj", UInt8(4), UInt8(1), UInt16(0), UInt16(4))
    appendShaderBody(bytes, source, [UInt16(0x0001), UInt16(0x0005)], UInt16(64))
    bytes.toArray()
}

private func buildDebugFragmentShader(): Array<Byte> {
    let source =
        "#include <metal_stdlib>\n" +
        "#include <simd/simd.h>\n" +
        "using namespace metal;\n" +
        "struct xlatMtlMain_out {\n" +
        "    float4 bgfx_FragData0 [[color(0)]];\n" +
        "};\n" +
        "struct xlatMtlMain_in {\n" +
        "    float4 v_color0 [[user(locn0)]];\n" +
        "};\n" +
        "fragment xlatMtlMain_out xlatMtlMain(xlatMtlMain_in in [[stage_in]]) {\n" +
        "    xlatMtlMain_out out = {};\n" +
        "    out.bgfx_FragData0 = in.v_color0;\n" +
        "    return out;\n" +
        "}\n"
    let bytes = shaderPrefix(BgfxShaderStage.Fragment, DEBUG_LINK_HASH, UInt32(0))
    appendUInt16LE(bytes, UInt16(0))
    appendShaderBody(bytes, source, [], UInt16(0))
    bytes.toArray()
}

private func shaderPrefix(stage: BgfxShaderStage, inputHash: UInt32, outputHash: UInt32): ArrayList<Byte> {
    let bytes = ArrayList<Byte>()
    bytes.add(match (stage) {
        case BgfxShaderStage.Vertex => UInt8(0x56)
        case BgfxShaderStage.Fragment => UInt8(0x46)
    })
    bytes.add(UInt8(0x53))
    bytes.add(UInt8(0x48))
    bytes.add(SHADER_CONTAINER_VERSION)
    appendUInt32LE(bytes, inputHash)
    appendUInt32LE(bytes, outputHash)
    if (stage == BgfxShaderStage.Vertex) { appendUInt16LE(bytes, UInt16(1)) }
    bytes
}

private func appendUniform(
    bytes: ArrayList<Byte>,
    name: String,
    kind: UInt8,
    count: UInt8,
    registerIndex: UInt16,
    registerCount: UInt16
): Unit {
    let nameBytes = name.toArray()
    bytes.add(UInt8(nameBytes.size))
    appendBytes(bytes, nameBytes)
    bytes.add(kind)
    bytes.add(count)
    appendUInt16LE(bytes, registerIndex)
    appendUInt16LE(bytes, registerCount)
    bytes.add(UInt8(0))
    bytes.add(UInt8(0))
    appendUInt16LE(bytes, UInt16(0))
}

private func appendShaderBody(
    bytes: ArrayList<Byte>, source: String, attributes: Array<UInt16>, uniformBytes: UInt16
): Unit {
    let sourceBytes = source.toArray()
    appendUInt32LE(bytes, UInt32(sourceBytes.size))
    appendBytes(bytes, sourceBytes)
    bytes.add(UInt8(0))
    bytes.add(UInt8(attributes.size))
    for (attribute in attributes) { appendUInt16LE(bytes, attribute) }
    appendUInt16LE(bytes, uniformBytes)
}

private func appendBytes(out: ArrayList<Byte>, values: Array<Byte>): Unit {
    for (value in values) { out.add(value) }
}

private func appendUInt16LE(out: ArrayList<Byte>, value: UInt16): Unit {
    out.add(UInt8(value & UInt16(0xff)))
    out.add(UInt8((value >> 8) & UInt16(0xff)))
}

private func appendUInt32LE(out: ArrayList<Byte>, value: UInt32): Unit {
    out.add(UInt8(value & UInt32(0xff)))
    out.add(UInt8((value >> 8) & UInt32(0xff)))
    out.add(UInt8((value >> 16) & UInt32(0xff)))
    out.add(UInt8((value >> 24) & UInt32(0xff)))
}

private let SHA256_INITIAL: Array<UInt32> = [
    UInt32(0x6a09e667), UInt32(0xbb67ae85), UInt32(0x3c6ef372), UInt32(0xa54ff53a),
    UInt32(0x510e527f), UInt32(0x9b05688c), UInt32(0x1f83d9ab), UInt32(0x5be0cd19)
]

private let SHA256_ROUND: Array<UInt32> = [
    UInt32(0x428a2f98), UInt32(0x71374491), UInt32(0xb5c0fbcf), UInt32(0xe9b5dba5),
    UInt32(0x3956c25b), UInt32(0x59f111f1), UInt32(0x923f82a4), UInt32(0xab1c5ed5),
    UInt32(0xd807aa98), UInt32(0x12835b01), UInt32(0x243185be), UInt32(0x550c7dc3),
    UInt32(0x72be5d74), UInt32(0x80deb1fe), UInt32(0x9bdc06a7), UInt32(0xc19bf174),
    UInt32(0xe49b69c1), UInt32(0xefbe4786), UInt32(0x0fc19dc6), UInt32(0x240ca1cc),
    UInt32(0x2de92c6f), UInt32(0x4a7484aa), UInt32(0x5cb0a9dc), UInt32(0x76f988da),
    UInt32(0x983e5152), UInt32(0xa831c66d), UInt32(0xb00327c8), UInt32(0xbf597fc7),
    UInt32(0xc6e00bf3), UInt32(0xd5a79147), UInt32(0x06ca6351), UInt32(0x14292967),
    UInt32(0x27b70a85), UInt32(0x2e1b2138), UInt32(0x4d2c6dfc), UInt32(0x53380d13),
    UInt32(0x650a7354), UInt32(0x766a0abb), UInt32(0x81c2c92e), UInt32(0x92722c85),
    UInt32(0xa2bfe8a1), UInt32(0xa81a664b), UInt32(0xc24b8b70), UInt32(0xc76c51a3),
    UInt32(0xd192e819), UInt32(0xd6990624), UInt32(0xf40e3585), UInt32(0x106aa070),
    UInt32(0x19a4c116), UInt32(0x1e376c08), UInt32(0x2748774c), UInt32(0x34b0bcb5),
    UInt32(0x391c0cb3), UInt32(0x4ed8aa4a), UInt32(0x5b9cca4f), UInt32(0x682e6ff3),
    UInt32(0x748f82ee), UInt32(0x78a5636f), UInt32(0x84c87814), UInt32(0x8cc70208),
    UInt32(0x90befffa), UInt32(0xa4506ceb), UInt32(0xbef9a3f7), UInt32(0xc67178f2)
]

@OverflowWrapping
private func sha256(data: Array<Byte>): Array<Byte> {
    let message = sha256Padding(data)
    let state = SHA256_INITIAL.clone()
    var offset: Int64 = 0
    while (offset < message.size) {
        let words = Array<UInt32>(64, repeat: UInt32(0))
        var i: Int64 = 0
        while (i < 16) {
            words[i] = readUInt32BE(message, offset + i * 4)
            i += 1
        }
        while (i < 64) {
            let s0 = rotateRight(words[i - 15], 7) ^ rotateRight(words[i - 15], 18) ^ (words[i - 15] >> 3)
            let s1 = rotateRight(words[i - 2], 17) ^ rotateRight(words[i - 2], 19) ^ (words[i - 2] >> 10)
            words[i] = words[i - 16] + s0 + words[i - 7] + s1
            i += 1
        }
        var a = state[0]
        var b = state[1]
        var c = state[2]
        var d = state[3]
        var e = state[4]
        var f = state[5]
        var g = state[6]
        var h = state[7]
        i = 0
        while (i < 64) {
            let sum1 = rotateRight(e, 6) ^ rotateRight(e, 11) ^ rotateRight(e, 25)
            let choose = (e & f) ^ ((e ^ UInt32(0xffff_ffff)) & g)
            let first = h + sum1 + choose + SHA256_ROUND[i] + words[i]
            let sum0 = rotateRight(a, 2) ^ rotateRight(a, 13) ^ rotateRight(a, 22)
            let majority = (a & b) ^ (a & c) ^ (b & c)
            h = g
            g = f
            f = e
            e = d + first
            d = c
            c = b
            b = a
            a = first + sum0 + majority
            i += 1
        }
        state[0] = state[0] + a
        state[1] = state[1] + b
        state[2] = state[2] + c
        state[3] = state[3] + d
        state[4] = state[4] + e
        state[5] = state[5] + f
        state[6] = state[6] + g
        state[7] = state[7] + h
        offset += 64
    }
    let result = ArrayList<Byte>()
    for (value in state) {
        result.add(UInt8((value >> 24) & UInt32(0xff)))
        result.add(UInt8((value >> 16) & UInt32(0xff)))
        result.add(UInt8((value >> 8) & UInt32(0xff)))
        result.add(UInt8(value & UInt32(0xff)))
    }
    result.toArray()
}

private func sha256Padding(data: Array<Byte>): Array<Byte> {
    let result = ArrayList<Byte>()
    appendBytes(result, data)
    result.add(UInt8(0x80))
    while ((result.size + 8) % 64 != 0) { result.add(UInt8(0)) }
    let bits = UInt64(data.size) * UInt64(8)
    var shift: Int64 = 56
    while (shift >= 0) {
        result.add(UInt8((bits >> shift) & UInt64(0xff)))
        shift -= 8
    }
    result.toArray()
}

private func readUInt32BE(data: Array<Byte>, offset: Int64): UInt32 {
    (UInt32(UInt8(data[offset])) << 24) |
    (UInt32(UInt8(data[offset + 1])) << 16) |
    (UInt32(UInt8(data[offset + 2])) << 8) |
    UInt32(UInt8(data[offset + 3]))
}

private func rotateRight(value: UInt32, count: Int64): UInt32 {
    (value >> count) | (value << (32 - count))
}

private func bytesToLowerHex(bytes: Array<Byte>): String {
    let digits: Array<String> = [
        "0", "1", "2", "3", "4", "5", "6", "7",
        "8", "9", "a", "b", "c", "d", "e", "f"
    ]
    var result = ""
    for (value in bytes) {
        let byte = UInt8(value)
        result += digits[Int64(byte >> 4)]
        result += digits[Int64(byte & UInt8(0x0f))]
    }
    result
}

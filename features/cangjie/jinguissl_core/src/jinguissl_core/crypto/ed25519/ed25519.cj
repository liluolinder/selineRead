package jinguissl_core.crypto.ed25519

import std.collection.ArrayList
import std.math.numeric.{BigInt}
import jinguissl_core.crypto.bignum.BigNum
import jinguissl_core.crypto.digest.sha512
import jinguissl_core.crypto.error.{CryptoException, CryptoErrorCode}
import jinguissl_core.crypto.utils.csprngBytes

public let ED25519_SEED_LEN: Int64 = 32
public let ED25519_PUBLIC_KEY_LEN: Int64 = 32
public let ED25519_SIGNATURE_LEN: Int64 = 64

private let ED25519_SCALAR_BITS: Int64 = 256
private let ED25519_P: BigInt = BigNum.fromHex("7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffed").toBigInt()
private let ED25519_D: BigInt = BigNum.fromHex("52036cee2b6ffe738cc740797779e89800700a4d4141d8ab75eb4dca135978a3").toBigInt()
private let ED25519_ORDER_L: BigInt = BigNum.fromHex("1000000000000000000000000000000014def9dea2f79cd65812631a5cf5d3ed").toBigInt()
private let ED25519_SQRT_M1: BigInt = BigNum.fromHex("2b8324804fc1df0b2b4d00993dfbd7a72f431806ad2fe478c4ee1b274a0ea0b0").toBigInt()
private let ED25519_BASE_X: BigInt = BigNum.fromHex("216936d3cd6e53fec0a4e231fdd6dc5c692cc7609525a7b2c9562d608f25d51a").toBigInt()
private let ED25519_BASE_Y: BigInt = BigNum.fromHex("6666666666666666666666666666666666666666666666666666666666666658").toBigInt()
private let ED25519_BASE_POINT: Ed25519Point = Ed25519Point(ED25519_BASE_X, ED25519_BASE_Y)

private class Ed25519Point {
    let x: BigInt
    let y: BigInt

    init(x: BigInt, y: BigInt) {
        this.x = modP(x)
        this.y = modP(y)
    }

    static func identity(): Ed25519Point {
        Ed25519Point(BigInt(0), BigInt(1))
    }
}

public func ed25519GeneratePrivateKeySeed(): Array<Byte> {
    csprngBytes(ED25519_SEED_LEN)
}

public func ed25519PublicKeyFromSeed(privateKeySeed: Array<Byte>): Array<Byte> {
    let (secretScalar, _, _) = expandPrivateKeySeed(privateKeySeed)
    encodePoint(scalarMul(ED25519_BASE_POINT, secretScalar))
}

public func ed25519Sign(privateKeySeed: Array<Byte>, message: Array<Byte>): Array<Byte> {
    let (secretScalar, prefix, publicKey) = expandPrivateKeySeed(privateKeySeed)

    let nonceInput = ArrayList<Byte>()
    appendBytes(nonceInput, prefix)
    appendBytes(nonceInput, message)
    let nonceScalar = modOrder(decodeLittleEndianInt(sha512(nonceInput.toArray())))

    let encodedR = encodePoint(scalarMul(ED25519_BASE_POINT, nonceScalar))
    let challenge = computeChallenge(encodedR, publicKey, message)
    let scalarS = modOrder(nonceScalar + modOrder(challenge * secretScalar))

    let signature = Array<Byte>(ED25519_SIGNATURE_LEN, repeat: 0)
    copyInto(encodedR, signature, 0)
    copyInto(encodeLittleEndianIntFixed(scalarS, ED25519_PUBLIC_KEY_LEN), signature, ED25519_PUBLIC_KEY_LEN)
    signature
}

public func ed25519Verify(publicKey: Array<Byte>, message: Array<Byte>, signature: Array<Byte>): Bool {
    if (publicKey.size != ED25519_PUBLIC_KEY_LEN || signature.size != ED25519_SIGNATURE_LEN) {
        return false
    }

    try {
        let publicPoint = decodePoint(publicKey)
        let encodedR = signature[0..ED25519_PUBLIC_KEY_LEN]
        let encodedS = signature[ED25519_PUBLIC_KEY_LEN..]
        let pointR = decodePoint(encodedR)
        let publicPointIsSmallOrder = isSmallOrder(publicPoint)
        let pointRIsSmallOrder = isSmallOrder(pointR)
        if (publicPointIsSmallOrder || pointRIsSmallOrder) {
            return false
        }
        let scalarS = decodeLittleEndianInt(encodedS)
        if (scalarS < BigInt(0) || scalarS >= ED25519_ORDER_L) {
            return false
        }

        let challenge = computeChallenge(encodedR, publicKey, message)
        let lhs = scalarMul(ED25519_BASE_POINT, scalarS)
        let rhs = pointAdd(pointR, scalarMul(publicPoint, challenge))
        pointEquals(lhs, rhs)
    } catch (_: CryptoException) {
        false
    }
}

private func expandPrivateKeySeed(privateKeySeed: Array<Byte>): (BigInt, Array<Byte>, Array<Byte>) {
    if (privateKeySeed.size != ED25519_SEED_LEN) {
        throw CryptoException(InvalidArgument, "ed25519 private key seed must be 32 bytes")
    }

    let digest = sha512(privateKeySeed)
    let secretScalar = decodeLittleEndianInt(clampScalarBytes(digest[0..ED25519_SEED_LEN]))
    let prefix = digest[ED25519_SEED_LEN..]
    let publicKey = encodePoint(scalarMul(ED25519_BASE_POINT, secretScalar))
    (secretScalar, prefix, publicKey)
}

private func computeChallenge(encodedR: Array<Byte>, publicKey: Array<Byte>, message: Array<Byte>): BigInt {
    let input = ArrayList<Byte>()
    appendBytes(input, encodedR)
    appendBytes(input, publicKey)
    appendBytes(input, message)
    modOrder(decodeLittleEndianInt(sha512(input.toArray())))
}

private func decodePoint(encoded: Array<Byte>): Ed25519Point {
    if (encoded.size != ED25519_PUBLIC_KEY_LEN) {
        throw CryptoException(ParseError, "ed25519 encoded point must be 32 bytes")
    }

    let yEncoded = encoded.clone()
    let xSignBit = UInt8(UInt8(yEncoded[31]) >> UInt8(7))
    yEncoded[31] = UInt8(UInt8(yEncoded[31]) & UInt8(0x7f))

    let y = decodeLittleEndianInt(yEncoded)
    if (y < BigInt(0) || y >= ED25519_P) {
        throw CryptoException(ParseError, "ed25519 point y coordinate is out of range")
    }

    let ySquared = modP(y * y)
    let u = modP(ySquared - BigInt(1))
    let v = modP(modP(ED25519_D * ySquared) + BigInt(1))
    let xSquared = modP(u * modInverseP(v))
    var x = sqrtModP(xSquared)

    let shouldBeOdd = xSignBit == UInt8(1)
    if (isOdd(x) != shouldBeOdd) {
        x = modP(ED25519_P - x)
    }
    if (x == BigInt(0) && shouldBeOdd) {
        throw CryptoException(ParseError, "ed25519 point has invalid x sign bit")
    }

    let point = Ed25519Point(x, y)
    if (!isOnCurve(point)) {
        throw CryptoException(ParseError, "ed25519 point is not on curve")
    }
    point
}

private func encodePoint(point: Ed25519Point): Array<Byte> {
    let encoded = encodeLittleEndianIntFixed(point.y, ED25519_PUBLIC_KEY_LEN)
    if (isOdd(point.x)) {
        encoded[ED25519_PUBLIC_KEY_LEN - 1] =
            UInt8(UInt8(encoded[ED25519_PUBLIC_KEY_LEN - 1]) | UInt8(0x80))
    }
    encoded
}

private func isOnCurve(point: Ed25519Point): Bool {
    let xSquared = modP(point.x * point.x)
    let ySquared = modP(point.y * point.y)
    let left = modP(ySquared - xSquared)
    let right = modP(BigInt(1) + modP(ED25519_D * modP(xSquared * ySquared)))
    left == right
}

private func pointEquals(left: Ed25519Point, right: Ed25519Point): Bool {
    left.x == right.x && left.y == right.y
}

private func isSmallOrder(point: Ed25519Point): Bool {
    pointEquals(scalarMul(point, BigInt(8)), Ed25519Point.identity())
}

private func pointAdd(left: Ed25519Point, right: Ed25519Point): Ed25519Point {
    let x1x2 = modP(left.x * right.x)
    let y1y2 = modP(left.y * right.y)
    let dxxyy = modP(ED25519_D * modP(x1x2 * y1y2))

    let xNumerator = modP(modP(left.x * right.y) + modP(left.y * right.x))
    let yNumerator = modP(y1y2 + x1x2)
    let xDenominator = modP(BigInt(1) + dxxyy)
    let yDenominator = modP(BigInt(1) - dxxyy)

    let x = modP(xNumerator * modInverseP(xDenominator))
    let y = modP(yNumerator * modInverseP(yDenominator))
    Ed25519Point(x, y)
}

private func scalarMul(point: Ed25519Point, scalar: BigInt): Ed25519Point {
    if (scalar.sign < 0) {
        throw CryptoException(InvalidArgument, "ed25519 scalar must be non-negative")
    }

    let one = BigInt(1)
    var result = Ed25519Point.identity()
    var addend = point
    var bitIndex = Int64(0)

    // Fixed-round selection reduces scalar-bit control flow, but BigInt and inversion timing remain unproven.
    while (bitIndex < ED25519_SCALAR_BITS) {
        let bit = (scalar >> bitIndex) & one
        let candidate = pointAdd(result, addend)
        result = selectPoint(bit, candidate, result)
        addend = pointAdd(addend, addend)
        bitIndex += 1
    }
    result
}

private func selectPoint(bit: BigInt, ifOne: Ed25519Point, ifZero: Ed25519Point): Ed25519Point {
    Ed25519Point(selectBigInt(bit, ifOne.x, ifZero.x), selectBigInt(bit, ifOne.y, ifZero.y))
}

private func selectBigInt(bit: BigInt, ifOne: BigInt, ifZero: BigInt): BigInt {
    modP(ifZero + (bit * (ifOne - ifZero)))
}

private func bitLengthBigInt(value: BigInt): Int64 {
    let bytes = BigNum(value).toBytesBE()
    if (bytes.size == 0 || (bytes.size == 1 && bytes[0] == UInt8(0))) {
        return 0
    }
    var top = UInt8(bytes[0])
    var topBits: Int64 = 0
    while (top != UInt8(0)) {
        top = top >> 1
        topBits += 1
    }
    (bytes.size - 1) * 8 + topBits
}

private func sqrtModP(value: BigInt): BigInt {
    let normalized = modP(value)
    let exp = (ED25519_P + BigInt(3)) / BigInt(8)
    var root = normalized.modPow(exp, m: ED25519_P)
    if (modP(root * root - normalized) != BigInt(0)) {
        root = modP(root * ED25519_SQRT_M1)
    }
    if (modP(root * root - normalized) != BigInt(0)) {
        throw CryptoException(ParseError, "ed25519 point does not have square root")
    }
    root
}

private func modP(value: BigInt): BigInt {
    var reduced = value % ED25519_P
    if (reduced.sign < 0) {
        reduced += ED25519_P
    }
    reduced
}

private func modOrder(value: BigInt): BigInt {
    var reduced = value % ED25519_ORDER_L
    if (reduced.sign < 0) {
        reduced += ED25519_ORDER_L
    }
    reduced
}

private func modInverseP(value: BigInt): BigInt {
    let normalized = modP(value)
    if (normalized == BigInt(0)) {
        throw CryptoException(ParseError, "ed25519 modular inverse does not exist")
    }
    try {
        return modP(normalized.modInverse(ED25519_P))
    } catch (_: Exception) {
        throw CryptoException(ParseError, "ed25519 modular inverse failed")
    }
}

private func isOdd(value: BigInt): Bool {
    (value % BigInt(2)) != BigInt(0)
}

private func decodeLittleEndianInt(bytes: Array<Byte>): BigInt {
    if (bytes.size == 0) {
        return BigInt(0)
    }
    BigNum.fromBytesBE(reverseBytes(bytes)).toBigInt()
}

private func encodeLittleEndianIntFixed(value: BigInt, size: Int64): Array<Byte> {
    if (size < 0) {
        throw CryptoException(InvalidArgument, "ed25519 little-endian integer size must be non-negative")
    }
    if (value.sign < 0) {
        throw CryptoException(InvalidArgument, "ed25519 integer encoding requires non-negative value")
    }

    let out = Array<Byte>(size, repeat: 0)
    var current = value
    let base = BigInt(256)
    var i = 0
    while (i < size) {
        out[i] = UInt8((current % base).toInt64())
        current = current / base
        i += 1
    }
    if (current != BigInt(0)) {
        throw CryptoException(OutOfBounds, "ed25519 integer does not fit target width")
    }
    out
}

private func clampScalarBytes(bytes: Array<Byte>): Array<Byte> {
    if (bytes.size != ED25519_SEED_LEN) {
        throw CryptoException(InvalidArgument, "ed25519 scalar bytes must be 32 bytes")
    }
    let out = bytes.clone()
    out[0] = UInt8(UInt8(out[0]) & UInt8(0xf8))
    out[31] = UInt8(UInt8(out[31]) & UInt8(0x3f))
    out[31] = UInt8(UInt8(out[31]) | UInt8(0x40))
    out
}

private func copyInto(source: Array<Byte>, destination: Array<Byte>, offset: Int64): Unit {
    if (offset < 0 || offset + source.size > destination.size) {
        throw CryptoException(OutOfBounds, "ed25519 copy destination is out of bounds")
    }
    var i = 0
    while (i < source.size) {
        destination[offset + i] = source[i]
        i += 1
    }
}

private func reverseBytes(bytes: Array<Byte>): Array<Byte> {
    let out = Array<Byte>(bytes.size, repeat: 0)
    var i = 0
    while (i < bytes.size) {
        out[bytes.size - 1 - i] = bytes[i]
        i += 1
    }
    out
}

private func appendBytes(out: ArrayList<Byte>, data: Array<Byte>): Unit {
    for (b in data) {
        out.add(b)
    }
}

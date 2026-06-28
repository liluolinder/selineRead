package jinguissl_core.crypto.x25519

import std.math.numeric.BigInt
import jinguissl_core.crypto.bignum.BigNum
import jinguissl_core.crypto.error.{CryptoException, CryptoErrorCode}
import jinguissl_core.crypto.utils.csprngBytes

public let X25519_KEY_LEN: Int64 = 32
public let X25519_SHARED_SECRET_LEN: Int64 = 32

private let X25519_A24: BigNum = BigNum.fromHex("1db41")
private let X25519_BASEPOINT_U: Array<Byte> = [
    UInt8(0x09), UInt8(0x00), UInt8(0x00), UInt8(0x00),
    UInt8(0x00), UInt8(0x00), UInt8(0x00), UInt8(0x00),
    UInt8(0x00), UInt8(0x00), UInt8(0x00), UInt8(0x00),
    UInt8(0x00), UInt8(0x00), UInt8(0x00), UInt8(0x00),
    UInt8(0x00), UInt8(0x00), UInt8(0x00), UInt8(0x00),
    UInt8(0x00), UInt8(0x00), UInt8(0x00), UInt8(0x00),
    UInt8(0x00), UInt8(0x00), UInt8(0x00), UInt8(0x00),
    UInt8(0x00), UInt8(0x00), UInt8(0x00), UInt8(0x00)
]
private let X25519_P: BigNum = BigNum.fromHex(
    "7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffed"
)

public func x25519GeneratePrivateKey(): Array<Byte> {
    x25519ClampPrivateKey(csprngBytes(X25519_KEY_LEN))
}

public func x25519ClampPrivateKey(privateKey: Array<Byte>): Array<Byte> {
    x25519RequireKeyLength(privateKey, "X25519 private key")
    let clamped = privateKey.clone()
    clamped[0] = UInt8(UInt8(clamped[0]) & UInt8(0xf8))
    clamped[31] = UInt8(UInt8(clamped[31]) & UInt8(0x7f))
    clamped[31] = UInt8(UInt8(clamped[31]) | UInt8(0x40))
    clamped
}

public func x25519ValidatePublicKey(publicKey: Array<Byte>): Unit {
    x25519RequireKeyLength(publicKey, "X25519 public key")
}

public func x25519PublicFromPrivate(privateKey: Array<Byte>): Array<Byte> {
    x25519ScalarMult(privateKey, X25519_BASEPOINT_U)
}

/**
 * x25519DeriveSharedSecret.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func x25519DeriveSharedSecret(privateKey: Array<Byte>, peerPublicKey: Array<Byte>): Array<Byte> {
    x25519ValidatePublicKey(peerPublicKey)
    let shared = x25519ScalarMult(privateKey, peerPublicKey)
    if (isAllZero(shared)) {
        throw CryptoException(InvalidArgument, "X25519 shared secret resolves to all-zero")
    }
    shared
}

/**
 * x25519ScalarMult.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func x25519ScalarMult(privateKey: Array<Byte>, uCoordinate: Array<Byte>): Array<Byte> {
    x25519RequireKeyLength(privateKey, "X25519 private key")
    x25519RequireKeyLength(uCoordinate, "X25519 u-coordinate")

    let scalar = x25519ClampPrivateKey(privateKey)
    let x1 = decodeLittleEndian(modReduceUCoordinate(uCoordinate))
    var x2 = BigNum.one()
    var z2 = BigNum.zero()
    var x3 = x1
    var z3 = BigNum.one()
    var swapBit: Int64 = 0

    var bit = Int64(254)
    while (bit >= 0) {
        let kBit = scalarBit(scalar, bit)
        let shouldSwap = swapBit ^ kBit
        let (nx2, nx3) = cswap(shouldSwap, x2, x3)
        let (nz2, nz3) = cswap(shouldSwap, z2, z3)
        x2 = nx2
        x3 = nx3
        z2 = nz2
        z3 = nz3
        swapBit = kBit

        let a = modP(x2.add(z2))
        let aa = modP(a.mul(a))
        let b = modP(x2.sub(z2))
        let bb = modP(b.mul(b))
        let e = modP(aa.sub(bb))
        let c = modP(x3.add(z3))
        let d = modP(x3.sub(z3))
        let da = modP(d.mul(a))
        let cb = modP(c.mul(b))
        let daPlusCb = modP(da.add(cb))
        let daMinusCb = modP(da.sub(cb))

        x3 = modP(daPlusCb.mul(daPlusCb))
        z3 = modP(x1.mul(modP(daMinusCb.mul(daMinusCb))))
        x2 = modP(aa.mul(bb))
        z2 = modP(e.mul(modP(aa.add(modP(X25519_A24.mul(e))))))
        bit -= 1
    }

    let (nx2, nx3) = cswap(swapBit, x2, x3)
    let (nz2, nz3) = cswap(swapBit, z2, z3)
    x2 = nx2
    x3 = nx3
    z2 = nz2
    z3 = nz3

    let inv = try {
        z2.modInversePrimeFixedSchedule(X25519_P, 255)
    } catch (_: CryptoException) {
        throw CryptoException(ParseError, "X25519 scalar multiplication result is not invertible")
    }
    encodeLittleEndian(modP(x2.mul(inv)), X25519_SHARED_SECRET_LEN)
}

/**
 * cswap — branchless conditional swap.
 *
 * Returns (left, right) when swap is 0, and (right, left) when swap is 1.
 * Always computes both outcomes and selects via arithmetic; no data-dependent
 * branch on the swap bit.
 */
private func cswap(swap: Int64, left: BigNum, right: BigNum): (BigNum, BigNum) {
    let s = BigNum(BigInt(swap))
    let ns = BigNum(BigInt(1 - swap))
    (left.mul(ns).add(right.mul(s)), left.mul(s).add(right.mul(ns)))
}

private func modReduceUCoordinate(value: Array<Byte>): Array<Byte> {
    let out = value.clone()
    out[31] = UInt8(UInt8(out[31]) & UInt8(0x7f))
    out
}

private func x25519RequireKeyLength(key: Array<Byte>, label: String): Unit {
    if (key.size != X25519_KEY_LEN) {
        throw CryptoException(InvalidArgument, "${label} must be 32 bytes")
    }
}

private func scalarBit(scalar: Array<Byte>, bitIndex: Int64): Int64 {
    let byteIndex = bitIndex / 8
    let bitOffset = bitIndex % 8
    Int64((UInt8(scalar[byteIndex]) >> UInt8(bitOffset)) & UInt8(0x01))
}

private func modP(value: BigNum): BigNum {
    value.mod(X25519_P)
}

private func decodeLittleEndian(bytes: Array<Byte>): BigNum {
    BigNum.fromBytesBE(reverseBytes(bytes))
}

private func encodeLittleEndian(value: BigNum, size: Int64): Array<Byte> {
    reverseBytes(value.toBytesBE(paddedLen: size))
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

private func isAllZero(bytes: Array<Byte>): Bool {
    var acc: UInt8 = 0
    var i = 0
    while (i < bytes.size) {
        acc = acc | UInt8(bytes[i])
        i += 1
    }
    acc == UInt8(0)
}

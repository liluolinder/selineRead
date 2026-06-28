package jinguissl_core.crypto.ecc

import std.math.numeric.{BigInt}
import jinguissl_core.crypto.bignum.BigNum
import jinguissl_core.crypto.compliance.FipsProfile
import jinguissl_core.crypto.error.{CryptoException, CryptoErrorCode}
import jinguissl_core.crypto.utils.randomSeed

public enum NamedCurve <: Equatable<NamedCurve> & ToString {
    | P256
    | P384
    | P521
    | SECP256K1

    public operator func ==(right: NamedCurve): Bool {
        ordinalValue() == right.ordinalValue()
    }

    public operator func !=(right: NamedCurve): Bool {
        !(this == right)
    }

    public func ordinalValue(): Int64 {
        match (this) {
            case P256 => 0
            case P384 => 1
            case P521 => 2
            case SECP256K1 => 3
        }
    }

    public func toString(): String {
        match (this) {
            case P256 => "P-256"
            case P384 => "P-384"
            case P521 => "P-521"
            case SECP256K1 => "secp256k1"
        }
    }
}

public class EcPublicKey {
    public let curve: NamedCurve
    public let x: BigNum
    public let y: BigNum

    public init(curve: NamedCurve, x: BigNum, y: BigNum) {
        validateCoordinate(x, "x")
        validateCoordinate(y, "y")
        let params = paramsForCurve(curve)
        if (!isPointOnCurve(x, y, params)) {
            throw CryptoException(InvalidArgument, "public key point is not on curve")
        }
        this.curve = curve
        this.x = x
        this.y = y
    }
}

public class EcPrivateKey {
    public let curve: NamedCurve
    public let scalar: BigNum

    public init(curve: NamedCurve, scalar: BigNum) {
        if (scalar.isZero() || scalar.isNegative()) {
            throw CryptoException(InvalidArgument, "EC private scalar must be positive")
        }
        this.curve = curve
        this.scalar = scalar
    }
}

/**
 * namedCurveFromText.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func namedCurveFromText(name: String): NamedCurve {
    let key = name.trimAscii().toAsciiUpper().replace("-", "").replace("_", "")
    match (key) {
        case "P256" | "SECP256R1" | "PRIME256V1" => P256
        case "P384" | "SECP384R1" => P384
        case "P521" | "SECP521R1" => P521
        case "SECP256K1" => SECP256K1
        case _ =>
            throw CryptoException(InvalidArgument, "unknown curve: ${name}")
    }
}

public func isFipsCurve(curve: NamedCurve): Bool {
    match (curve) {
        case P256 | P384 | P521 => true
        case SECP256K1 => false
    }
}

/**
 * requireFipsCurve.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func requireFipsCurve(curve: NamedCurve): Unit {
    if (!isFipsCurve(curve)) {
        throw CryptoException(ComplianceRejected, "curve is blocked by FIPS profile: ${curve.toString()}")
    }
}

public func ecdsaRequireAllowed(profile: FipsProfile): Unit {
    profile.requireAllowed("ECDSA")
}

public func ecdhRequireAllowed(profile: FipsProfile): Unit {
    profile.requireAllowed("ECDH")
}

/**
 * ecdsaSign.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func ecdsaSign(privateKey: EcPrivateKey, digest: Array<Byte>): (BigNum, BigNum) {
    let params = paramsForCurve(privateKey.curve)
    let d = normalizeScalar(privateKey.scalar, params.n)
    let z = digestToCurveScalar(digest, params.n)
    let g = AffinePoint(params.gx, params.gy)
    let scalarBytes = fieldByteLength(params.n)
    let orderBits = bitLength(params.n)

    var attempt = 0
    while (attempt < 128) {
        let k = try {
            normalizeScalar(BigNum.fromBytesBE(randomSeed(size: scalarBytes)), params.n)
        } catch (_: CryptoException) {
            attempt += 1
            continue
        }

        let p = scalarMulProjectivePoint(g, k, params)
        if (p.infinity) {
            attempt += 1
            continue
        }

        let r = modNormalize(p.x, params.n)
        if (r.isZero()) {
            attempt += 1
            continue
        }

        let kInv = try {
            k.modInversePrimeFixedSchedule(params.n, orderBits)
        } catch (_: CryptoException) {
            attempt += 1
            continue
        }

        let s = modNormalize(kInv.mul(z.add(r.mul(d))), params.n)
        if (s.isZero()) {
            attempt += 1
            continue
        }

        return (r, s)
    }

    throw CryptoException(InternalError, "ECDSA sign failed to generate non-zero signature")
}

public func ecdsaVerify(publicKey: EcPublicKey, digest: Array<Byte>, r: BigNum, s: BigNum): Bool {
    let params = paramsForCurve(publicKey.curve)
    if (!isInRange(r, params.n) || !isInRange(s, params.n)) {
        return false
    }

    let q = AffinePoint(publicKey.x, publicKey.y)
    if (!isPointOnCurve(q.x, q.y, params)) {
        return false
    }

    let z = digestToCurveScalar(digest, params.n)
    let orderBits = bitLength(params.n)

    let w = try {
        s.modInversePrimeFixedSchedule(params.n, orderBits)
    } catch (_: CryptoException) {
        return false
    }

    let u1 = modNormalize(z.mul(w), params.n)
    let u2 = modNormalize(r.mul(w), params.n)
    let g = AffinePoint(params.gx, params.gy)

    let p1 = scalarMulProjectivePoint(g, u1, params)
    let p2 = scalarMulProjectivePoint(q, u2, params)
    let p = pointAdd(p1, p2, params)
    if (p.infinity) {
        return false
    }

    let v = modNormalize(p.x, params.n)
    v.cmp(r) == 0
}

/**
 * ecdhDeriveSharedSecret.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func ecdhDeriveSharedSecret(privateKey: EcPrivateKey, peerPublicKey: EcPublicKey): Array<Byte> {
    if (privateKey.curve != peerPublicKey.curve) {
        throw CryptoException(InvalidArgument, "ECDH key curve mismatch")
    }
    let params = paramsForCurve(privateKey.curve)
    let scalar = normalizeScalar(privateKey.scalar, params.n)
    let peer = AffinePoint(peerPublicKey.x, peerPublicKey.y)
    if (!isPointOnCurve(peer.x, peer.y, params)) {
        throw CryptoException(InvalidArgument, "peer public key point is not on curve")
    }

    let shared = scalarMulProjectivePoint(peer, scalar, params)
    if (shared.infinity) {
        throw CryptoException(InvalidArgument, "ECDH shared point is at infinity")
    }
    shared.x.toBytesBE(paddedLen: fieldByteLength(params.p))
}

/**
 * ecPublicFromPrivateKey.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func ecPublicFromPrivateKey(privateKey: EcPrivateKey): EcPublicKey {
    let params = paramsForCurve(privateKey.curve)
    let scalar = normalizeScalar(privateKey.scalar, params.n)
    let g = AffinePoint(params.gx, params.gy)
    let publicPoint = scalarMulProjectivePoint(g, scalar, params)
    if (publicPoint.infinity) {
        throw CryptoException(InvalidArgument, "EC public key derivation returned point at infinity")
    }
    EcPublicKey(privateKey.curve, publicPoint.x, publicPoint.y)
}

private class CurveParams {
    let p: BigNum
    let a: BigNum
    let b: BigNum
    let gx: BigNum
    let gy: BigNum
    let n: BigNum

    init(
        p: BigNum,
        a: BigNum,
        b: BigNum,
        gx: BigNum,
        gy: BigNum,
        n: BigNum
    ) {
        this.p = p
        this.a = a
        this.b = b
        this.gx = gx
        this.gy = gy
        this.n = n
    }
}

private class AffinePoint {
    let infinity: Bool
    let x: BigNum
    let y: BigNum

    init(x: BigNum, y: BigNum) {
        this.infinity = false
        this.x = x
        this.y = y
    }

    init(infinity: Bool) {
        this.infinity = infinity
        this.x = BigNum.zero()
        this.y = BigNum.zero()
    }

    static func infinityPoint(): AffinePoint {
        AffinePoint(true)
    }
}

private func paramsForCurve(curve: NamedCurve): CurveParams {
    match (curve) {
        case P256 => p256Params()
        case P384 => p384Params()
        case P521 => p521Params()
        case SECP256K1 => secp256k1Params()
    }
}

private func p256Params(): CurveParams {
    CurveParams(
        BigNum.fromHex("FFFFFFFF00000001000000000000000000000000FFFFFFFFFFFFFFFFFFFFFFFF"),
        BigNum.fromHex("FFFFFFFF00000001000000000000000000000000FFFFFFFFFFFFFFFFFFFFFFFC"),
        BigNum.fromHex("5AC635D8AA3A93E7B3EBBD55769886BC651D06B0CC53B0F63BCE3C3E27D2604B"),
        BigNum.fromHex("6B17D1F2E12C4247F8BCE6E563A440F277037D812DEB33A0F4A13945D898C296"),
        BigNum.fromHex("4FE342E2FE1A7F9B8EE7EB4A7C0F9E162BCE33576B315ECECBB6406837BF51F5"),
        BigNum.fromHex("FFFFFFFF00000000FFFFFFFFFFFFFFFFBCE6FAADA7179E84F3B9CAC2FC632551")
    )
}

private func p384Params(): CurveParams {
    CurveParams(
        BigNum.fromHex("FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFFFF0000000000000000FFFFFFFF"),
        BigNum.fromHex("FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFFFF0000000000000000FFFFFFFC"),
        BigNum.fromHex("B3312FA7E23EE7E4988E056BE3F82D19181D9C6EFE8141120314088F5013875AC656398D8A2ED19D2A85C8EDD3EC2AEF"),
        BigNum.fromHex("AA87CA22BE8B05378EB1C71EF320AD746E1D3B628BA79B9859F741E082542A385502F25DBF55296C3A545E3872760AB7"),
        BigNum.fromHex("3617DE4A96262C6F5D9E98BF9292DC29F8F41DBD289A147CE9DA3113B5F0B8C00A60B1CE1D7E819D7A431D7C90EA0E5F"),
        BigNum.fromHex("FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFC7634D81F4372DDF581A0DB248B0A77AECEC196ACCC52973")
    )
}

private func p521Params(): CurveParams {
    CurveParams(
        BigNum.fromHex("1FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF"),
        BigNum.fromHex("1FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFC"),
        BigNum.fromHex("51953EB9618E1C9A1F929A21A0B68540EEA2DA725B99B315F3B8B489918EF109E156193951EC7E937B1652C0BD3BB1BF073573DF883D2C34F1EF451FD46B503F00"),
        BigNum.fromHex("C6858E06B70404E9CD9E3ECB662395B4429C648139053FB521F828AF606B4D3DBAA14B5E77EFE75928FE1DC127A2FFA8DE3348B3C1856A429BF97E7E31C2E5BD66"),
        BigNum.fromHex("11839296A789A3BC0045C8A5FB42C7D1BD998F54449579B446817AFBD17273E662C97EE72995EF42640C550B9013FAD0761353C7086A272C24088BE94769FD16650"),
        BigNum.fromHex("1FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFA51868783BF2F966B7FCC0148F709A5D03BB5C9B8899C47AEBB6FB71E91386409")
    )
}

private func secp256k1Params(): CurveParams {
    CurveParams(
        BigNum.fromHex("FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC2F"),
        BigNum.zero(),
        BigNum.fromHex("07"),
        BigNum.fromHex("79BE667EF9DCBBAC55A06295CE870B07029BFCDB2DCE28D959F2815B16F81798"),
        BigNum.fromHex("483ADA7726A3C4655DA4FBFC0E1108A8FD17B448A68554199C47D08FFB10D4B8"),
        BigNum.fromHex("FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141")
    )
}

private func validateCoordinate(value: BigNum, label: String): Unit {
    if (value.isNegative()) {
        throw CryptoException(InvalidArgument, "EC ${label} must be non-negative")
    }
}

private func isPointOnCurve(x: BigNum, y: BigNum, params: CurveParams): Bool {
    let lhs = modNormalize(y.mul(y), params.p)
    let rhs = modNormalize(
        x.mul(x).mul(x).add(params.a.mul(x)).add(params.b),
        params.p
    )
    lhs.cmp(rhs) == 0
}

private func isInRange(value: BigNum, upper: BigNum): Bool {
    if (value.isZero() || value.isNegative()) {
        return false
    }
    value.cmp(upper) < 0
}

private func normalizeScalar(value: BigNum, order: BigNum): BigNum {
    if (value.isNegative()) {
        throw CryptoException(InvalidArgument, "EC scalar must be non-negative")
    }
    let out = modNormalize(value, order)
    if (out.isZero()) {
        throw CryptoException(InvalidArgument, "EC scalar must be in [1, n-1]")
    }
    out
}

private func digestToCurveScalar(digest: Array<Byte>, order: BigNum): BigNum {
    let z = BigNum.fromBytesBE(digest)
    let digestBits = digest.size * 8
    let orderBits = bitLength(order)
    if (digestBits > orderBits) {
        return z.rshift(digestBits - orderBits)
    }
    z
}

private func pointAdd(p: AffinePoint, q: AffinePoint, params: CurveParams): AffinePoint {
    if (p.infinity) {
        return q
    }
    if (q.infinity) {
        return p
    }

    if (p.x.cmp(q.x) == 0) {
        let ySum = modNormalize(p.y.add(q.y), params.p)
        if (ySum.isZero()) {
            return AffinePoint.infinityPoint()
        }
        return pointDouble(p, params)
    }

    let numerator = modNormalize(q.y.sub(p.y), params.p)
    let denominator = modNormalize(q.x.sub(p.x), params.p)
    let inv = denominator.modInverse(params.p)
    let lambda = modNormalize(numerator.mul(inv), params.p)

    let x3 = modNormalize(lambda.mul(lambda).sub(p.x).sub(q.x), params.p)
    let y3 = modNormalize(lambda.mul(p.x.sub(x3)).sub(p.y), params.p)
    AffinePoint(x3, y3)
}

private func pointDouble(p: AffinePoint, params: CurveParams): AffinePoint {
    if (p.infinity) {
        return p
    }
    if (modNormalize(p.y, params.p).isZero()) {
        return AffinePoint.infinityPoint()
    }

    let three = BigNum.fromHex("3")
    let two = BigNum.fromHex("2")
    let numerator = modNormalize(three.mul(p.x.mul(p.x)).add(params.a), params.p)
    let denominator = modNormalize(two.mul(p.y), params.p)
    let inv = denominator.modInverse(params.p)
    let lambda = modNormalize(numerator.mul(inv), params.p)

    let x3 = modNormalize(lambda.mul(lambda).sub(p.x).sub(p.x), params.p)
    let y3 = modNormalize(lambda.mul(p.x.sub(x3)).sub(p.y), params.p)
    AffinePoint(x3, y3)
}

private func scalarMul(point: AffinePoint, scalar: BigNum, params: CurveParams): AffinePoint {
    if (point.infinity || scalar.isZero()) {
        return AffinePoint.infinityPoint()
    }

    let orderBits = bitLength(params.n)
    let k = scalar.toBigInt()
    let zero = BigInt(0)
    let one = BigInt(1)
    var result = AffinePoint.infinityPoint()
    var addend = point
    var bitIndex = Int64(0)

    while (bitIndex < orderBits) {
        if (((k >> bitIndex) & one) != zero) {
            result = pointAdd(result, addend, params)
        }
        addend = pointDouble(addend, params)
        bitIndex += 1
    }
    result
}

private func modNormalize(value: BigNum, modulus: BigNum): BigNum {
    value.mod(modulus)
}

private func bitLength(value: BigNum): Int64 {
    let bytes = value.toBytesBE()
    if (bytes.size == 0 || (bytes.size == 1 && UInt8(bytes[0]) == UInt8(0))) {
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

private func fieldByteLength(prime: BigNum): Int64 {
    let bits = bitLength(prime)
    (bits + 7) / 8
}

// Projective/Jacobian coordinate helpers used as ECC groundwork.
private class JacobianPoint {
    let infinity: Bool
    let x: BigNum
    let y: BigNum
    let z: BigNum

    init(x: BigNum, y: BigNum, z: BigNum) {
        this.infinity = false
        this.x = x
        this.y = y
        this.z = z
    }

    init(infinity: Bool) {
        this.infinity = infinity
        this.x = BigNum.zero()
        this.y = BigNum.zero()
        this.z = BigNum.zero()
    }

    static func infinityPoint(): JacobianPoint {
        JacobianPoint(true)
    }
}

private func affineToJacobian(p: AffinePoint): JacobianPoint {
    if (p.infinity) {
        return JacobianPoint.infinityPoint()
    }
    JacobianPoint(p.x, p.y, BigNum.one())
}

private func jacobianToAffine(p: JacobianPoint, params: CurveParams): AffinePoint {
    if (p.infinity) {
        return AffinePoint.infinityPoint()
    }
    let primeBits = bitLength(params.p)
    let zInv = p.z.modInversePrimeFixedSchedule(params.p, primeBits)
    let zInvSq = zInv.mul(zInv).mod(params.p)
    let zInvCu = zInvSq.mul(zInv).mod(params.p)
    let x3 = p.x.mul(zInvSq).mod(params.p)
    let y3 = p.y.mul(zInvCu).mod(params.p)
    AffinePoint(x3, y3)
}

private func jacobianDouble(p: JacobianPoint, params: CurveParams): JacobianPoint {
    if (p.infinity) {
        return p
    }
    let yNorm = modNormalize(p.y, params.p)
    if (yNorm.isZero()) {
        return JacobianPoint.infinityPoint()
    }

    let three = BigNum.fromHex("3")
    let two = BigNum.fromHex("2")
    let four = BigNum.fromHex("4")
    let eight = BigNum.fromHex("8")

    let x1Sq = p.x.mul(p.x).mod(params.p)
    let y1Sq = yNorm.mul(yNorm).mod(params.p)
    let z1Sq = p.z.mul(p.z).mod(params.p)

    let sVal = four.mul(p.x.mul(y1Sq)).mod(params.p)

    let aIsMinus3 = (params.a.cmp(params.p.sub(three)) == 0)
    var mVal: BigNum
    if (aIsMinus3) {
        let xMinusZsq = p.x.sub(z1Sq).mod(params.p)
        let xPlusZsq = p.x.add(z1Sq).mod(params.p)
        mVal = three.mul(xMinusZsq.mul(xPlusZsq)).mod(params.p)
    } else {
        let z1Pow4 = z1Sq.mul(z1Sq).mod(params.p)
        mVal = three.mul(x1Sq).add(params.a.mul(z1Pow4)).mod(params.p)
    }

    let x3 = mVal.mul(mVal).sub(two.mul(sVal)).mod(params.p)
    let y1Pow4 = y1Sq.mul(y1Sq).mod(params.p)
    let y3 = mVal.mul(sVal.sub(x3)).sub(eight.mul(y1Pow4)).mod(params.p)
    let z3 = two.mul(yNorm).mul(p.z).mod(params.p)

    JacobianPoint(x3, y3, z3)
}

private func jacobianAdd(p: JacobianPoint, q: JacobianPoint, params: CurveParams): JacobianPoint {
    if (p.infinity) {
        return q
    }
    if (q.infinity) {
        return p
    }

    let z1Sq = p.z.mul(p.z).mod(params.p)
    let z2Sq = q.z.mul(q.z).mod(params.p)

    let u1 = p.x.mul(z2Sq).mod(params.p)
    let u2 = q.x.mul(z1Sq).mod(params.p)
    let s1 = p.y.mul(z2Sq.mul(q.z)).mod(params.p)
    let s2 = q.y.mul(z1Sq.mul(p.z)).mod(params.p)

    let hVal = u2.sub(u1).mod(params.p)
    if (hVal.isZero()) {
        let rCheck = s2.sub(s1).mod(params.p)
        if (rCheck.isZero()) {
            return jacobianDouble(p, params)
        }
        return JacobianPoint.infinityPoint()
    }
    let rVal = s2.sub(s1).mod(params.p)

    let hSq = hVal.mul(hVal).mod(params.p)
    let hCu = hSq.mul(hVal).mod(params.p)
    let two = BigNum.fromHex("2")

    let x3 = rVal.mul(rVal).sub(hCu).sub(two.mul(u1.mul(hSq))).mod(params.p)
    let y3 = rVal.mul(u1.mul(hSq).sub(x3)).sub(s1.mul(hCu)).mod(params.p)
    let z3 = hVal.mul(p.z).mul(q.z).mod(params.p)

    JacobianPoint(x3, y3, z3)
}

/** @internal - projective scalar multiplication parity hook for Core tests; not a contract facade. */
public func scalarMulProjective(
    gx: BigNum, gy: BigNum, scalar: BigNum, curve: NamedCurve
): (BigNum, BigNum, Bool) {
    let params = paramsForCurve(curve)
    let point = AffinePoint(gx, gy)
    let affineResult = scalarMulProjectivePoint(point, scalar, params)
    (affineResult.x, affineResult.y, affineResult.infinity)
}

private func scalarMulProjectivePoint(
    point: AffinePoint, scalar: BigNum, params: CurveParams
): AffinePoint {
    if (point.infinity || scalar.isZero()) {
        return AffinePoint.infinityPoint()
    }

    let orderBits = bitLength(params.n)
    let k = scalar.toBigInt()
    let zero = BigInt(0)
    let one = BigInt(1)
    var result = JacobianPoint.infinityPoint()
    var addend = affineToJacobian(point)

    var bitIndex = Int64(0)
    while (bitIndex < orderBits) {
        if (((k >> bitIndex) & one) != zero) {
            result = jacobianAdd(result, addend, params)
        }
        addend = jacobianDouble(addend, params)
        bitIndex += 1
    }

    jacobianToAffine(result, params)
}

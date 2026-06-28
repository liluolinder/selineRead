package jinguissl_core.crypto.bignum

import std.math.numeric.{BigInt, abs}
import std.collection.ArrayList
import jinguissl_core.crypto.error.{CryptoException, CryptoErrorCode}

public class BigNum <: Equatable<BigNum> & ToString {
    let _value: BigInt
    public let sign: Int64
    public let limbs: Array<UInt32>

    public init(value: BigInt) {
        this._value = value
        this.sign = value.sign
        this.limbs = magnitudeToLittleEndianLimbs(abs(value).toBytes())
    }

    public static func zero(): BigNum {
        BigNum(BigInt(0))
    }

    public static func one(): BigNum {
        BigNum(BigInt(1))
    }

    public static func fromHex(hex: String): BigNum {
        var text = hex.trimAscii()
        if (text.size == 0) {
            throw CryptoException(ParseError, "empty hex text")
        }

        var negative = false
        if (text.startsWith("+")) {
            text = text[1..]
        } else if (text.startsWith("-")) {
            negative = true
            text = text[1..]
        }

        if (text.startsWith("0x") || text.startsWith("0X")) {
            text = text[2..]
        }

        text = trimLeadingHexZeros(text)
        if (text.size == 0) {
            return BigNum.zero()
        }

        try {
            var parsed = BigInt.parse(text, radix: 16)
            if (negative) {
                parsed = -parsed
            }
            return BigNum(parsed)
        } catch (_: Exception) {
            throw CryptoException(ParseError, "invalid hex string: ${hex}")
        }
    }

    public static func fromBytesBE(bytes: Array<Byte>, negative!: Bool = false): BigNum {
        if (bytes.size == 0) {
            return BigNum.zero()
        }
        let normalized = trimLeadingZeroBytes(bytes)
        if (normalized.size == 0) {
            return BigNum.zero()
        }
        if (negative) {
            return BigNum(BigInt(false, normalized))
        }
        BigNum(BigInt(true, normalized))
    }

    public func toBigInt(): BigInt {
        _value
    }

    /**
 * toBytesBE.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func toBytesBE(paddedLen!: Int64 = -1): Array<Byte> {
        var raw = trimLeadingZeroBytes(abs(_value).toBytes())
        if (raw.size == 0) {
            raw = [0]
        }
        if (paddedLen < 0) {
            return raw
        }
        if (raw.size > paddedLen) {
            throw CryptoException(OutOfBounds, "output buffer too small")
        }
        let out = Array<Byte>(paddedLen, repeat: 0)
        var i = 0
        while (i < raw.size) {
            out[paddedLen - raw.size + i] = raw[i]
            i += 1
        }
        out
    }

    public func toHex(): String {
        let digits: Array<String> = [
            "0", "1", "2", "3", "4", "5", "6", "7",
            "8", "9", "a", "b", "c", "d", "e", "f"
        ]
        let bytes = trimLeadingZeroBytes(abs(_value).toBytes())
        if (bytes.size == 0) {
            return "0"
        }
        var out = ""
        for (b in bytes) {
            let ub = UInt8(b)
            let hi = Int64((ub >> 4) & 0x0F)
            let lo = Int64(ub & 0x0F)
            out += digits[hi]
            out += digits[lo]
        }
        if (_value.sign < 0) {
            return "-${out}"
        }
        out
    }

    public func add(other: BigNum): BigNum {
        BigNum(_value + other._value)
    }

    public func sub(other: BigNum): BigNum {
        BigNum(_value - other._value)
    }

    public func mul(other: BigNum): BigNum {
        BigNum(_value * other._value)
    }

    /**
 * divMod.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func divMod(other: BigNum): (BigNum, BigNum) {
        if (other._value.sign == 0) {
            throw CryptoException(DivideByZero, "divide by zero")
        }
        let (q, r) = _value.divAndMod(other._value)
        (BigNum(q), BigNum(r))
    }

    /**
 * mod.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func mod(other: BigNum): BigNum {
        let m = abs(other._value)
        if (m.sign == 0) {
            throw CryptoException(DivideByZero, "mod by zero")
        }
        BigNum(normalizeMod(_value, m))
    }

    /**
 * exp.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func exp(exponent: BigNum): BigNum {
        if (exponent._value.sign < 0) {
            throw CryptoException(InvalidArgument, "negative exponent is not supported")
        }

        var e = exponent._value
        var base = _value
        var result = BigInt(1)
        let zero = BigInt(0)
        let two = BigInt(2)
        while (e > zero) {
            if ((e % two) != zero) {
                result = result * base
            }
            e = e >> 1
            if (e > zero) {
                base = base * base
            }
        }
        BigNum(result)
    }

    /**
 * modExp.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func modExp(exponent: BigNum, modulus: BigNum): BigNum {
        let m = abs(modulus._value)
        if (m.sign == 0) {
            throw CryptoException(DivideByZero, "modulus must not be zero")
        }
        if (exponent._value.sign < 0) {
            throw CryptoException(InvalidArgument, "negative exponent is not supported")
        }

        // Phase-1: odd modulus path is only a modPow wrapper; keep the
        // wording honest until a real Montgomery implementation exists.
        let result = if (isOdd(m)) {
            oddModulusModPowPhase1(_value, exponent._value, m)
        } else {
            _value.modPow(exponent._value, m: m)
        }
        BigNum(normalizeMod(result, m))
    }

    /**
 * modInverse.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func modInverse(modulus: BigNum): BigNum {
        let m = abs(modulus._value)
        if (m.sign == 0) {
            throw CryptoException(DivideByZero, "modulus must not be zero")
        }
        try {
            let inv = _value.modInverse(m)
            return BigNum(normalizeMod(inv, m))
        } catch (_: Exception) {
            throw CryptoException(NoModInverse, "mod inverse does not exist")
        }
    }

    /**
 * modInversePrimeFixedSchedule.
 *
 * Fixed-round prime-modulus inversion via Fermat: this^(p - 2) mod p.
 *
 * This avoids BigInt.modInverse and BigInt.modPow, but it is not a
 * constant-time certificate. The exponent comes from the public prime modulus,
 * while BigInt multiplication, modulo, allocation, and the public-exponent bit
 * branch remain outside JinguiSSL's constant-time control.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func modInversePrimeFixedSchedule(primeModulus: BigNum, bitLength: Int64): BigNum {
        let p = abs(primeModulus._value)
        if (p <= BigInt(1)) {
            throw CryptoException(InvalidArgument, "prime modulus must be > 1")
        }
        if (!isOdd(p)) {
            throw CryptoException(InvalidArgument, "prime modulus must be odd")
        }
        if (bitLength <= 0) {
            throw CryptoException(InvalidArgument, "bitLength must be > 0")
        }

        let two = BigInt(2)
        let exponent = p - two
        let zero = BigInt(0)
        var result = BigInt(1)
        var base = normalizeMod(_value, p)
        if (base == zero) {
            throw CryptoException(NoModInverse, "mod inverse does not exist")
        }

        var i: Int64 = 0
        while (i < bitLength) {
            let multiplied = (result * base) % p
            if (((exponent >> i) % two) != zero) {
                result = multiplied
            }
            base = (base * base) % p
            i += 1
        }

        BigNum(result)
    }

    /**
 * lshift.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func lshift(bits: Int64): BigNum {
        if (bits < 0) {
            throw CryptoException(InvalidArgument, "shift bits must be >= 0")
        }
        BigNum(_value << bits)
    }

    /**
 * rshift.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func rshift(bits: Int64): BigNum {
        if (bits < 0) {
            throw CryptoException(InvalidArgument, "shift bits must be >= 0")
        }
        BigNum(_value >> bits)
    }

    public func cmp(other: BigNum): Int64 {
        if (_value < other._value) {
            return -1
        }
        if (_value > other._value) {
            return 1
        }
        0
    }

    public func isZero(): Bool {
        _value.sign == 0
    }

    public func isNegative(): Bool {
        _value.sign < 0
    }

    public static func gcd(left: BigNum, right: BigNum): BigNum {
        var a = abs(left._value)
        var b = abs(right._value)
        let zero = BigInt(0)
        while (b != zero) {
            let r = a % b
            a = b
            b = r
        }
        BigNum(a)
    }

    public static func modSqrt(value: BigNum, primeModulus: BigNum): BigNum {
        let p = abs(primeModulus._value)
        if (p <= BigInt(1)) {
            throw CryptoException(InvalidArgument, "prime modulus must be > 1")
        }

        let a = normalizeMod(value._value, p)
        if (a == BigInt(0)) {
            return BigNum.zero()
        }

        if (p == BigInt(2)) {
            return BigNum(a)
        }

        let one = BigInt(1)
        let two = BigInt(2)

        // Euler criterion.
        let ls = a.modPow((p - one) / two, m: p)
        if (ls != one) {
            throw CryptoException(NoModInverse, "square root does not exist for this modulus")
        }

        if ((p % BigInt(4)) == BigInt(3)) {
            let r = a.modPow((p + one) / BigInt(4), m: p)
            return BigNum(minRoot(r, p))
        }

        // Tonelli-Shanks for odd prime p.
        var q = p - one
        var s: Int64 = 0
        while ((q % two) == BigInt(0)) {
            q = q / two
            s += 1
        }

        var z = BigInt(2)
        while (z.modPow((p - one) / two, m: p) != p - one) {
            z += one
        }

        var m = s
        var c = z.modPow(q, m: p)
        var t = a.modPow(q, m: p)
        var r = a.modPow((q + one) / two, m: p)

        while (t != one) {
            var i: Int64 = 1
            var t2i = (t * t) % p
            while (i < m && t2i != one) {
                t2i = (t2i * t2i) % p
                i += 1
            }
            if (i >= m) {
                throw CryptoException(InternalError, "failed to converge in Tonelli-Shanks")
            }

            let b = c.modPow(BigInt(1) << (m - i - 1), m: p)
            r = (r * b) % p
            t = (t * b * b) % p
            c = (b * b) % p
            m = i
        }

        BigNum(minRoot(r, p))
    }

    public operator func ==(other: BigNum): Bool {
        _value == other._value
    }

    public operator func !=(other: BigNum): Bool {
        !(_value == other._value)
    }

    public func toString(): String {
        _value.toString()
    }

    private static func normalizeMod(value: BigInt, modulus: BigInt): BigInt {
        var r = value % modulus
        if (r.sign < 0) {
            r += modulus
        }
        r
    }

    private static func isOdd(value: BigInt): Bool {
        (value % BigInt(2)) != BigInt(0)
    }

    private static func oddModulusModPowPhase1(base: BigInt, exponent: BigInt, modulus: BigInt): BigInt {
        base.modPow(exponent, m: modulus)
    }

    private static func minRoot(root: BigInt, primeModulus: BigInt): BigInt {
        let normalized = normalizeMod(root, primeModulus)
        let other = primeModulus - normalized
        if (normalized <= other) {
            return normalized
        }
        other
    }

    private static func trimLeadingHexZeros(input: String): String {
        var idx = 0
        while (idx < input.size && input[idx] == b'0') {
            idx += 1
        }
        if (idx >= input.size) {
            return ""
        }
        input[idx..]
    }

    private static func trimLeadingZeroBytes(input: Array<Byte>): Array<Byte> {
        var idx = 0
        while (idx < input.size && input[idx] == 0) {
            idx += 1
        }
        if (idx >= input.size) {
            return []
        }
        input[idx..]
    }

    private static func magnitudeToLittleEndianLimbs(magnitudeBE: Array<Byte>): Array<UInt32> {
        let bytes = trimLeadingZeroBytes(magnitudeBE)
        if (bytes.size == 0) {
            return []
        }

        let limbs = ArrayList<UInt32>()
        var i = bytes.size
        while (i > 0) {
            var word: UInt32 = 0
            var shift = 0
            while (shift < 4 && i > 0) {
                i -= 1
                word = word | (UInt32(UInt8(bytes[i])) << (shift * 8))
                shift += 1
            }
            limbs.add(word)
        }

        while (limbs.size > 0 && limbs[limbs.size - 1] == 0) {
            limbs.remove(at: limbs.size - 1)
        }
        limbs.toArray()
    }
}

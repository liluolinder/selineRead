package jinguissl_core.tests

import std.collection.ArrayList
import std.fs.*
import jinguissl_core.crypto.bignum.BigNum

/**
 * Vector-driven BigNum test.
 *
 * Reads the 10 BN vector files from testdata/bn/ and validates
 * every test case block against the corresponding BigNum operation.
 */
@Test
public class CoreBNVectorTestSuite {

    /**
     * Exponentiation: A ^ E = Exp
     */
    @TestCase
    public func testExpVectors(): Unit {
        let blocks = parseVectorBlocks("testdata/bn/exp_tests.txt")
        var passed: Int64 = 0
        for (block in blocks) {
            let a = getValue(block, "A")
            let e = getValue(block, "E")
            let expected = getValue(block, "Exp")
            let result = BigNum.fromHex(a).exp(BigNum.fromHex(e))
            if (normalizeHex(result.toHex()) != normalizeHex(expected)) {
                @Fail("exp: A=${a} E=${e} expected=${expected} got=${result.toHex()}")
            }
            passed += 1
        }
        if (passed == 0) {
            @Fail("exp_tests.txt: no test blocks parsed")
        }
    }

    /**
     * Sum: A + B = Sum
     */
    @TestCase
    public func testSumVectors(): Unit {
        let blocks = parseVectorBlocks("testdata/bn/sum_tests.txt")
        var passed: Int64 = 0
        for (block in blocks) {
            let a = getValue(block, "A")
            let b = getValue(block, "B")
            let expected = getValue(block, "Sum")
            let result = BigNum.fromHex(a).add(BigNum.fromHex(b))
            if (normalizeHex(result.toHex()) != normalizeHex(expected)) {
                @Fail("sum: A=${a} B=${b} expected=${expected} got=${result.toHex()}")
            }
            passed += 1
        }
        if (passed == 0) {
            @Fail("sum_tests.txt: no test blocks parsed")
        }
    }

    /**
     * Square (product): A * A = Square
     */
    @TestCase
    public func testSquareVectors(): Unit {
        let blocks = parseVectorBlocks("testdata/bn/product_tests.txt")
        var passed: Int64 = 0
        for (block in blocks) {
            let a = tryGetValue(block, "A")
            if (a.size == 0) {
                continue
            }
            // Blocks with "Square" are A*A; blocks with "Product" are A*B.
            let squareStr = tryGetValue(block, "Square")
            let productStr = tryGetValue(block, "Product")
            if (squareStr.size > 0) {
                let result = BigNum.fromHex(a).mul(BigNum.fromHex(a))
                if (normalizeHex(result.toHex()) != normalizeHex(squareStr)) {
                    @Fail("square: A=${a} expected=${squareStr} got=${result.toHex()}")
                }
                passed += 1
            } else if (productStr.size > 0) {
                let b = tryGetValue(block, "B")
                if (b.size == 0) {
                    continue
                }
                let result = BigNum.fromHex(a).mul(BigNum.fromHex(b))
                if (normalizeHex(result.toHex()) != normalizeHex(productStr)) {
                    @Fail("product: A=${a} B=${b} expected=${productStr} got=${result.toHex()}")
                }
                passed += 1
            }
        }
        if (passed == 0) {
            @Fail("product_tests.txt: no test blocks parsed")
        }
    }

    /**
     * Quotient + Remainder: A / B = Quotient, A % B = Remainder
     */
    @TestCase
    public func testQuotientVectors(): Unit {
        let blocks = parseVectorBlocks("testdata/bn/quotient_tests.txt")
        var passed: Int64 = 0
        for (block in blocks) {
            let aStr = getValue(block, "A")
            let bStr = getValue(block, "B")
            let expectedQ = getValue(block, "Quotient")
            let expectedR = getValue(block, "Remainder")
            let a = BigNum.fromHex(aStr)
            let b = BigNum.fromHex(bStr)
            let (q, r) = a.divMod(b)
            let qHex = normalizeHex(q.toHex())
            let rHex = normalizeHex(r.toHex())
            let expQ = normalizeHex(expectedQ)
            let expR = normalizeHex(expectedR)
            if (qHex != expQ || rHex != expR) {
                @Fail("divmod: A=${aStr} B=${bStr} expected=(${expQ},${expR}) got=(${qHex},${rHex})")
            }
            passed += 1
        }
        if (passed == 0) {
            @Fail("quotient_tests.txt: no test blocks parsed")
        }
    }

    /**
     * Modular exponentiation: A ^ E = ModExp (mod M)
     */
    @TestCase
    public func testModExpVectors(): Unit {
        let blocks = parseVectorBlocks("testdata/bn/mod_exp_tests.txt")
        var passed: Int64 = 0
        for (block in blocks) {
            let a = getValue(block, "A")
            let e = getValue(block, "E")
            let m = getValue(block, "M")
            let expected = getValue(block, "ModExp")
            let result = BigNum.fromHex(a).modExp(BigNum.fromHex(e), BigNum.fromHex(m))
            if (normalizeHex(result.toHex()) != normalizeHex(expected)) {
                @Fail("modExp: A=${a} E=${e} M=${m} expected=${expected} got=${result.toHex()}")
            }
            passed += 1
        }
        if (passed == 0) {
            @Fail("mod_exp_tests.txt: no test blocks parsed")
        }
    }

    /**
     * Modular inverse: ModInv * A = 1 (mod M)
     */
    @TestCase
    public func testModInvVectors(): Unit {
        let blocks = parseVectorBlocks("testdata/bn/mod_inv_tests.txt")
        var passed: Int64 = 0
        for (block in blocks) {
            let a = getValue(block, "A")
            let m = getValue(block, "M")
            let expected = getValue(block, "ModInv")
            let modVal = BigNum.fromHex(m)
            if (modVal.cmp(BigNum.one()) <= 0) {
                continue
            }
            let result = BigNum.fromHex(a).modInverse(modVal)
            if (normalizeHex(result.toHex()) != normalizeHex(expected)) {
                @Fail("modInv: A=${a} M=${m} expected=${expected} got=${result.toHex()}")
            }
            passed += 1
        }
        if (passed == 0) {
            @Fail("mod_inv_tests.txt: no test blocks parsed")
        }
    }

    /**
     * Modular multiplication: A * B = ModMul (mod M)
     */
    @TestCase
    public func testModMulVectors(): Unit {
        let blocks = parseVectorBlocks("testdata/bn/mod_mul_tests.txt")
        var passed: Int64 = 0
        for (block in blocks) {
            let a = tryGetValue(block, "A")
            let m = tryGetValue(block, "M")
            if (a.size == 0 || m.size == 0) {
                continue
            }
            // Blocks with "ModMul" are A*B mod M; blocks with "ModSquare" are A*A mod M.
            let modMul = tryGetValue(block, "ModMul")
            let modSquare = tryGetValue(block, "ModSquare")
            if (modMul.size > 0) {
                let b = tryGetValue(block, "B")
                if (b.size == 0) {
                    continue
                }
                let result = BigNum.fromHex(a).mul(BigNum.fromHex(b)).mod(BigNum.fromHex(m))
                if (normalizeHex(result.toHex()) != normalizeHex(modMul)) {
                    @Fail("modMul: A=${a} B=${b} M=${m} expected=${modMul} got=${result.toHex()}")
                }
                passed += 1
            } else if (modSquare.size > 0) {
                let result = BigNum.fromHex(a).mul(BigNum.fromHex(a)).mod(BigNum.fromHex(m))
                if (normalizeHex(result.toHex()) != normalizeHex(modSquare)) {
                    @Fail("modSquare: A=${a} M=${m} expected=${modSquare} got=${result.toHex()}")
                }
                passed += 1
            }
        }
        if (passed == 0) {
            @Fail("mod_mul_tests.txt: no test blocks parsed")
        }
    }

    /**
     * Modular square root: ModSqrt * ModSqrt = A (mod P)
     */
    @TestCase
    public func testModSqrtVectors(): Unit {
        let blocks = parseVectorBlocks("testdata/bn/mod_sqrt_tests.txt")
        var passed: Int64 = 0
        for (block in blocks) {
            // Some blocks may be file terminators without A/P — skip those.
            let aStr = tryGetValue(block, "A")
            let pStr = tryGetValue(block, "P")
            if (aStr.size == 0 || pStr.size == 0) {
                continue
            }
            let expected = getValue(block, "ModSqrt")
            let a = BigNum.fromHex(aStr)
            let p = BigNum.fromHex(pStr)
            if (p.cmp(BigNum.fromHex("02")) < 0) {
                continue
            }
            let root = BigNum.modSqrt(a, p)
            let squared = root.mul(root).mod(p)
            let aNorm = a.mod(p)
            if (normalizeHex(squared.toHex()) != normalizeHex(aNorm.toHex())) {
                @Fail("modSqrt: A=${aStr} P=${pStr} root=${root.toHex()} squared=${squared.toHex()} expected_a_mod_p=${aNorm.toHex()}")
            }
            passed += 1
        }
        if (passed == 0) {
            @Fail("mod_sqrt_tests.txt: no test blocks parsed")
        }
    }

    /**
     * GCD: gcd(A, B) = GCD
     */
    @TestCase
    public func testGcdVectors(): Unit {
        let blocks = parseVectorBlocks("testdata/bn/gcd_tests.txt")
        var passed: Int64 = 0
        for (block in blocks) {
            let a = getValue(block, "A")
            let b = getValue(block, "B")
            let expected = getValue(block, "GCD")
            let result = BigNum.gcd(BigNum.fromHex(a), BigNum.fromHex(b))
            if (normalizeHex(result.toHex()) != normalizeHex(expected)) {
                @Fail("gcd: A=${a} B=${b} expected=${expected} got=${result.toHex()}")
            }
            passed += 1
        }
        if (passed == 0) {
            @Fail("gcd_tests.txt: no test blocks parsed")
        }
    }

    /**
     * Left shift by 1: A * 2 = LShift1
     */
    @TestCase
    public func testShiftVectors(): Unit {
        let blocks = parseVectorBlocks("testdata/bn/shift_tests.txt")
        var passed: Int64 = 0
        for (block in blocks) {
            let a = tryGetValue(block, "A")
            if (a.size == 0) {
                continue
            }
            // LShift1 = A * 2 (left shift by 1)
            let lshift1 = tryGetValue(block, "LShift1")
            if (lshift1.size > 0) {
                let result = BigNum.fromHex(a).lshift(1)
                if (normalizeHex(result.toHex()) != normalizeHex(lshift1)) {
                    @Fail("lshift1: A=${a} expected=${lshift1} got=${result.toHex()}")
                }
                passed += 1
                continue
            }
            // LShift = A left-shifted by N bits
            let lshift = tryGetValue(block, "LShift")
            if (lshift.size > 0) {
                let nStr = tryGetValue(block, "N")
                // Parse N as decimal integer.
                let n = parseDecimal(nStr)
                let result = BigNum.fromHex(a).lshift(n)
                if (normalizeHex(result.toHex()) != normalizeHex(lshift)) {
                    @Fail("lshift: A=${a} N=${nStr} expected=${lshift} got=${result.toHex()}")
                }
                passed += 1
                continue
            }
            // RShift = A right-shifted by N bits
            let rshift = tryGetValue(block, "RShift")
            if (rshift.size > 0) {
                let nStr = tryGetValue(block, "N")
                let n = parseDecimal(nStr)
                let result = BigNum.fromHex(a).rshift(n)
                if (normalizeHex(result.toHex()) != normalizeHex(rshift)) {
                    @Fail("rshift: A=${a} N=${nStr} expected=${rshift} got=${result.toHex()}")
                }
                passed += 1
                continue
            }
        }
        if (passed == 0) {
            @Fail("shift_tests.txt: no test blocks parsed")
        }
    }

    private static func parseDecimal(text: String): Int64 {
        // N values in shift vectors are hex.
        let bn = BigNum.fromHex(text)
        var value: Int64 = 0
        let bytes = bn.toBytesBE()
        for (b in bytes) {
            value = (value << 8) + Int64(UInt8(b))
        }
        value
    }

    private static func digitVal(ch: Rune): Int64 {
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
            case _ => throw Exception("not a digit: ${ch.toString()}")
        }
    }

    // ---------------------------------------------------------------------------
    // Vector file parsing helpers.
    // ---------------------------------------------------------------------------

    private static func parseVectorBlocks(path: String): ArrayList<Block> {
        let raw = readText(path)
        let lines = raw.split("\n")
        let blocks = ArrayList<Block>()
        var currentKeys = ArrayList<String>()
        var currentVals = ArrayList<String>()
        for (line in lines) {
            let trimmed = line.trimAscii()
            if (trimmed.size == 0) {
                if (currentKeys.size > 0) {
                    blocks.add(Block(currentKeys, currentVals))
                    currentKeys = ArrayList<String>()
                    currentVals = ArrayList<String>()
                }
                continue
            }
            if (trimmed.startsWith("#")) {
                continue
            }
            let eqIdx = indexOfChar(trimmed, r'=')
            if (eqIdx > 0) {
                let key = trimmed[0..eqIdx].trimAscii()
                let value = trimmed[eqIdx + 1..].trimAscii()
                currentKeys.add(key)
                currentVals.add(value)
            }
        }
        if (currentKeys.size > 0) {
            blocks.add(Block(currentKeys, currentVals))
        }
        blocks
    }

    private static func getValue(block: Block, key: String): String {
        for (i in 0..block.keys.size) {
            if (block.keys[i] == key) {
                return block.vals[i]
            }
        }
        throw Exception("missing key: ${key}")
    }

    private static func tryGetValue(block: Block, key: String): String {
        for (i in 0..block.keys.size) {
            if (block.keys[i] == key) {
                return block.vals[i]
            }
        }
        ""
    }

    private static func normalizeHex(value: String): String {
        var text = value
        if (text.startsWith("0x") || text.startsWith("0X")) {
            text = text[2..]
        }
        var neg = false
        if (text.startsWith("-")) {
            neg = true
            text = text[1..]
        }
        // Strip leading zeros but keep at least one digit.
        let chars = text.toRuneArray()
        var i: Int64 = 0
        while (i < chars.size - 1 && chars[i] == r'0') {
            i += 1
        }
        text = ""
        while (i < chars.size) {
            text += chars[i].toString()
            i += 1
        }
        if (neg && text != "0") {
            text = "-${text}"
        }
        text
    }

    private static func indexOfChar(text: String, ch: Rune): Int64 {
        let runes = text.toRuneArray()
        var i: Int64 = 0
        while (i < runes.size) {
            if (runes[i] == ch) {
                return i
            }
            i += 1
        }
        -1
    }

    private static func readText(path: String): String {
        if (!exists(path)) {
            throw Exception("file not found: ${path}")
        }
        String.fromUtf8(File.readFrom(path))
    }
}

/**
 * A parsed vector block: parallel arrays of keys and values.
 */
private class Block {
    public let keys: ArrayList<String>
    public let vals: ArrayList<String>

    public init(keys: ArrayList<String>, vals: ArrayList<String>) {
        this.keys = keys
        this.vals = vals
    }
}

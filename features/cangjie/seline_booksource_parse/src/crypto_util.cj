package seline_booksource_parse

/**
 * 加密工具：AES-128-CBC-PKCS7 纯仓颉实现 + Base64
 *
 * 用途：为书源生成正文 token（如 apibi.cc 章节 token = Base64(AES-CBC(明文模板))）。
 * 密钥/IV/明文模板由书源 JSON 的 ruleContent.token 配置，本类只提供通用加密能力。
 * 实现经 FIPS-197 标准向量验证：AES-128(key=0001..0f, plain=001122..ff) = 69c4e0d86a7b0430d8cdb78070b4c55a
 */
public class CryptoUtil {
    private static let SBOX: Array<Int64> = genSbox()

    /**
     * 生成 token：按指定算法对 input 加密，结果 Base64 编码
     * @param input 明文（书源 input 模板填充并转义后）
     * @param key   AES 密钥（16 字节 UTF-8 文本）
     * @param iv    AES 初始向量（16 字节 UTF-8 文本）
     * @param algo  加密算法（当前支持 "aes-128-cbc"）
     * @return Base64 字符串（含 +/ 字符，用于 URL 时需再编码）
     */
    public static func genToken(input: String, key: String, iv: String, algo: String): String {
        match (algo) {
            case "aes-128-cbc" | "aes" => aes128Token(input, key, iv)
            case _ => throw Exception("不支持的 token 算法: " + algo)
        }
    }

    private static func aes128Token(input: String, key: String, iv: String): String {
        let enc = aesCbcPkcs7Encrypt(input.toArray(), key.toArray(), iv.toArray())
        base64Encode(enc)
    }

    // ==================== AES-128-CBC-PKCS7 ====================

    public static func aesCbcPkcs7Encrypt(plain: Array<Byte>, key: Array<Byte>, iv: Array<Byte>): Array<Byte> {
        // PKCS7 填充
        let padLen: Int64 = 16 - (plain.size % 16)
        let paddedSize: Int64 = plain.size + padLen
        var padded = Array<Int64>(paddedSize, repeat: 0)
        for (i in 0..plain.size) {
            padded[i] = Int64(plain[i])
        }
        for (i in plain.size..paddedSize) {
            padded[i] = padLen
        }
        // 密钥扩展
        var k = Array<Int64>(16, repeat: 0)
        for (i in 0..16) {
            k[i] = Int64(key[i])
        }
        let w = expandKey(k)
        // CBC 模式
        var prev = Array<Int64>(16, repeat: 0)
        for (i in 0..16) {
            prev[i] = Int64(iv[i])
        }
        var out = Array<Byte>(paddedSize, repeat: 0)
        var block = Array<Int64>(16, repeat: 0)
        let blocks: Int64 = paddedSize / 16
        for (blk in 0..blocks) {
            for (i in 0..16) {
                block[i] = padded[blk * 16 + i] ^ prev[i]
            }
            let enc = encryptBlock(block, w)
            for (i in 0..16) {
                out[blk * 16 + i] = UInt8(enc[i])
                prev[i] = enc[i]
            }
        }
        out
    }

    private static func expandKey(key: Array<Int64>): Array<Int64> {
        let rcon: Array<Int64> = [0x01, 0x02, 0x04, 0x08, 0x10, 0x20, 0x40, 0x80, 0x1B, 0x36]
        let w = Array<Int64>(44, repeat: 0)
        for (i in 0..4) {
            w[i] = (key[4 * i] << 24) | (key[4 * i + 1] << 16) | (key[4 * i + 2] << 8) | key[4 * i + 3]
        }
        for (i in 4..44) {
            var temp = w[i - 1]
            if (i % 4 == 0) {
                // Rcon 数组索引 0-9 对应 Rcon[1..10]
                temp = subWord(rotWord(temp)) ^ (rcon[i / 4 - 1] << 24)
            }
            w[i] = w[i - 4] ^ temp
        }
        w
    }

    private static func encryptBlock(input: Array<Int64>, w: Array<Int64>): Array<Int64> {
        var state = Array<Int64>(16, repeat: 0)
        for (i in 0..16) {
            state[i] = input[i]
        }
        addRoundKey(state, w, 0)
        // Cangjie 的 a..b 为左闭右开区间 [a, b)，故用 1..11 覆盖第 1~10 轮
        for (round in 1..11) {
            subBytes(state)
            shiftRows(state)
            if (round != 10) {
                mixColumns(state)
            }
            addRoundKey(state, w, round)
        }
        state
    }

    private static func subBytes(state: Array<Int64>): Unit {
        for (i in 0..16) {
            state[i] = SBOX[state[i] & 0xFF]
        }
    }

    private static func shiftRows(state: Array<Int64>): Unit {
        var t = Array<Int64>(16, repeat: 0)
        for (r in 0..4) {
            for (c in 0..4) {
                t[r + 4 * c] = state[r + 4 * ((c + r) % 4)]
            }
        }
        for (i in 0..16) {
            state[i] = t[i]
        }
    }

    private static func mixColumns(state: Array<Int64>): Unit {
        for (c in 0..4) {
            let i0 = 4 * c
            let i1 = 4 * c + 1
            let i2 = 4 * c + 2
            let i3 = 4 * c + 3
            let a0 = state[i0]
            let a1 = state[i1]
            let a2 = state[i2]
            let a3 = state[i3]
            state[i0] = (mul2(a0) ^ mul3(a1) ^ a2 ^ a3) & 0xFF
            state[i1] = (a0 ^ mul2(a1) ^ mul3(a2) ^ a3) & 0xFF
            state[i2] = (a0 ^ a1 ^ mul2(a2) ^ mul3(a3)) & 0xFF
            state[i3] = (mul3(a0) ^ a1 ^ a2 ^ mul2(a3)) & 0xFF
        }
    }

    private static func addRoundKey(state: Array<Int64>, w: Array<Int64>, round: Int64): Unit {
        for (i in 0..16) {
            let word = w[round * 4 + i / 4]
            let byte = (word >> (8 * (3 - i % 4))) & 0xFF
            state[i] = (state[i] ^ byte) & 0xFF
        }
    }

    private static func rotWord(x: Int64): Int64 {
        ((x << 8) | (x >> 24)) & 0xFFFFFFFF
    }

    private static func subWord(x: Int64): Int64 {
        (SBOX[(x >> 24) & 0xFF] << 24) | (SBOX[(x >> 16) & 0xFF] << 16) | (SBOX[(x >> 8) & 0xFF] << 8) | SBOX[x & 0xFF]
    }

    private static func mul2(x: Int64): Int64 {
        ((x << 1) ^ (if ((x & 0x80) != 0) { 0x1B } else { 0 })) & 0xFF
    }

    private static func mul3(x: Int64): Int64 {
        mul2(x) ^ x
    }

    private static func rotl8(x: Int64, n: Int64): Int64 {
        ((x << n) | (x >> (8 - n))) & 0xFF
    }

    /** FIPS-197 标准方法生成 S-box */
    private static func genSbox(): Array<Int64> {
        let sbox = Array<Int64>(256, repeat: 0)
        var p: Int64 = 1
        var q: Int64 = 1
        while (true) {
            // p = p * x
            p = (p ^ (p << 1) ^ (if ((p & 0x80) != 0) { 0x11B } else { 0 })) & 0xFF
            // q = q * x^7（乘法逆，即除以 x）
            q ^= q << 1
            q ^= q << 2
            q ^= q << 4
            if ((q & 0x80) != 0) {
                q ^= 0x09
            }
            q = q & 0xFF
            let xformed = (q ^ rotl8(q, 1) ^ rotl8(q, 2) ^ rotl8(q, 3) ^ rotl8(q, 4) ^ 0x63) & 0xFF
            sbox[p] = xformed
            if (p == 1) {
                break
            }
        }
        sbox[0] = 0x63
        sbox
    }

    // ==================== Base64 ====================

    private static let B64_CHARS: String = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

    public static func base64Encode(data: Array<Byte>): String {
        let sb = StringBuilder()
        var i: Int64 = 0
        while (i + 3 <= data.size) {
            let n = (Int64(data[i]) << 16) | (Int64(data[i + 1]) << 8) | Int64(data[i + 2])
            sb.append(b64Char((n >> 18) & 0x3F))
            sb.append(b64Char((n >> 12) & 0x3F))
            sb.append(b64Char((n >> 6) & 0x3F))
            sb.append(b64Char(n & 0x3F))
            i += 3
        }
        let rest = data.size - i
        if (rest == 1) {
            let n = Int64(data[i]) << 16
            sb.append(b64Char((n >> 18) & 0x3F))
            sb.append(b64Char((n >> 12) & 0x3F))
            sb.append("==")
        } else if (rest == 2) {
            let n = (Int64(data[i]) << 16) | (Int64(data[i + 1]) << 8)
            sb.append(b64Char((n >> 18) & 0x3F))
            sb.append(b64Char((n >> 12) & 0x3F))
            sb.append(b64Char((n >> 6) & 0x3F))
            sb.append("=")
        }
        sb.toString()
    }

    private static func b64Char(idx: Int64): String {
        B64_CHARS[idx..(idx + 1)]
    }
}

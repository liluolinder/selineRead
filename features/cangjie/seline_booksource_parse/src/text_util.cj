package seline_booksource_parse

/**
 * 字符串工具：提供可靠的 trim 实现
 *
 * 注意：本环境标准库 String.trimStart()/trimEnd() 无参版本不剥离空白字符（实测返回原串），
 * 因此这里提供字节级 trim（ASCII 空白 + 全角空格 U+3000）。
 */
public class TextUtil {
    private init() {}

    /** 去掉字符串首尾空白（空格、\t、\n、\r 及全角空格 U+3000） */
    public static func trim(s: String): String {
        if (s.isEmpty()) {
            return ""
        }
        var start: Int64 = 0
        var end: Int64 = s.size
        while (start < end && isAsciiWs(s[start])) {
            start++
        }
        while (start < end && isFullWidthSpace(s, start)) {
            start += 3
        }
        while (end > start && isAsciiWs(s[end - 1])) {
            end--
        }
        while (end > start && isFullWidthSpace(s, end - 3)) {
            end -= 3
        }
        if (start == 0 && end == s.size) {
            return s
        }
        s[start..end]
    }

    private static func isAsciiWs(b: Byte): Bool {
        b == b' ' || b == b'\t' || b == b'\n' || b == b'\r'
    }

    // 全角空格 U+3000 的 UTF-8 编码为 E3 80 80
    private static func isFullWidthSpace(s: String, pos: Int64): Bool {
        pos >= 0 && pos + 2 < s.size && s[pos] == 0xE3 && s[pos + 1] == 0x80 && s[pos + 2] == 0x80
    }
}

/** String 扩展：提供与常见语言一致的 trim() 语义（同包内可见） */
extend String {
    public func trim(): String {
        TextUtil.trim(this)
    }
}

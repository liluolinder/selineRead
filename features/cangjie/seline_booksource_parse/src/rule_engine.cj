package seline_booksource_parse

import std.collection.ArrayList
import html4cj.Html4cj
import html4cj.Element
import html4cj.Elements
import html4cj.Node
import html4cj.TextNode
import gjson.get
import gjson.Result

/**
 * 规则引擎
 *
 * 规则语法：
 * - HTML 书源：CSS 选择器 + 可选 "@属性" 后缀，属性支持 text（默认）/ ownText / html / 任意属性名（href、src…）
 * - JSON 书源：gjson 路径（如 data.books.#.name）
 *
 * 内容类型自动判定：响应体去除首尾空白后以 '{' 或 '[' 开头按 JSON 处理，否则按 HTML 处理。
 */
public class RuleEngine {
    private init() {}

    /** 判断响应内容是否为 JSON */
    public static func isJsonContent(content: String): Bool {
        let trimmed = content.trim()
        if (trimmed.isEmpty()) {
            return false
        }
        trimmed[0] == b'{' || trimmed[0] == b'['
    }

    /** 拆分 "选择器@属性" 规则，返回 (选择器, 属性)；无 @ 时属性默认为 text */
    public static func splitRule(rule: String): (String, String) {
        let idx = lastIndexOf(rule, b'@')
        if (idx < 0) {
            return (rule.trim(), "text")
        }
        (rule[0..idx].trim(), rule[(idx + 1)..].trim())
    }

    /**
     * 对元素应用相对规则：
     * - 规则含选择器（如 "h3@text"）时，先在元素内查找子元素再提取
     * - 规则只有属性（如 "@text" / "@href"）时，直接对当前元素提取
     */
    public static func extractElement(element: Element, rule: String): String {
        if (rule.isEmpty()) {
            return ""
        }
        let (selector, attr) = splitRule(rule)
        if (selector.isEmpty()) {
            return extractByAttr(element, attr)
        }
        if (let Some(sub) <- element.selectFirst(selector)) {
            return extractByAttr(sub, attr)
        }
        ""
    }

    /** 对整段 HTML 应用规则，取第一个匹配值 */
    public static func extractFirst(html: String, rule: String): String {
        if (rule.isEmpty()) {
            return ""
        }
        let (selector, attr) = splitRule(rule)
        if (selector.isEmpty()) {
            return ""
        }
        let doc = Html4cj.parse(html)
        if (let Some(el) <- doc.selectFirst(selector)) {
            return extractByAttr(el, attr)
        }
        ""
    }

    /** 对整段 HTML 应用规则，取全部匹配值（多值规则用，如目录列表） */
    public static func extractAll(html: String, rule: String): ArrayList<String> {
        let result = ArrayList<String>()
        if (rule.isEmpty()) {
            return result
        }
        let (selector, attr) = splitRule(rule)
        if (selector.isEmpty()) {
            return result
        }
        let doc = Html4cj.parse(html)
        let elements = doc.select(selector)
        for (el in elements.elementArr) {
            result.add(extractByAttr(el, attr))
        }
        result
    }

    /** 按 CSS 选择器取元素列表（供逐条应用相对规则） */
    public static func selectElements(html: String, selector: String): Elements {
        Html4cj.parse(html).select(selector)
    }

    /** 对 JSON 内容应用 gjson 路径规则，取第一个匹配值 */
    public static func extractJson(json: String, path: String): String {
        if (path.isEmpty()) {
            return ""
        }
        let result = get(json, path)
        if (result.exists()) {
            return cleanJsonNumber(result.toString().trim())
        }
        ""
    }

    /** 对 JSON 内容应用 gjson 路径规则，取全部匹配值 */
    public static func extractJsonAll(json: String, path: String): ArrayList<String> {
        let result = ArrayList<String>()
        if (path.isEmpty()) {
            return result
        }
        let r = get(json, path)
        if (r.exists() && r.isArray()) {
            for (item in r.array()) {
                if (item.exists()) {
                    result.add(cleanJsonNumber(item.toString().trim()))
                }
            }
        }
        result
    }

    /** 对 gjson Result 应用相对路径，取字符串值 */
    public static func jsonValue(item: Result, path: String): String {
        if (path.isEmpty()) {
            return ""
        }
        let r = item.get(path)
        if (r.exists()) {
            return cleanJsonNumber(r.toString().trim())
        }
        ""
    }

    /** 清理 JSON 数字值：去掉末尾的 .0 / .000000（如 "234856.000000" → "234856"） */
    private static func cleanJsonNumber(s: String): String {
        var i = s.size - 1
        while (i >= 0 && s[i] == b'0') {
            i--
        }
        if (i >= 0 && s[i] == b'.') {
            s[0..i]
        } else {
            s
        }
    }

    private static func extractByAttr(element: Element, attr: String): String {
        let value = match (attr) {
            case "text" => textWithBreaks(element)
            case "ownText" => element.ownText()
            case "html" => element.html()
            case _ => element.attr(attr)
        }
        value.trim()
    }

    /**
     * 块级感知文本提取：递归遍历子节点，块级元素（p/div/li/br 等）之间追加换行。
     * 解决正文多段落（如 #articlecontent 内多个 p）@text 提取时全部堆在一起的问题；
     * 单行场景（书名/作者等）不受影响（trim 掉首尾空白）。
     */
    private static func textWithBreaks(element: Element): String {
        let sb = StringBuilder()
        appendTextWithBreaks(element, sb)
        sb.toString()
    }

    private static func appendTextWithBreaks(node: Node, sb: StringBuilder): Unit {
        match (node) {
            case tn: TextNode =>
                sb.append(tn.getWholeText())
            case el: Element =>
                let tag = el.normalName()
                for (child in el.childNodes()) {
                    appendTextWithBreaks(child, sb)
                }
                // 块级元素或 <br> 后追加换行，分隔段落
                if (el.isBlock() || tag == "br") {
                    sb.append("\n")
                }
            case _ => ()
        }
    }

    private static func lastIndexOf(s: String, ch: Byte): Int64 {
        var i: Int64 = s.size - 1
        while (i >= 0) {
            if (s[i] == ch) {
                return i
            }
            i--
        }
        -1
    }
}

package seline_booksource_parse

import std.collection.HashMap
import linderHttp.HttpQuick
import linderHttp.LinderHttpClient
import linderHttp.RequestUrl
import linderHttp.RequestMethod
import stdx.encoding.url.URL

/**
 * HTTP 工具类：基于 linderHttp 的请求封装
 *
 * 提供：
 * - GET / POST 请求（支持自定义请求头）
 * - "Name=value; Name2=value2" 书源请求头解析
 * - {{key}} / {{page}} 模板占位符填充
 * - 相对 URL 拼接（resolve 到书源根地址）
 */
public class HttpUtil {
    private init() {}

    /**
     * 解析书源 header 字段："User-Agent=Mozilla/5.0; Referer=https://x.com"
     * 注意：值里可能含分号（如 UA 的 "Windows NT 10.0; Win64; x64"），
     * 无 '=' 的片段会被合并到上一个 header 项，避免被错误切分
     */
    public static func parseHeaders(headerStr: String): HashMap<String, String> {
        let headers = HashMap<String, String>()
        if (headerStr.isEmpty()) {
            return headers
        }
        let items = headerStr.split(";")
        var lastKey: String = ""
        for (item in items) {
            let pair = item.trim()
            if (pair.isEmpty()) {
                continue
            }
            let eq = pair.indexOf('=')
            if (let Some(pos) <- eq) {
                let key = pair[0..pos].trim()
                let value = pair[(pos + 1)..].trim()
                if (!key.isEmpty()) {
                    headers[key] = value
                    lastKey = key
                }
            } else if (!lastKey.isEmpty()) {
                // 不含 '='：是上一个 header 值的一部分（如 UA 分号后的片段）
                headers[lastKey] = headers.get(lastKey).getOrThrow() + "; " + pair
            }
        }
        headers
    }

    /** GET 请求，返回响应体字符串 */
    public static func get(url: String): String {
        HttpQuick.get(url).getBodyString()
    }

    /** GET 请求（带请求头），返回响应体字符串 */
    public static func get(url: String, headers: HashMap<String, String>): String {
        HttpQuick.get(url, header:headers).getBodyString()
    }

    /** POST 请求（带请求头），返回响应体字符串 */
    public static func post(url: String, body: String, headers: HashMap<String, String>): String {
        let response = LinderHttpClient(url: RequestUrl.from(url), method: RequestMethod.POST)
            .setHeader(headers)
            .setBody(body)
            .send()
        response.getBodyString()
    }

    /**
     * URL 编码（RFC 3986，组件级）：使用 stdx.encoding.url 的 URL.encodeComponent
     * 用于搜索关键字等查询参数值的百分号编码
     */
    public static func urlEncode(s: String): String {
        URL.encodeComponent(s)
    }

    /**
     * 填充模板占位符：{{key}} / {{searchKey}} 替换为搜索关键字，{{page}} / {{pageIndex}} 替换为页码
     */
    public static func fillTemplate(template: String, key: String, page: String): String {
        if (template.isEmpty()) {
            return ""
        }
        let sb = StringBuilder()
        var segStart: Int64 = 0
        var i: Int64 = 0
        let n: Int64 = template.size
        while (i < n) {
            if (i + 1 < n && template[i] == b'{' && template[i + 1] == b'{') {
                sb.append(template[segStart..i])
                var j: Int64 = i + 2
                while (j + 1 < n && !(template[j] == b'}' && template[j + 1] == b'}')) {
                    j++
                }
                if (j + 1 < n) {
                    let name = template[(i + 2)..j]
                    let value = match (name) {
                        case "key" | "searchKey" | "searchkey" | "search_key" => key
                        case "page" | "pageIndex" | "pageindex" | "page_index" => page
                        case _ => ""
                    }
                    sb.append(value)
                    i = j + 2
                    segStart = i
                } else {
                    i = n
                }
            } else {
                i++
            }
        }
        sb.append(template[segStart..])
        sb.toString()
    }

    /**
     * 通用占位符替换：将模板中的 {{name}} 全部替换为 value
     * 用于 {{bookId}}、{{chapterId}} 等动态 URL 占位符
     */
    public static func replacePlaceholder(template: String, name: String, value: String): String {
        if (template.isEmpty() || name.isEmpty()) {
            return template
        }
        let sb = StringBuilder()
        var segStart: Int64 = 0
        var i: Int64 = 0
        let n: Int64 = template.size
        while (i < n) {
            if (i + 1 < n && template[i] == b'{' && template[i + 1] == b'{') {
                sb.append(template[segStart..i])
                var j: Int64 = i + 2
                while (j + 1 < n && !(template[j] == b'}' && template[j + 1] == b'}')) {
                    j++
                }
                if (j + 1 < n) {
                    let key = template[(i + 2)..j]
                    sb.append(if (key == name) { value } else { template[i..(j + 2)] })
                    i = j + 2
                    segStart = i
                } else {
                    i = n
                }
            } else {
                i++
            }
        }
        sb.append(template[segStart..])
        sb.toString()
    }

    /**
     * 相对 URL 拼接：以 base 为基准解析 relative
     * - 绝对地址（http/https）原样返回
     * - "//x" 协议相对补全 scheme
     * - "/x" 站内根路径
     * - 其余相对路径拼到 base 最后一个 '/' 之后
     */
    public static func resolveUrl(base: String, relative: String): String {
        if (relative.isEmpty()) {
            return ""
        }
        if (relative.startsWith("http://") || relative.startsWith("https://")) {
            return relative
        }
        if (relative.startsWith("//")) {
            let idx = base.indexOf("://")
            if (!idx.isNone()) {
                return base[0..idx.getOrThrow()] + ":" + relative
            }
            return relative
        }
        if (relative.startsWith("/")) {
            let idx = base.indexOf("://")
            if (idx.isNone()) {
                return relative
            }
            var i: Int64 = idx.getOrThrow() + 3
            while (i < base.size && base[i] != b'/') {
                i++
            }
            return base[0..i] + relative
        }
        // 其余相对路径拼到 base 路径最后一个 '/' 之后；
        // 若 base 无路径（如 "https://host"），直接拼到 host 后加 '/'
        let idx = base.indexOf("://")
        var lastSlash: Int64 = -1
        let scanStart: Int64 = if (idx.isNone()) { 0 } else { idx.getOrThrow() + 3 }
        for (i in scanStart..base.size) {
            if (base[i] == b'/') {
                lastSlash = i
            }
        }
        if (lastSlash >= 0) {
            return base[0..(lastSlash + 1)] + relative
        }
        base + "/" + relative
    }
}

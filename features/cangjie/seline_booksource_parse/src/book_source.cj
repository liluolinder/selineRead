package seline_booksource_parse

// CJson 宏要求：被 @JsonSerializable 装饰的类所在包必须可见以下依赖
internal import std.collection.HashMap
internal import std.collection.ArrayList
internal import stdx.encoding.json.*
import CJson.*
import CJson.jsonmacro.*

/**
 * 搜索规则
 * - searchUrl 支持 {{key}} / {{page}} 模板占位符
 * - method：请求方式，默认 "GET"；"POST" 时关键字通过 postBody 表单提交
 * - postBody：POST 表单模板（如 "searchkey={{key}}"），{{key}} 会 URL 编码
 * - 其余字段为相对规则：HTML 书源形如 "选择器@属性"（如 h3@text、a@href、img@src）
 * - JSON 书源形如 gjson 路径（如 data.books.#.name）
 */
@JsonSerializable
public class RuleSearch {
    public var searchUrl: String = ""
    public var method: String = "GET"
    public var postBody: String = ""
    public var name: String = ""
    public var author: String = ""
    public var bookUrl: String = ""
    public var bookUrlTemplate: String = ""
    public var coverUrl: String = ""
    public var intro: String = ""
    public var kind: String = ""
    public var wordCount: String = ""
    public var latestChapter: String = ""
    /** offset 偏移量（固定数字，如 "20"）：offsetNum 未传时用该值 */
    public var offset: String = ""

    public init() {}
}

/**
 * 书籍详情页规则
 * - url：详情页地址模板（可选，缺省使用搜索结果的 bookUrl）
 */
@JsonSerializable
public class RuleBookInfo {
    public var url: String = ""
    public var name: String = ""
    public var author: String = ""
    public var coverUrl: String = ""
    public var intro: String = ""
    public var kind: String = ""
    public var wordCount: String = ""
    public var latestChapter: String = ""
    public var status: String = ""

    public init() {}
}

/**
 * 目录页规则
 * - url：目录页地址模板（可选，缺省使用详情页地址）
 */
@JsonSerializable
public class RuleToc {
    public var url: String = ""
    public var chapterName: String = ""
    public var chapterUrl: String = ""
    public var nextTocUrl: String = ""

    public init() {}
}

/**
 * 正文 token 生成配置（站点特定加密，算法与明文组成均可配置）
 * - algo：加密算法（当前支持 "aes-128-cbc"）
 * - key / iv：算法参数（AES 的密钥与初始向量，UTF-8 文本，各 16 字节）
 * - input：明文模板，支持 {{bookId}} / {{chapterId}} 占位符；
 *   因 CJson 不支持 JSON 字符串中的 \" 转义，模板中的单引号 ' 会被转换为双引号
 *   例："{'id':{{bookId}},'chapterid':{{chapterId}}}" → {"id":35814,"chapterid":2}
 */
@JsonSerializable
public class TokenConfig {
    public var algo: String = ""
    public var key: String = ""
    public var iv: String = ""
    public var input: String = ""

    public init() {}
}

/**
 * 正文页规则
 * - url：正文页地址模板（可选）
 *   - 含 {{chapterToken}} 且配置了 token 时，目录解析会为每章生成完整正文 URL
 *   - 固定地址时（如写死 token 的接口），getContent 使用该地址
 *   - 为空时使用章节地址（chapter.url）
 * - nextUrl：下一页链接规则（章节正文分页合并用，如 "#next_url@href"）；
 *   引擎会循环跟随后续页并合并正文，直到无有效下一页（非 /read/ 链接或提取为空）为止
 * - filters：正文过滤数组，提取正文后逐条匹配并替换为空（用于清理广告等干扰文本）；
 *   元素支持两种形式：
 *   - 普通字符串：直接全文匹配替换（如 "[全本小说]"）
 *   - "/正则/"：以 / 开头和结尾视为正则表达式，用正则替换（如 "/\\[全本小说\\].*一秒记住！/"）
 */
@JsonSerializable
public class RuleContent {
    public var url: String = ""
    public var content: String = ""
    public var nextUrl: String = ""
    public var filters: ArrayList<String> = ArrayList<String>()
    public var token: Option<TokenConfig>

    public init() {
        this.token = None
    }
}

/**
 * 书源（JSON 结构），通过 CJson 宏自动生成 fromJson / toJson
 *
 * 示例 JSON：
 * {
 *   "bookSourceUrl": "https://example.com",
 *   "bookSourceName": "示例书源",
 *   "bookSourceGroup": "测试",
 *   "bookSourceType": 0,
 *   "enabled": true,
 *   "header": "User-Agent=Mozilla/5.0",
 *   "ruleSearch": {
 *     "searchUrl": "/search?q={{key}}&page={{page}}",
 *     "name": "h3@text",
 *     "author": ".author@text",
 *     "bookUrl": "a@href",
 *     "coverUrl": "img@src",
 *     "intro": ".intro@text"
 *   },
 *   "ruleBookInfo": { "name": "h1@text", "author": ".author@text", "intro": "#intro@text" },
 *   "ruleToc": { "chapterList": "div.chapter-list li", "chapterName": "a@text", "chapterUrl": "a@href" },
 *   "ruleContent": { "content": "#content@text" }
 * }
 */
@JsonSerializable
public class BookSource {
    public var bookSourceUrl: String = ""
    public var bookSourceName: String = ""
    public var bookSourceGroup: String = ""
    public var bookSourceComment: String = ""
    public var bookSourceType: Int64 = 0
    public var enabled: Bool = true
    public var header: String = ""
    public var ruleSearch: Option<RuleSearch> = None 
    public var ruleBookInfo: Option<RuleBookInfo> = None
    public var ruleToc: Option<RuleToc> = None
    public var ruleContent: Option<RuleContent> = None
}

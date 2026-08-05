/**
 * Created on 2026/8/4
 */
package ohos_app_cangjie_entry.bookSource

import ohos.ark_interop_advance.*
import ohos.ark_interop_macro.*
import seline_booksource_parse.RuleSearch
import seline_booksource_parse.RuleBookInfo
import seline_booksource_parse.RuleToc
import seline_booksource_parse.RuleContent
import seline_booksource_parse.TokenConfig
import seline_booksource_parse.BookSource
import seline_booksource_parse.Chapter
import ohos_app_cangjie_entry.run2JS

@Interop[ArkTS]
public class BookSourceArk {
    public var bookSourceUrl: String = ""
    public var bookSourceName: String = ""
    public var bookSourceGroup: String = ""
    public var bookSourceComment: String = ""
    public var bookSourceType: Int64 = 0
    public var enabled: Bool = true
    public var header: String = ""
    public var ruleSearch: Option<RuleSearchArk> = None
    public var ruleBookInfo: Option<RuleBookInfoArk> = None
    public var ruleToc: Option<RuleTocArk> = None
    public var ruleContent: Option<RuleContentArk> = None

    var cjValue: Option<BookSource> = None

    private prop cjv: BookSource {
        get() {
            cjValue.getOrThrow()
        }
    }

    public BookSourceArk() {}

    @Interop[ArkTS, Invisible]
    public static func fromCJ(cjValue: BookSource): BookSourceArk {
        let r = BookSourceArk()
        r.bookSourceUrl = cjValue.bookSourceUrl
        r.bookSourceName = cjValue.bookSourceName
        r.bookSourceGroup = cjValue.bookSourceGroup
        r.bookSourceComment = cjValue.bookSourceComment
        r.bookSourceType = cjValue.bookSourceType
        r.enabled = cjValue.enabled
        r.header = cjValue.header
        if (let Some(v) <- cjValue.ruleSearch) {
            r.ruleSearch = Some(RuleSearchArk.fromCJ(v))
        }
        if (let Some(v) <- cjValue.ruleBookInfo) {
            r.ruleBookInfo = Some(RuleBookInfoArk.fromCJ(v))
        }
        if (let Some(v) <- cjValue.ruleToc) {
            r.ruleToc = Some(RuleTocArk.fromCJ(v))
        }
        if (let Some(v) <- cjValue.ruleContent) {
            r.ruleContent = Some(RuleContentArk.fromCJ(v))
        }
        r.cjValue = cjValue
        r
    }
}

@Interop[ArkTS]
public class ChapterArk {
    public var index: Int64 = 0
    public var name: String = ""
    public var url: String = ""
    public var sourceUrl: String = ""

    var cjValue: Option<Chapter> = None

    private prop cjv: Chapter {
        get() {
            cjValue.getOrThrow()
        }
    }

    public ChapterArk() {}

    @Interop[ArkTS, Invisible]
    public static func fromCJ(cjValue: Chapter): ChapterArk {
        let r = ChapterArk()
        r.index = cjValue.index
        r.name = cjValue.name
        r.url = cjValue.url
        r.sourceUrl = cjValue.sourceUrl
        r.cjValue = cjValue
        r
    }

    /** 获取本章正文（需已绑定解析器，由书源解析器目录解析后返回的章节自带解析器） */
    public func getContent(returnFunc: (String) -> Unit, errorFunc: (String) -> Unit): Unit {
        spawn {
            try {
                let res = cjv.getContent()
                run2JS {
                    returnFunc(res)
                }
            } catch (error: Exception) {
                run2JS {
                    errorFunc(error.toString())
                }
            }
        }
    }
}

@Interop[ArkTS]
public class RuleSearchArk {
    public var searchUrl: String = ""
    public var method: String = "GET"
    public var postBody: String = ""
    public var bookList: String = ""
    public var name: String = ""
    public var author: String = ""
    public var bookUrl: String = ""
    public var bookUrlTemplate: String = ""
    public var coverUrl: String = ""
    public var intro: String = ""
    public var kind: String = ""
    public var wordCount: String = ""
    public var latestChapter: String = ""

    var cjValue: Option<RuleSearch> = None

    private prop cjv: RuleSearch {
        get() {
            cjValue.getOrThrow()
        }
    }

    public RuleSearchArk() {}

    @Interop[ArkTS, Invisible]
    public static func fromCJ(cjValue: RuleSearch): RuleSearchArk {
        let r = RuleSearchArk()
        r.searchUrl = cjValue.searchUrl
        r.method = cjValue.method
        r.postBody = cjValue.postBody
        r.bookList = cjValue.bookList
        r.name = cjValue.name
        r.author = cjValue.author
        r.bookUrl = cjValue.bookUrl
        r.bookUrlTemplate = cjValue.bookUrlTemplate
        r.coverUrl = cjValue.coverUrl
        r.intro = cjValue.intro
        r.kind = cjValue.kind
        r.wordCount = cjValue.wordCount
        r.latestChapter = cjValue.latestChapter
        r.cjValue = cjValue
        r
    }
}

@Interop[ArkTS]
public class RuleBookInfoArk {
    public var url: String = ""
    public var name: String = ""
    public var author: String = ""
    public var coverUrl: String = ""
    public var intro: String = ""
    public var kind: String = ""
    public var wordCount: String = ""
    public var latestChapter: String = ""
    public var status: String = ""

    var cjValue: Option<RuleBookInfo> = None

    private prop cjv: RuleBookInfo {
        get() {
            cjValue.getOrThrow()
        }
    }

    public RuleBookInfoArk() {}

    @Interop[ArkTS, Invisible]
    public static func fromCJ(cjValue: RuleBookInfo): RuleBookInfoArk {
        let r = RuleBookInfoArk()
        r.url = cjValue.url
        r.name = cjValue.name
        r.author = cjValue.author
        r.coverUrl = cjValue.coverUrl
        r.intro = cjValue.intro
        r.kind = cjValue.kind
        r.wordCount = cjValue.wordCount
        r.latestChapter = cjValue.latestChapter
        r.status = cjValue.status
        r.cjValue = cjValue
        r
    }
}

@Interop[ArkTS]
public class RuleTocArk {
    public var url: String = ""
    public var chapterList: String = ""
    public var chapterName: String = ""
    public var chapterUrl: String = ""
    public var nextTocUrl: String = ""

    var cjValue: Option<RuleToc> = None

    private prop cjv: RuleToc {
        get() {
            cjValue.getOrThrow()
        }
    }

    public RuleTocArk() {}

    @Interop[ArkTS, Invisible]
    public static func fromCJ(cjValue: RuleToc): RuleTocArk {
        let r = RuleTocArk()
        r.url = cjValue.url
        r.chapterList = cjValue.chapterList
        r.chapterName = cjValue.chapterName
        r.chapterUrl = cjValue.chapterUrl
        r.nextTocUrl = cjValue.nextTocUrl
        r.cjValue = cjValue
        r
    }
}

@Interop[ArkTS]
public class TokenConfigArk {
    public var algo: String = "aes-128-cbc"
    public var key: String = ""
    public var iv: String = ""
    public var input: String = ""
    public var bookIdFrom: String = "bookUrl"

    var cjValue: Option<TokenConfig> = None

    private prop cjv: TokenConfig {
        get() {
            cjValue.getOrThrow()
        }
    }

    public TokenConfigArk() {}

    @Interop[ArkTS, Invisible]
    public static func fromCJ(cjValue: TokenConfig): TokenConfigArk {
        let r = TokenConfigArk()
        r.algo = cjValue.algo
        r.key = cjValue.key
        r.iv = cjValue.iv
        r.input = cjValue.input
        r.bookIdFrom = cjValue.bookIdFrom
        r.cjValue = cjValue
        r
    }
}

@Interop[ArkTS]
public class RuleContentArk {
    public var url: String = ""
    public var content: String = ""
    public var nextUrl: String = ""
    public var filters: JSArrayEx<String> = JSArrayEx<String>([])
    public var token: Option<TokenConfigArk> = None

    var cjValue: Option<RuleContent> = None

    private prop cjv: RuleContent {
        get() {
            cjValue.getOrThrow()
        }
    }

    public RuleContentArk() {}

    @Interop[ArkTS, Invisible]
    public static func fromCJ(cjValue: RuleContent): RuleContentArk {
        let r = RuleContentArk()
        r.url = cjValue.url
        r.content = cjValue.content
        r.nextUrl = cjValue.nextUrl
        r.filters = JSArrayEx<String>(cjValue
            .filters
            .toArray())
        if (let Some(t) <- cjValue.token) {
            r.token = Some(TokenConfigArk.fromCJ(t))
        }
        r.cjValue = cjValue
        r
    }
}

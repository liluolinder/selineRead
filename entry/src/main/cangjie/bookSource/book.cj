/**
 * Created on 2026/8/4
 */
package ohos_app_cangjie_entry.bookSource

import ohos.ark_interop_advance.*
import ohos.ark_interop_macro.*
import seline_booksource_parse.Book
import ohos_app_cangjie_entry.run2JS

@Interop[ArkTS]
public class BookArk {
    public var bookUrl: String = ""
    public var name: String = ""
    public var author: String = ""
    public var coverUrl: String = ""
    public var intro: String = ""
    public var kind: String = ""
    public var wordCount: String = ""
    public var latestChapter: String = ""
    public var sourceUrl: String = ""

    var cjValue: Option<Book> = None

    private prop cjv: Book {
        get() {
            cjValue.getOrThrow()
        }
    }

    public func getToc(returnFunc: (JSArrayEx<ChapterArk>) -> Unit, errorFunc: (String) -> Unit): Unit {
        spawn {
            try {
                let temp = cjv
                    .getToc()
                    .toArray()
                    .map({toc => ChapterArk.fromCJ(toc)})
                let res = JSArrayEx<ChapterArk>(temp)
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

    public func getBookInfo(returnFunc: (BookArk) -> Unit, errorFunc: (String) -> Unit): Unit {
        spawn {
            try {
                let temp = cjv.getBookInfo()
                let res = BookArk.fromCJ(temp)
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

    public BookArk() {}

    @Interop[ArkTS, Invisible]
    public static func fromCJ(cjValue: Book): BookArk {
        let r = BookArk()
        r.bookUrl = cjValue.bookUrl
        r.name = cjValue.name
        r.author = cjValue.author
        r.coverUrl = cjValue.coverUrl
        r.intro = cjValue.intro
        r.kind = cjValue.kind
        r.wordCount = cjValue.wordCount
        r.latestChapter = cjValue.latestChapter
        r.sourceUrl = cjValue.sourceUrl
        r.cjValue = cjValue
        r
    }
}

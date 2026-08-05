/**
 * Created on 2026/8/4
 */
package ohos_app_cangjie_entry.bookSource

import ohos.ark_interop_advance.*
import ohos.ark_interop_macro.*
import seline_booksource_parse.BookSourceParser
import ohos.request.agent.search
import ohos_app_cangjie_entry.run2JS

@Interop[ArkTS]
public class BookSourceParserArk {
    public var fileName: String = ''
    public var bookSource: BookSourceArk = BookSourceArk()

    var cjValue: Option<BookSourceParser> = None

    public prop supportsPage: Bool {
        get() {
            cjv.supportsPage
        }
    }

    private prop cjv: BookSourceParser {
        get() {
            cjValue.getOrThrow()
        }
    }

    public BookSourceParserArk(_fileName: String, bookSourceJson: String) {
        fileName = _fileName
        cjValue = BookSourceParser.fromJson(bookSourceJson)
        bookSource = BookSourceArk.fromCJ(cjv.bookSource)
    }

    public func search(keyWord: String, page: Option<String>, returnFunc: (JSArrayEx<BookArk>) -> Unit,
        errorFunc: (String) -> Unit): Unit {
        spawn {
            try {
                let reqs = cjv.search(keyWord, page: page)
                let temp = reqs
                    .toArray()
                    .map({
                        book => BookArk.fromCJ(book)
                    })
                let res = JSArrayEx<BookArk>(temp)
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

/**
 * Created on 2026/3/7
 */
package ohos_app_cangjie_entry.zlibAPI4cj

import ohos.ark_interop.*
import ohos.ark_interop_macro.*
import zlibraryAPI4CJ.dataModel.BookInfoBrief

@Interop[ArkTS]
public class ZlibBookInfoBriefArk {
    public var id: UInt64 = 0
    public var title: String = ''
    public var author: String = ''
    public var cover: String = ''
    public var hash: String = ''

    var cjValue: BookInfoBrief = BookInfoBrief()

    @Interop[ArkTS, Invisible]
    public static func fromCJ(cjValue: BookInfoBrief): ZlibBookInfoBriefArk {
        let r = ZlibBookInfoBriefArk()
        r.id = cjValue.id
        r.title = cjValue.title
        r.author = cjValue.author
        r.cover = cjValue.cover
        r.hash = cjValue.hash
        r.cjValue = cjValue
        r
    }

    public func getDetailInfo(cookie: Option<String>, returnFunc: (ZlibBookInfoArk) -> Unit, errorFunc: (String) -> Unit): Unit {
        if (let Some(context) <- globalcontext) {
            spawn {
                try {
                    let reqs = cjValue.getBookInfo(cookie: cookie)
                    if (reqs.success == 1) {
                        context.postJSTask {
                            returnFunc(ZlibBookInfoArk.fromCJ(reqs
                                .book
                                .getOrThrow()))
                        }
                    } else {
                        context.postJSTask {
                            errorFunc('获取错误:${reqs.errorInfo.getOrDefault {=> '未知错误'}}')
                        }
                    }
                } catch (err: Exception) {
                    context.postJSTask {
                        errorFunc(err.toString())
                    }
                }
            }
        }
    }

    public ZlibBookInfoBriefArk() {}
}

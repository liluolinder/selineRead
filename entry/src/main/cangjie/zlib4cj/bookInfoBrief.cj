/**
 * Created on 2026/3/7
 */
package ohos_app_cangjie_entry.zlib4cj

import ohos.ark_interop.*
import ohos.ark_interop_macro.*
import zlibraryAPI4CJ.dataModel.BookInfoBrief
import ohos_app_cangjie_entry.run2JS
import ohos.hilog.Hilog

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

    public func toCJ():Unit{
        cjValue.id = id
        cjValue.hash = hash
        cjValue.title = title
        cjValue.author = author
        cjValue.cover = cover
    }

    public func getDetailInfo(cookie: String, returnFunc: (ZlibBookInfoArk) -> Unit, errorFunc: (String) -> Unit): Unit {
         spawn {
                try {
                    let reqs = cjValue.getBookInfo(cookie: cookie)

                    let requ = cjValue.getUrl()
                    Hilog.info(1145,'meow',"meow:${requ}")

                    if (reqs.success == 1) {
                        run2JS{
                            returnFunc(ZlibBookInfoArk.fromCJ(reqs
                                .book
                                .getOrThrow()))
                        }
                    } else {
                        run2JS{
                             errorFunc('获取错误:${reqs.errorInfo.getOrDefault {=> '未知错误'}}')
                        }
                    }
                } catch (err: Exception) {
                    run2JS{
                        errorFunc("获取错误"+err.toString())
                    }
                }
            }
    }

    public init(){}

    public init(id:UInt64, hash:String) {
        this.id  = id
        this.hash = hash
        cjValue = BookInfoBrief()
        cjValue.id = id
        cjValue.hash=hash
    }


}

/**
 * Created on 2026/3/10
 */
package ohos_app_cangjie_entry.zlib4cj

import ohos.ark_interop.*
import ohos.ark_interop_macro.*
import zlibraryAPI4CJ.dataModel.ZlibUserInfo
import ohos_app_cangjie_entry.run2JS
import zlibraryAPI4CJ.dataModel.Pagination
import ohos.hilog.Hilog

@Interop[ArkTS]
public class ZlibUserInfoArk {
    public var id: UInt64 = 0
    public var email: String = ""
    public var name: String = ""
    public var kindleEmail: String = ""
    public var remixUserKey: String = ""
    public var todayDownloadNum: UInt64 = 0
    public var downloadLimit: UInt64 = 0

    var cjValue: ZlibUserInfo = ZlibUserInfo()

    @Interop[ArkTS, Invisible]
    public static func fromCJ(cjValue: ZlibUserInfo): ZlibUserInfoArk {
        let r = ZlibUserInfoArk()
        r.id = cjValue.id
        r.email = cjValue.email
        r.name = cjValue.name
        r.kindleEmail = cjValue.kindleEmail
        r.remixUserKey = cjValue.remixUserKey
        r.todayDownloadNum = cjValue.todayDownloadNum
        r.downloadLimit = cjValue.downloadLimit
        r.cjValue = cjValue
        r
    }

    public prop cookie: String {
        get() {
            'siteLanguage=zh; remix_userkey=${remixUserKey}; remix_userid=${id}'
        }
    }

    public func getSavedBook(page: UInt64, returnFunc: (JSArrayEx<ZlibBookInfoArk>, PaginationArk) -> Unit,
        errorFunc: (String) -> Unit): Unit {
        spawn {
            try {
                Hilog.info(1414, '1145', '开始获取')
                let reqs = cjValue.getSaved(page: page)
                if (reqs.success == 1) {
                    let tempBooks = reqs
                        .books
                        .getOrThrow()
                        .map {
                            book => ZlibBookInfoArk.fromCJ(book)
                        }

                    let bookResArray = JSArrayEx<ZlibBookInfoArk>(tempBooks)
                    let pagiinationRes = PaginationArk.fromCJ(reqs
                        .pagination
                        .getOrThrow())

                    run2JS {
                        returnFunc(bookResArray, pagiinationRes)
                    }
                } else {
                    run2JS {
                        errorFunc('获取错误:${reqs.errorInfo.getOrDefault {=> '未知错误'}}')
                    }
                }
            } catch (err: Exception) {
                Hilog.info(1414, '1145', 'err:${err.message}')
                run2JS {
                    errorFunc(err.message)
                }
            }
        }
    }

    public func getRecommendBook(returnFunc: (JSArrayEx<ZlibBookInfoBriefArk>) -> Unit, errorFunc: (String) -> Unit): Unit {
        spawn {
            try {
                Hilog.info(1414, '1145', '开始获取')
                let reqs = cjValue.getRecommendBook()
                if (reqs.success == 1) {
                    let tempBooks = reqs
                        .books
                        .getOrThrow()
                        .map {
                            book => ZlibBookInfoBriefArk.fromCJ(book)
                        }
                    let bookResArray = JSArrayEx<ZlibBookInfoBriefArk>(tempBooks)

                    run2JS {
                        returnFunc(bookResArray)
                    }
                } else {
                    run2JS {
                        errorFunc('获取错误:${reqs.errorInfo.getOrDefault {=> '未知错误'}}')
                    }
                }
            } catch (err: Exception) {
                run2JS {
                    errorFunc(err.message)
                }
            }
        }
    }

    public ZlibUserInfoArk() {}
}

@Interop[ArkTS]
public class PaginationArk {
    public var limit: UInt64 = 0
    public var current: UInt64 = 0
    public var totalItems: UInt64 = 0
    public var totalPages: UInt64 = 0

    @Interop[ArkTS, Invisible]
    public static func fromCJ(cjValue: Pagination): PaginationArk {
        let r = PaginationArk()
        r.limit = cjValue.limit
        r.current = cjValue.current
        r.totalItems = cjValue.totalItems
        r.totalPages = cjValue.totalPages
        r
    }
    public PaginationArk() {}
}

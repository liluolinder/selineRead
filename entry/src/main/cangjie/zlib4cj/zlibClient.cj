/**
 * Created on 2026/3/7
 */
package ohos_app_cangjie_entry.zlib4cj

import ohos.ark_interop.*
import ohos.ark_interop_macro.*
import zlibraryAPI4CJ.*
import zlibraryAPI4CJ.dataModel.*
import zlibraryAPI4CJ.common.canAccessZlib
import zlibraryAPI4CJ.common.zlibBaseUrl
import zlibraryAPI4CJ.common.zlibEAPI
import ohos_app_cangjie_entry.run2JS
import ohos.hilog.Hilog
import zlibraryAPI4CJ.common.changeUrl
import zlibraryAPI4CJ.common.checkAccessByAddr

@Interop[ArkTS]
public class ZlibClientArk {
    let client: ZlibClient = ZlibClient()

    public func checkAccess(autoRedirect: Bool, returnFunc: (Bool) -> Unit, errorFunc: (String) -> Unit): Unit {
        spawn {
            try {
                let res = canAccessZlib(autoRedirect: autoRedirect)
                run2JS {
                    returnFunc(res)
                }
            } catch (err: Exception) {
                run2JS {
                    errorFunc(err.toString())
                }
            }
        }
    }

    public func checkAccessByAddress(address: String, autoRedirect: Bool, returnFunc: (Bool, String) -> Unit,
        errorFunc: (String) -> Unit): Unit {
        spawn {
            try {
                let (canAccess, location) = checkAccessByAddr(address, autoRedirect: autoRedirect)
                run2JS {
                    returnFunc(canAccess, location)
                }
            } catch (err: Exception) {
                run2JS {
                    errorFunc(err.toString())
                }
            }
        }
    }

    public func getRecommendBook(returnFunc: (JSArrayEx<ZlibBookInfoBriefArk>) -> Unit, errorFunc: (String) -> Unit): Unit {
        spawn {
            try {
                let reqs = client.getRecommendBook()
                if (reqs.success == 1) {
                    let temp = reqs
                        .books
                        .getOrThrow()
                        .map({bookInfo => ZlibBookInfoBriefArk.fromCJ(bookInfo)})
                    let res = JSArrayEx<ZlibBookInfoBriefArk>(temp)
                    run2JS {
                        returnFunc(res)
                    }
                } else {
                    run2JS {
                        errorFunc("获取错误:${reqs.errorInfo.getOrDefault({=> '未知错误'})}")
                    }
                }
            } catch (error: Exception) {
                run2JS {
                    errorFunc(error.toString())
                }
            }
        }
    }

    public func login(email: String, password: String, returnFunc: (ZlibUserInfoArk) -> Unit,
        errorFunc: (String) -> Unit): Unit {
        spawn {
            try {
                let reqs = client.login(email: email, password: password)

                if (reqs.success == 1) {
                    if (let Some(info) <- reqs.userInfo) {
                        let res = ZlibUserInfoArk.fromCJ(info)
                        run2JS {
                            returnFunc(res)
                        }
                    }
                } else {
                    run2JS {
                        errorFunc("获取错误:${reqs.errorInfo.getOrDefault({=> '未知错误'})}")
                    }
                }
            } catch (err: Exception) {
                run2JS {
                    errorFunc(err.toString())
                }
            }
        }
    }

    public func search(bookName: String, page: UInt16, returnFunc: (JSArrayEx<ZlibBookInfoBriefArk>) -> Unit,
        errorFunc: (String) -> Unit): Unit {
        spawn {
            try {
                let reqs = client.search(message: bookName, page: page)
                if (reqs.success == 1) {
                    let temp = reqs
                        .books
                        .getOrThrow()
                        .map(
                            {
                                bookinfo: BookInfo =>
                                    let book = BookInfoBrief()
                                    book.title = bookinfo.title
                                    book.id = bookinfo.id
                                    book.hash = bookinfo.hash
                                    book.author = bookinfo
                                        .author
                                        .getOrDefault {''}
                                    book.cover = bookinfo.cover
                                    ZlibBookInfoBriefArk.fromCJ(book)
                            }
                        )

                    let res = JSArrayEx<ZlibBookInfoBriefArk>(temp)

                    run2JS {
                        returnFunc(res)
                    }
                } else {
                    run2JS {
                        errorFunc("获取错误:搜索错误")
                    }
                }
            } catch (err: Exception) {
                run2JS {
                    errorFunc(err.message)
                }
            }
        }
    }

    public func getZlibUrl(returnFunc: (String) -> Unit): Unit {
        spawn {
            run2JS {
                returnFunc(zlibBaseUrl)
            }
        }
    }

    public func setZlibUrl(url: String): Unit {
        changeUrl(url)
    }

    public ZlibClientArk() {}
}

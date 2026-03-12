/**
 * Created on 2026/3/7
 */
package ohos_app_cangjie_entry.zlibAPI4cj

import ohos.ark_interop.*
import ohos.ark_interop_macro.*
import zlibraryAPI4CJ.*
import zlibraryAPI4CJ.dataModel.*
import zlibraryAPI4CJ.common.canAccessZlib
import zlibraryAPI4CJ.common.zlibBaseUrl
import zlibraryAPI4CJ.common.zlibEAPI

var globalcontext: Option<JSContext> = None

let _ = JSModule.registerModule {context, _ => globalcontext = context}

@Interop[ArkTS]
public class ZlibClientArk {
    let client: ZlibClient = ZlibClient()

    public func checkAccess(autoRedirect: Bool, returnFunc: (Bool) -> Unit, errorFunc: (String) -> Unit): Unit {
        if (let Some(context) <- globalcontext) {
            spawn {
                try {
                    let res = canAccessZlib(autoRedirect: autoRedirect)
                    context.postJSTask {
                        returnFunc(res)
                    }
                } catch (err: Exception) {
                    context.postJSTask {
                        errorFunc(err.toString())
                    }
                }
            }
        }
    }

    public func getRecommendBook(returnFunc: (JSArrayEx<ZlibBookInfoBriefArk>) -> Unit, errorFunc: (String) -> Unit): Unit {
        if (let Some(context) <- globalcontext) {
            spawn {
                try {
                    let reqs = client.getRecommendBook()
                    if (reqs.success == 1) {
                        let temp = reqs
                            .books
                            .getOrThrow()
                            .map({bookInfo => ZlibBookInfoBriefArk.fromCJ(bookInfo)})
                        let res = JSArrayEx<ZlibBookInfoBriefArk>(temp)
                        context.postJSTask {
                            returnFunc(res)
                        }
                    } else {
                        context.postJSTask {
                            errorFunc("获取错误:${reqs.errorInfo.getOrDefault({=> '未知错误'})}")
                        }
                    }
                } catch (error: Exception) {
                    context.postJSTask {
                        errorFunc(error.toString())
                    }
                }
            }
        }
    }

    public func login(email: String, password: String, returnFunc: (ZlibUserInfoArk) -> Unit,
        errorFunc: (String) -> Unit): Unit {
        if (let Some(context) <- globalcontext) {
            spawn {
                try {
                    let reqs = client.login(email: email, password: password)

                    if (reqs.success == 1) {
                        if (let Some(info) <- reqs.userInfo) {
                            let res = ZlibUserInfoArk.fromCJ(info)
                            context.postJSTask {returnFunc(res)}
                        }
                    } else {
                        context.postJSTask {
                            errorFunc("获取错误:${reqs.errorInfo.getOrDefault({=> '未知错误'})}")
                        }
                    }
                } catch (err: Exception) {
                }
            }
        }
    }

    public func search(bookName: String, page: UInt16, returnFunc: (JSArrayEx<ZlibBookInfoBriefArk>) -> Unit,
        errorFunc: (String) -> Unit): Unit {
        if (let Some(context) <- globalcontext) {
            spawn {
                try {
                    let reqs = client.search(message: bookName, page: page)
                    if (reqs.success == 1) {
                        let temp = reqs
                            .books
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
                        context.postJSTask {
                            returnFunc(res)
                        }
                    } else {
                        context.postJSTask {
                            errorFunc("获取错误:搜索错误")
                        }
                    }
                } catch (err: Exception) {
                }
            }
        }
    }

    public func getZlibUrl(returnFunc: (String) -> Unit):Unit{
        if (let Some(context) <- globalcontext) {
            spawn {
                context.postJSTask {
                        returnFunc(zlibBaseUrl)
                    }
            }
        }
    }

    public func setZlibUrl(url:String):Unit{
        zlibBaseUrl = url
        zlibEAPI = "${zlibBaseUrl}/eapi"
    }

    public ZlibClientArk() {}
}

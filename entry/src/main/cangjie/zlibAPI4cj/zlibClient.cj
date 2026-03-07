/**
 * Created on 2026/3/7
 */
package ohos_app_cangjie_entry.zlibAPI4cj

import ohos.ark_interop.*
import ohos.ark_interop_macro.*
import zlibraryAPI4CJ.*
import zlibraryAPI4CJ.dataModel.*
import zlibraryAPI4CJ.common.canAccessZlib

@Interop[ArkTS]
public class ZlibClientArk {
    let client: ZlibClient = ZlibClient()

    public func checkAccess(autoRedirect: Bool, returnFunc: (Bool) -> Unit, errorFunc: (String) -> Unit): Unit {
        let context = JSRuntime().mainContext
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

    public func getRecommendBook(returnFunc: (JSArrayEx<ZlibBookInfoBriefArk>) -> Unit, errorFunc: (String) -> Unit): Unit {
        let context = JSRuntime().mainContext
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
                        errorFunc("获取错误:${reqs.errorInfo.getOrDefault({=> '位置错误'})}")
                    }
                }
            } catch (error: Exception) {
                context.postJSTask {
                    errorFunc(error.toString())
                }
            }
        }
    }

    public func login(email: String, password: String, returnFunc: () -> Unit, errorFunc: (String) -> Unit): Unit {
        let context = JSRuntime().mainContext
        spawn {
            try {
                client.login(email: email, password: password)
            } catch (err: Exception) {
            }
        }
    }

    public ZlibClientArk() {}
}

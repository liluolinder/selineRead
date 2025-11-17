package ohos_app_cangjie_entry

internal import ohos.ark_interop.JSModule
internal import ohos.ark_interop.JSContext
internal import ohos.ark_interop.JSCallInfo
internal import ohos.ark_interop.JSValue
internal import cj_res_entry.app
import ohos_app_cangjie_entry.zlibTools.*

func testCJ(runtime: JSContext, callInfo: JSCallInfo): JSValue {
    let value = callInfo[0].toString(runtime)
    let result = "Hello ${value}"
    runtime.string(result).toJSValue()
}

let EXPORT_MODULE = JSModule.registerModule {
    runtime, exports =>
    exports["testCJ"] = runtime.function(testCJ).toJSValue()
    exports["getBookInfo"] = runtime.function(getBookInfo).toJSValue()
    exports["getSearchBookArray"] = runtime.function(getSearchBookArray).toJSValue()
    exports["getBookFirstDownloadUrl"] = runtime.function(getBookFirstDownloadUrl).toJSValue()
    exports["getBookFirstDownloadInfo"] = runtime.function(getBookFirstDownloadInfo).toJSValue()
    exports["getUserDownloadLimitAndDonation"] = runtime.function(getUserDownloadLimitAndDonation).toJSValue()
    exports["getUserAvatar"] = runtime.function(getUserAvatar).toJSValue()
    exports["getUserName"] = runtime.function(getUserName).toJSValue()
    exports["getReadUrl"] = runtime.function(getReadUrl).toJSValue()
    exports["getTerms"] = runtime.function(getTerms).toJSValue()
    exports["getSearchTermsArray"] = runtime.function(getSearchTermsArray).toJSValue()
    exports["getBookShelfIsLoved"] = runtime.function(getBookShelfIsLoved).toJSValue()

}

/*
Copyright (c) 2025 琉离铟落linder
SelineRead is licensed under Mulan PSL v2.
You can use this software according to the terms and conditions of the Mulan
PSL v2.
You may obtain a copy of Mulan PSL v2 at:
         http://license.coscl.org.cn/MulanPSL2
THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY
KIND, EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO
NON-INFRINGEMENT, MERCHANTABILITY OR FIT FOR A PARTICULAR PURPOSE.
See the Mulan PSL v2 for more details.

Mulan Permissive Software License，Version 2

Mulan Permissive Software License，Version 2 (Mulan PSL v2)

January 2020 http://license.coscl.org.cn/MulanPSL2
 */

package ohos_app_cangjie_entry

import ohos_app_cangjie_entry.tools.getBookInfo
internal import ohos.ark_interop.JSModule
internal import ohos.ark_interop.JSContext
internal import ohos.ark_interop.JSCallInfo
internal import ohos.ark_interop.JSValue
internal import cj_res_entry.app
import ohos_app_cangjie_entry.tools.*


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
}

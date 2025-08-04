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

package ohos_app_cangjie_entry.tools

import html4cj.*
import encoding.json.*
import ohos.base.AppLog
import std.console.Console

public func getUserDownloadLimitAndDonation(runtime: JSContext, callInfo: JSCallInfo): JSValue {
    let htmlString:String = callInfo[0].toString(runtime)
    var doc: Document = Html4cj.parse(htmlString)
    var ascriptAll: Elements = doc.select("div")
    var jsonMap = JsonObject()

    var index:Int64 = 0

    for (i in ascriptAll)
    {
        if (i.attr("class")==#"\"caret-scroll__title\""#)
        {
            index++
            match (index)
            {
                case 2 =>
                    jsonMap.put("downloadLimit",JsonString(i.html().toString().replace("\\n ","")))
                case 4 =>
                    jsonMap.put("donation",JsonString(i.html().toString().replace("\\n ","")))
                case _ =>
                    continue
            }
        }
    }
     runtime.string(jsonMap.toString()).toJSValue()
}
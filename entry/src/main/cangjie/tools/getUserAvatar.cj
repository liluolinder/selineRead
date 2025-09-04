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

import encoding.json.*
import html4cj.*
import ohos.base.AppLog
import std.collection.*

public func getUserAvatar(runtime: JSContext, callInfo: JSCallInfo): JSValue
{
    let htmlString:String = callInfo[0].toString(runtime)
    var doc: Document = Html4cj.parse(htmlString)
    var ascriptAll: Elements = doc.select('z-account')
    var res:String=''
    for (i in ascriptAll)
    {
        if (i.hasAttr('avatar'))
        {
             res = i.attr('avatar').toString().replace("\\n","").replace("\\\"","")
             AppLog.info('Liquid${i.attr('avatar').toString().replace("\\n","").replace("\\\"","")}')
            break
        }
    }
    runtime.string(res).toJSValue()
}
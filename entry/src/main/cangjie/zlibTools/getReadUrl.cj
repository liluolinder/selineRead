package ohos_app_cangjie_entry.zlibTools

public func getReadUrl(runtime: JSContext, callInfo: JSCallInfo): JSValue {
 let htmlString:String = callInfo[0].toString(runtime)
    var doc: Document = Html4cj.parse(htmlString)
    var ascriptAll: Elements = doc.select('a')
    var res:String = ''
    var index:Int64 = 0
    for (i in ascriptAll)
    {
        if (i.attr('class')==#"\"btn"#)
        {
            if (i.attr('href').toString().contains('reader'))
            {
                res = i.attr('href').toString()
                break
            }

        }
    }

     runtime.string(res.replace("\\\"", "")).toJSValue()
}

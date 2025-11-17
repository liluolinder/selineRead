package ohos_app_cangjie_entry.zlibTools

public func getBookInfo(runtime: JSContext, callInfo: JSCallInfo): JSValue {
    let htmlString:String = callInfo[0].toString(runtime)
    var doc: Document = Html4cj.parse(htmlString)
    var ascriptAll: Elements = doc.select("script")
    var index = 0
    var res:String = ''

    for(i in ascriptAll ){
       if (i.attr('type').toString()==#"\"application/ld+json\""#)
        {
            if (index == 1)
            {
               res = i.html().toString()
                break
            }
            index ++
        }
    }

     runtime.string(res).toJSValue()
}

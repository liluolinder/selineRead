package ohos_app_cangjie_entry.zlibTools

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
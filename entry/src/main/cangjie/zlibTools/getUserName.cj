package ohos_app_cangjie_entry.zlibTools

public func getUserName(runtime: JSContext, callInfo: JSCallInfo): JSValue
{
    let htmlString:String = callInfo[0].toString(runtime)
    var doc: Document = Html4cj.parse(htmlString)
    var ascriptAll: Elements = doc.select('a')
    var res:String=''
    var index:Int64 = 0
    for (i in ascriptAll)
    {
        if (i.attr('href')==#"\"/profile\""#)
        {
            if (index == 1)
            {
                res=i.html()
            }

            index++
        }
    }
    runtime.string(res).toJSValue()
}
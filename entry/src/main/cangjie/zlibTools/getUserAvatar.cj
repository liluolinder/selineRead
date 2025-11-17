package ohos_app_cangjie_entry.zlibTools

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
            break
        }
    }
    runtime.string(res).toJSValue()
}
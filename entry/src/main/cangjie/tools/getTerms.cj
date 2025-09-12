/**
 * Created on 2025/9/12
 */
package ohos_app_cangjie_entry.tools


public func getTerms(runtime: JSContext, callInfo: JSCallInfo): JSValue
{
    let htmlString:String = callInfo[0].toString(runtime)
    var doc: Document = Html4cj.parse(htmlString)
    var ascriptAll: Elements = doc.select('div')
    var jsonList: ArrayList<JsonValue> = ArrayList<JsonValue>()
    var res:String=''
    for (i in ascriptAll)
    {
        if (i.attr('class')==#'\"termsCloud\"'#)
        {
            doc = Html4cj.parse(i.html())
            ascriptAll = doc.select('a')
            break
        }
    }

    for (i in ascriptAll)
    {
        var jsonMap = JsonObject()
         jsonMap.put('term',JsonString(i.html()))
        jsonMap.put('href',JsonString(i.attr('href').replace("\\\"", "")))
        jsonMap |> jsonList.append
    }

    runtime.string(jsonList.toString()).toJSValue()
}
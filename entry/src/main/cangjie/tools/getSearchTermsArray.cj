/**
 * Created on 2025/9/13
 */
package ohos_app_cangjie_entry.tools

public func getSearchTermsArray(runtime: JSContext, callInfo: JSCallInfo): JSValue {
    let htmlString: String = callInfo[0].toString(runtime)
    var doc: Document = Html4cj.parse(htmlString)
    var ascriptAll: Elements = doc.select('z-bookcard')
    var jsonList: ArrayList<JsonValue> = ArrayList<JsonValue>()
    var res: String = ''
    for (i in ascriptAll) {
        var jsonMap = JsonObject()
         jsonMap.put('id',JsonString(i.attr('id')))
         jsonMap.put('isbn',JsonString(i.attr('isbn')))
        jsonMap.put('href',JsonString(i.attr('href')))
        jsonMap.put('publisher',JsonString(i.attr('publisher')))
        jsonMap.put('language',JsonString(i.attr('language')))
        jsonMap.put('year',JsonString(i.attr('year')))
        jsonMap.put('extension',JsonString(i.attr('extension')))
        jsonMap.put('filesize',JsonString(i.attr('filesize')))
        jsonMap.put('language',JsonString(i.attr('language')))
        jsonMap.put('year',JsonString(i.attr('year')))
        var doc1: Document = Html4cj.parse(i.html())
        var ascriptAll1: Elements = doc1.select('div')
        for (j in ascriptAll1){
            if (j.attr('slot') == 'title')
            {
                jsonMap.put('title',JsonString(j.html()))
            }
            if (j.attr('slot') == 'author')
            {
                 jsonMap.put('writer',JsonString(j.html()))
            }
        }
        doc1 = Html4cj.parse(i.html())
        ascriptAll1 = doc1.select('img')
        for (j in ascriptAll1){
            if (j.hasAttr('data-src')){
                jsonMap.put('image',JsonString(if(j.attr('data-src') != '/img/cover-not-exists.png'){j.attr('data-src')}else{''}))
                break
            }
        }
        jsonList.append(jsonMap)
    }
    jsonList.toString() |> AppLog.info
    runtime.string(jsonList.toString()).toJSValue()
}

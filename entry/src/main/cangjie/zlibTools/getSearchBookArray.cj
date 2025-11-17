package ohos_app_cangjie_entry.zlibTools


public func getSearchBookArray(runtime: JSContext, callInfo: JSCallInfo): JSValue {
    let htmlString:String = callInfo[0].toString(runtime)
    var doc: Document = Html4cj.parse(htmlString)

    var ascriptAll: Elements = doc.select(#"div"#)

    var jsonList: ArrayList<JsonValue> = ArrayList<JsonValue>()

    for(i in ascriptAll ){

        if(i.attr('class')==#"\"book-item"#)
        {
            var jsonMap = JsonObject()
            doc = Html4cj.parse(i.html().replace('\\n',''))
            var ascriptAll1: Elements = doc.select("z-bookcard")
            for(j in ascriptAll1)
            {
                jsonMap.put('id',JsonString(j.attr('id').replace("\\\"", "")))
                jsonMap.put('isbn',JsonString(j.attr('isbn').replace("\\\"", "")))
                jsonMap.put('href',JsonString(j.attr('href').replace("\\\"", "")))
                jsonMap.put('publisher',JsonString(j.attr('publisher').replace("\\\"", "")))
                jsonMap.put('language',JsonString(j.attr('language').replace("\\\"", "")))
                jsonMap.put('year',JsonString(j.attr('year').replace("\\\"", "")))
                jsonMap.put('extension',JsonString(j.attr('extension').replace("\\\"", "")))
                jsonMap.put('filesize',JsonString(j.attr('filesize').replace("\\\"", "")))
                doc = Html4cj.parse(j.html())
                ascriptAll1 = doc.select('img')
                jsonMap.put('image',JsonString(ascriptAll1[0].attr('data-src').replace("\\\"", "")))
                ascriptAll1 = doc.select('div')
                jsonMap.put('title',JsonString(ascriptAll1[0].html()))
                jsonMap.put('writer',JsonString(ascriptAll1[1].html()))
                jsonMap |> jsonList.append
            }
        }

    }

     runtime.string(jsonList.toString()).toJSValue()
}
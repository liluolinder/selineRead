package ohos_app_cangjie_entry.zlibTools

public func getBookFirstDownloadUrl(runtime: JSContext, callInfo: JSCallInfo): JSValue {
    let htmlString:String = callInfo[0].toString(runtime)
    var doc: Document = Html4cj.parse(htmlString)
    var ascriptAll: Elements = doc.select('a')
    var res:String = ''
    var index:Int64 = 0
    for (i in ascriptAll)
    {
        if (i.attr('class')==#"\"btn"#)
        {
            if (i.attr('href').toString().contains('/dl/'))
            {
                res = i.attr('href').toString()
                break
            }

        }
    }
     runtime.string(res).toJSValue()
}

public func getBookFirstDownloadInfo(runtime: JSContext, callInfo: JSCallInfo): JSValue {
    let htmlString:String = callInfo[0].toString(runtime)

    var doc: Document = Html4cj.parse(htmlString)
    var ascriptAll: Elements = doc.select('span')

    var map = JsonObject()

    var format:String=''

    var size:String=''

    var index:Int64 = 0

    var tempStr:String=''
    for (i in ascriptAll)
    {

        if (i.attr('class')==#"\"book-property__extension\""#)
        {
            format = i.html()

        }
    }

    ascriptAll = doc.select('a')

   for (i in ascriptAll)
    {
        if (i.attr('class')==#"\"btn"#)
        {
            tempStr = i.html()
            var tempArray:Array<String> =  tempStr.split(',')
            if (tempArray.size==2)
            {
                size = tempArray[tempArray.size-1].replace(" ",'')
                break
            }
        }
    }
    map.put("format",JsonString(format))
    map.put("size",JsonString(size))
    runtime.string(map.toString()).toJSValue()
}
package ohos_app_cangjie_entry.zlibTools
public func getBookShelfIsLoved(runtime: JSContext, callInfo: JSCallInfo): JSValue {
    let htmlString: String = callInfo[0].toString(runtime)
    var doc: Document = Html4cj.parse(htmlString)
    var ascriptAll: Elements = doc.select("div")
    var index = 0
    var res: Bool = false
    for (i in ascriptAll) {
        if (i.attributes().toString() == #" class="\&quot;favorite-booklist" active\"#) {
            res = true
            break
        } else if (i.attributes().toString() == #" class="\&quot;favorite-booklist" \"#) {
            res = false
            break
        }
    }
    runtime.boolean(res).toJSValue()
}


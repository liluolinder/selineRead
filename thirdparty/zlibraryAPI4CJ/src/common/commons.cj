package zlibraryAPI4CJ.common

import linderHttp.*
import std.fs.Path
import stdx.encoding.url.*

public var zlibBaseUrl: String = "https://tw.jiaoyuan.ru"
public var zlibEAPI: String = "${zlibBaseUrl}/eapi"

public func changeUrl(url: String) {
    zlibBaseUrl = url
    zlibEAPI = URL.parse(zlibBaseUrl).replace(path:'/eapi').toString()
}

public func canAccessZlib(autoRedirect!: Bool = false): Bool {
    var httpClient = LinderHttpClient(readTimeout: Duration.minute, writeTimeout: Duration.minute, autoRedirect: false, method:RequestMethod.HEAD)
    try {
         let res = httpClient.setUrl(zlibBaseUrl).send()
    	if (autoRedirect && let Some(location) <- res.location) {
        changeUrl(location[0])
        true
    } else if (res.status == 503 || res.status == 200 ) {
        true
    } else {
        false
    }
    }catch (err:Exception){
        false
    }
}

public func checkAccess(url:String):Bool{
     var httpClient = LinderHttpClient(readTimeout: Duration.minute, writeTimeout: Duration.minute, autoRedirect: false, method:RequestMethod.HEAD)

    try {
    	let res = httpClient.setUrl(url).send()

    if (res.status == 503 || res.status == 200) {
        true
    } else {
        false
    }
    }catch (err:Exception){
        false
    }
}
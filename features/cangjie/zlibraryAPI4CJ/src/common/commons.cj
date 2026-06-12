package zlibraryAPI4CJ.common

import linderHttp.*
import std.fs.Path
import stdx.encoding.url.*

public var zlibBaseUrl: String = "https://zh.zlibraryd.ru"
public var zlibEAPI: String = "${zlibBaseUrl}/eapi"

public func changeUrl(url: String) {
    zlibBaseUrl = url
    zlibEAPI = URL.parse(zlibBaseUrl).replace(path:'/eapi').toString()
}

public func canAccessZlib(autoRedirect!: Bool = false): Bool {
    var httpClient = LinderHttpClient(readTimeout: Duration.minute, writeTimeout: Duration.minute, autoRedirect: false, method:RequestMethod.HEAD)

    let res = httpClient.setUrl(zlibBaseUrl).send()

    if (autoRedirect && let Some(location) <- res.location) {
        changeUrl(location[0])
        true
    } else if (res.status != 302) {
        true
    } else {
        false
    }
}

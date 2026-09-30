package linderHttp.http

/*
 * 包级内部导入中心。
 *
 * 仓颉的 import 作用域是整个 package：这里集中导入后，同包其它文件无需重复导入。
 *
 * 注意：stdx.net.http 使用「显式名单」而非 `*`，目的是把 stdx 的 Cookie / CookieJar /
 * WebSocket 等名字挡在命名空间之外，避免和本库自己的同名类型冲突。
 */

internal import std.collection.*
internal import std.io.*
internal import std.time.*
internal import std.sync.*
internal import std.fs.*
internal import std.random.*
internal import std.convert.*
internal import std.env.*
internal import std.net.*
internal import stdx.encoding.json.*
internal import stdx.encoding.url.{URL, Form}
internal import stdx.net.tls.*
internal import stdx.net.tls.common.*
internal import stdx.net.http.{
    Client,
    ClientBuilder,
    HttpRequest,
    HttpRequestBuilder,
    HttpResponse,
    HttpHeaders,
    HttpException,
    HttpTimeoutException,
    ConnectionException,
    WebSocketFrame,
    WebSocketFrameType
}
/* 底层 WebSocket 用别名导入，避免和本库对外的 WebSocket 类型重名 */
internal import stdx.net.http.WebSocket as NativeWebSocket
internal import stdx.serialization.serialization.DataModel
internal import stdx.crypto.x509.X509Certificate
internal import stdx.crypto.common.*
internal import stdx.log.{LogLevel}
internal import stdx.logger.SimpleLogger
/* WebSocket 客户端握手需要默认加密套件实现，必须显式引入该注册包 */
internal import stdx.crypto.kit.*
internal import stdx.compress.zlib.*

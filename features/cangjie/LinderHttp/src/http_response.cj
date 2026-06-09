package linderHttp

/**
 * HTTP响应封装类
 * 
 * 提供HTTP响应数据的访问和处理功能。
 * 
 * ## 功能特性
 * - 多种响应体读取方式（字符串、JSON、字节流、文件）
 * - 自动解析常用响应头
 * - 支持响应头快速访问
 * 
 * ## 注意事项
 * - 响应体流只能读取一次，多次读取会返回空或异常
 */
public class LinderHttpResponse {
    /**
     * 构造HTTP响应对象
     * 无需手动构造
     * @param body 响应体数据流（必需）   读取body只能读取一次，调用2次返回为空或异常报错
     * @param bodySize 响应体字节长度（可选）
     * @param status HTTP状态码（如200）
     * @param headers 响应头集合（键值对容器）
     * @param isPersistent 连接是否保持
     * @param request 关联的请求对象（可选）
     */
    public LinderHttpResponse(
        public var body!: ?InputStream = None,
        public var bodySize!: ?Int64 = None,
        public var status!: UInt16,
        public var headers!: HttpHeaders,
        public var isPersistent!: Bool,
        public var request!: ?HttpRequest = None
    ) {}

    public init() {
        body = None
        bodySize = None
        status = 0
        headers = HttpHeaders()
        isPersistent = false
        request = None
    }

    /**
     * 重定向目标地址
     * @return None类型表示无重定向头，Some(Array<String>)或包含1-N个URL
     * 从`Location`头部提取的URL地址数组
     */
    public prop location: ?Array<String> {
        get() {
            let tempRes = headers.get('location')
            if (tempRes.isEmpty()) {
                None
            } else {
                tempRes.toArray()
            }
        }
    }

    /**
     * 内容类型标识
     * 从`Content-Type`头部提取的MIME类型数组
     * @return None类型表示无内容类型标识，Some(Array<String>)或包含1-N个内容类型标识
     * 示例：["application/json; charset=utf-8"]
     */
    public prop contentType: ?Array<String> {
        get() {
            let tempRes = headers.get('content-type')
            if (tempRes.isEmpty()) {
                None
            } else {
                tempRes.toArray()
            }
        }
    }

    /**
     * 服务端设置的Cookie
     * 从`Set-Cookie`头部提取的Cookie字符串数组
     *  @return None类型表示无Cookie字符串数组，Some(Array<String>)或包含1-N个Cookie字符串
     * 格式：["name=value; Path=/; Domain=example.com"]
     */
    public prop setCookie: ?Array<String> {
        get() {
            let tempRes = headers.get('set-cookie')
            if (tempRes.isEmpty()) {
                None
            } else {
                tempRes.toArray()
            }
        }
    }

    /**
     * 获取指定响应头的值
     *
     * @param header 头部字段名
     * @return 头部值数组（同名字段多个值时按顺序返回）, None类型表示无
     *
     * 示例：`getHeader("cache-control")`返回["max-age=3600"]
     */
    public func getHeader(header: String): ?Array<String> {
        let tempRes = headers.get(header)
        if (tempRes.isEmpty()) {
            None
        } else {
            tempRes.toArray()
        }
    }

    /**
     * 获取原始响应体流
     *
     * @return 未解码的二进制数据流
     *
     */
    public func getBodyStream(): InputStream {
        body.getOrThrow()
    }

    /**
     * 获取响应体字符串
     *
     * @return 按默认编码解码的字符串
     * @Throw 会触发异常，详见std.io.* std.fs.*
     */
    public func getBodyString(): String {
        StringReader<InputStream>(body.getOrThrow()).readToEnd()
    }

    public func getBodyJsonString(): String {
        JsonValue.fromStr(getBodyString()).toJsonString()
    }

    public func getBodyJsonValue(): JsonValue {
        JsonValue.fromStr(getBodyString())
    }

    public func getBodyJsonObject(): JsonObject {
        getBodyJsonValue().asObject()
    }

    public func getBodyDataModel(): DataModel {
        DataModel.fromJson(getBodyJsonValue())
    }

    /**
     * 获取响应体字节缓冲
     *
     * @return 内存连续的二进制数据缓冲
     * @Throw 触发异常，详见std.io.* std.fs.*
     */
    public func getBodyByteBuffer(): ByteBuffer {
        let bitArray: Array<Byte> = Array<Byte>(1024, repeat: 0)
        let byteBuffer: ByteBuffer = ByteBuffer()

        var readSize = body.getOrThrow().read(bitArray)

        do {
            byteBuffer.write(bitArray[0..readSize])
            readSize = body.getOrThrow().read(bitArray)
        } while (readSize > 0)

        byteBuffer
    }

    /**
     * 将响应体保存为文件
     *
     * @param filePath 目标文件路径（需包含文件名）
     * @param conflictMethod 文件冲突处理策略（默认重命名）
     * @Throw 触发异常，详见std.io.* std.fs.*
     * 冲突策略说明：
     *   - `ConflictMethod.Harmony`：自动重命名（如file.txt → file(1).txt）
     *   - `ConflictMethod.OverWrite`：覆盖现有文件
     *
     */
    public func getBodyFile(filePath!: Path, conflictMethod!: ConflictMethod = ConflictMethod.Harmony): Unit {
        exportToFile(content: body.getOrThrow(), filePath: filePath, conflictMethod: conflictMethod,
            )
    }

    /**
     * 打印响应头到控制台
     *
     * 输出格式：`HeaderName: [value1,value2]`
     * 适用场景：调试时快速检查响应头
     */
    public func printHeaders(): Unit {
        headers.iterator()
        for (i in headers) {
            println(i[0] + ':' + i[1].toArray().toString())
        }
    }
}

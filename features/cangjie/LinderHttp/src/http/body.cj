package linderHttp.http

/**
 * 请求体。
 *
 * 把「要发什么」收敛成一个类型，调用方不必关心底层 `HttpRequestBuilder` 的多个重载。
 * 两种形态：
 * - 内存型（已落地字节）：长度已知，可安全重试（重发时无需重新构造流）；
 * - 流式（输入流）：长度可能未知，走分块传输；重试会复用同一个流，因此流式请求默认不重试。
 */
public class Body <: ToString {
    private let payload: ?Array<Byte>
    private let source: ?InputStream
    private let mediaTypeValue: ?String
    private let lengthValue: ?Int64

    private init(payload: ?Array<Byte>, source: ?InputStream, mediaTypeValue: ?String,
        lengthValue: ?Int64) {
        this.payload = payload
        this.source = source
        this.mediaTypeValue = mediaTypeValue
        this.lengthValue = lengthValue
    }

    /** UTF-8 文本体。 */
    public static func text(value: String, contentType!: String = "text/plain; charset=utf-8"): Body {
        let data = value.toArray()
        Body(data, None, contentType, data.size)
    }

    /** 任意字符串体，Content-Type 由调用方指定（例如 `application/xml`）。 */
    public static func of(value: String, contentType!: String): Body {
        text(value, contentType: contentType)
    }

    /** JSON 体（由 JsonValue 序列化）。 */
    public static func json(value: JsonValue): Body {
        text(value.toString(), contentType: "application/json")
    }

    public static func json(value: JsonObject): Body {
        text(value.toString(), contentType: "application/json")
    }

    /** 已经是 JSON 文本时直接发，省一次解析。 */
    public static func jsonText(value: String): Body {
        text(value, contentType: "application/json")
    }

    /** 序列化框架的数据模型。 */
    public static func dataModel(value: DataModel): Body {
        text(value.toJson().toString(), contentType: "application/json")
    }

    /** 字节体。 */
    public static func bytes(value: Array<Byte>,
        contentType!: String = "application/octet-stream"): Body {
        Body(value, None, contentType, value.size)
    }

    /** 流式体；长度未知时传 None，底层会使用分块传输。 */
    public static func stream(value: InputStream,
        contentType!: String = "application/octet-stream", length!: ?Int64 = None): Body {
        Body(None, value, contentType, length)
    }

    /** 直接把文件作为请求体；长度取自文件大小。 */
    public static func file(path: Path, contentType!: String = "application/octet-stream"): Body {
        let size = File(path, OpenMode.Read).length
        Body(None, File(path, OpenMode.Read), contentType, Some(size))
    }

    /** 表单（application/x-www-form-urlencoded），值会自动做百分号编码。 */
    public static func form(fields: HashMap<String, String>): Body {
        let form = Form()
        for ((key, value) in fields) {
            form.add(key, value)
        }
        text(form.toEncodeString(), contentType: "application/x-www-form-urlencoded")
    }

    public static func form(fields: Array<(String, String)>): Body {
        let form = Form()
        for (pair in fields) {
            form.add(pair[0], pair[1])
        }
        text(form.toEncodeString(), contentType: "application/x-www-form-urlencoded")
    }

    /** multipart/form-data 体。 */
    public static func multipart(value: MultipartBody): Body {
        let data = value.build()
        Body(data, None, value.contentType(), data.size)
    }

    public static func empty(): Body {
        Body(Array<Byte>(), None, None, 0)
    }

    /** 内容类型；None 表示由引擎/调用方决定。 */
    public func mediaType(): ?String {
        mediaTypeValue
    }

    /** 是否为流式体（不可重复发送）。 */
    public func isStreaming(): Bool {
        payload.isNone()
    }

    /** 已知长度；None 表示长度未知。 */
    public func contentLength(): ?Int64 {
        lengthValue
    }

    /** 写入底层请求构建器。 */
    internal func applyTo(builder: HttpRequestBuilder): Unit {
        if (let Some(data) <- payload) {
            builder.body(data)
        } else if (let Some(input) <- source) {
            builder.body(input)
        }
    }

    public func toString(): String {
        match (payload) {
            case Some(data) => "Body(bytes=${data.size}, type=${mediaTypeValue})"
            case None => "Body(stream, length=${lengthValue}, type=${mediaTypeValue})"
        }
    }
}

/**
 * 把输入流读到结束；用于响应体落地与流式请求体的快照。
 */
internal func readStreamFully(source: InputStream): Array<Byte> {
    let buffer = ByteBuffer()
    let chunk = Array<Byte>(8192, repeat: 0)
    var read = source.read(chunk)
    while (read > 0) {
        buffer.write(chunk[0..read])
        read = source.read(chunk)
    }
    buffer.bytes()
}

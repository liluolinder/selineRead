package linderHttp.http

/**
 * multipart 表单的一个分段。
 */
public class MultipartPart {
    public let name: String
    public let fileName: ?String
    public let contentType: ?String
    private let data: ?Array<Byte>
    private let source: ?InputStream

    internal init(name: String, fileName: ?String, contentType: ?String, data: ?Array<Byte>,
        source: ?InputStream) {
        this.name = name
        this.fileName = fileName
        this.contentType = contentType
        this.data = data
        this.source = source
    }

    /** 该分段的内容字节（流式分段会被读入内存）。 */
    public func bytes(): Array<Byte> {
        match (data) {
            case Some(value) => value
            case None => readStreamFully(source.getOrThrow())
        }
    }

    public func isStreaming(): Bool {
        data.isNone()
    }
}

/**
 * multipart/form-data 构造器。
 *
 * 典型用法（文本字段 + 文件）：
 * ```cangjie
 * let form = MultipartBody.create()
 *     .text("name", "张三")
 *     .file("avatar", "photo.png", pngBytes, contentType: "image/png")
 * client.post("https://api.example.com/upload").multipart(form).send()
 * ```
 */
public class MultipartBody {
    private let boundary: String
    private let parts: ArrayList<MultipartPart> = ArrayList<MultipartPart>()

    private init(boundary: String) {
        this.boundary = boundary
    }

    /** 新建一个 multipart 体；不传 boundary 时自动生成。 */
    public static func create(boundary!: String = ""): MultipartBody {
        if (boundary.isEmpty()) {
            let rng = Random()
            let masked = rng.nextInt64() & 0x7FFF_FFFF_FFFF_FFFF
            MultipartBody("----LinderBoundary${masked}")
        } else {
            MultipartBody(boundary)
        }
    }

    public func boundaryText(): String {
        boundary
    }

    public func text(name: String, value: String): MultipartBody {
        parts.add(MultipartPart(name, None, None, Some(value.toArray()), None))
        this
    }

    public func file(name: String, fileName: String, content: Array<Byte>,
        contentType!: String = "application/octet-stream"): MultipartBody {
        parts.add(MultipartPart(name, Some(fileName), Some(contentType), Some(content), None))
        this
    }

    /** 直接以磁盘文件为分段，不把整个文件读进内存（发送时才会读取）。 */
    public func fileFromPath(name: String, path: Path, fileName!: String = "",
        contentType!: String = "application/octet-stream"): MultipartBody {
        let actualName = if (fileName.isEmpty()) { path.fileName } else { fileName }
        parts.add(MultipartPart(name, Some(actualName), Some(contentType), None,
            Some(File(path, OpenMode.Read))))
        this
    }

    public func fileStream(name: String, fileName: String, source: InputStream,
        contentType!: String = "application/octet-stream"): MultipartBody {
        parts.add(MultipartPart(name, Some(fileName), Some(contentType), None, Some(source)))
        this
    }

    public func partCount(): Int64 {
        parts.size
    }

    public func contentType(): String {
        "multipart/form-data; boundary=${boundary}"
    }

    /** 组装成完整的请求体字节。 */
    public func build(): Array<Byte> {
        let buffer = ByteBuffer()
        for (part in parts) {
            buffer.write("--${boundary}\r\n".toArray())
            var disposition = "Content-Disposition: form-data; name=\"${part.name}\""
            if (let Some(fileName) <- part.fileName) {
                disposition += "; filename=\"${fileName}\""
            }
            buffer.write("${disposition}\r\n".toArray())
            if (let Some(mediaType) <- part.contentType) {
                buffer.write("Content-Type: ${mediaType}\r\n".toArray())
            }
            buffer.write("\r\n".toArray())
            buffer.write(part.bytes())
            buffer.write("\r\n".toArray())
        }
        buffer.write("--${boundary}--\r\n".toArray())
        buffer.bytes()
    }
}

package linderHttp

/**
 * Multipart表单项类型
 */
public enum MultipartPart {
    | Text(String, String)        // name, value
    | File(String, String, Array<Byte>)  // name, filename, content
    | FileStream(String, String, InputStream)  // name, filename, stream

    /**
     * 获取字段名称
     */
    public func getName(): String {
        match (this) {
            case MultipartPart.Text(name, _) => name
            case MultipartPart.File(name, _, _) => name
            case MultipartPart.FileStream(name, _, _) => name
        }
    }

    /**
     * 获取字段值（仅文本字段有效）
     */
    public func getValue(): ?String {
        match (this) {
            case MultipartPart.Text(_, value) => Some(value)
            case _ => None
        }
    }

    /**
     * 获取文件名（仅文件字段有效）
     */
    public func getFilename(): ?String {
        match (this) {
            case MultipartPart.File(_, filename, _) => Some(filename)
            case MultipartPart.FileStream(_, filename, _) => Some(filename)
            case _ => None
        }
    }
}

/**
 * Multipart/form-data请求体
 * 用于构建multipart/form-data格式的HTTP请求体
 */
public class MultipartFormData {
    private var parts: ArrayList<MultipartPart> = ArrayList<MultipartPart>()
    private let boundary: String

    /**
     * 创建MultipartFormData实例
     * @param boundary 可选的分隔符，如果不提供则自动生成
     */
    public init(boundary!: String = "") {
        if (boundary == "") {
            let timestamp = DateTime.nowUTC().toUnixTimeStamp().toNanoseconds()
            let random = Random().nextUInt64()
            this.boundary = "----Boundary${timestamp}${random}"
        } else {
            this.boundary = boundary
        }
    }

    /**
     * 获取boundary分隔符
     */
    public func getBoundary(): String {
        boundary
    }

    /**
     * 添加文本字段
     * @param name 字段名
     * @param value 字段值
     * @return 当前对象（支持链式调用）
     */
    public func addText(name: String, value: String): MultipartFormData {
        parts.add(MultipartPart.Text(name, value))
        this
    }

    /**
     * 添加文件字段（字节数组）
     * @param name 字段名
     * @param filename 文件名
     * @param content 文件内容
     * @return 当前对象（支持链式调用）
     */
    public func addFile(name: String, filename: String, content: Array<Byte>): MultipartFormData {
        parts.add(MultipartPart.File(name, filename, content))
        this
    }

    /**
     * 添加文件字段（输入流）
     * @param name 字段名
     * @param filename 文件名
     * @param stream 文件输入流
     * @return 当前对象（支持链式调用）
     */
    public func addFileStream(name: String, filename: String, stream: InputStream): MultipartFormData {
        parts.add(MultipartPart.FileStream(name, filename, stream))
        this
    }

    /**
     * 获取所有part
     */
    public func getParts(): Array<MultipartPart> {
        parts.toArray()
    }

    /**
     * 清空所有part
     */
    public func clear(): Unit {
        parts.clear()
    }

    /**
     * 构建multipart/form-data格式的字节数组
     * @return 构建好的字节数组
     */
    public func build(): Array<Byte> {
        let result = ArrayList<Byte>()

        for (part in parts) {
            // 添加boundary分隔符
            result.add(all: "--${boundary}\r\n".toArray())

            match (part) {
                case MultipartPart.Text(name, value) =>
                    // 添加Content-Disposition
                    result.add(all: "Content-Disposition: form-data; name=\"${name}\"\r\n\r\n".toArray())
                    // 添加值
                    result.add(all: value.toArray())
                    result.add(all: "\r\n".toArray())

                case MultipartPart.File(name, filename, content) =>
                    // 添加Content-Disposition
                    result.add(all: "Content-Disposition: form-data; name=\"${name}\"; filename=\"${filename}\"\r\n".toArray())
                    // 添加Content-Type（默认为application/octet-stream）
                    result.add(all: "Content-Type: application/octet-stream\r\n\r\n".toArray())
                    // 添加文件内容
                    result.add(all: content)
                    result.add(all: "\r\n".toArray())

                case MultipartPart.FileStream(name, filename, stream) =>
                    // 添加Content-Disposition
                    result.add(all: "Content-Disposition: form-data; name=\"${name}\"; filename=\"${filename}\"\r\n".toArray())
                    // 添加Content-Type（默认为application/octet-stream）
                    result.add(all: "Content-Type: application/octet-stream\r\n\r\n".toArray())
                    // 读取流内容
                    let buffer = Array<Byte>(1024, repeat: 0)
                    var bytesRead = stream.read(buffer)
                    while (bytesRead > 0) {
                        result.add(all: buffer[0..bytesRead])
                        bytesRead = stream.read(buffer)
                    }
                    result.add(all: "\r\n".toArray())
            }
        }

        // 添加结束boundary
        result.add(all: "--${boundary}--\r\n".toArray())

        result.toArray()
    }

    /**
     * 获取Content-Type头部值
     * @return multipart/form-data; boundary=xxxxx
     */
    public func getContentType(): String {
        "multipart/form-data; boundary=${boundary}"
    }
}

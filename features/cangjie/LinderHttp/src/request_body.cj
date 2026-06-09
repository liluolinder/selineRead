package linderHttp


/**
 * HTTP请求体类型枚举
 * 
 * 支持多种请求体格式：
 * - 字符串
 * - 输入流
 * - 字节数组
 * - 数据模型对象
 * - JSON对象
 * - URL编码表单
 * - Multipart表单
 */
public enum RequestBody {
    | String(String)
    | InputStream(InputStream)
    | ByteArray(Array<Byte>)
    | Object(DataModel)
    | Json(JsonObject)
    | UrlEncoded(Form)
    | Multipart(MultipartFormData)

    public static func from(v: String): RequestBody {
        RequestBody.String(v)
    }

    public static func from(v: InputStream): RequestBody {
        RequestBody.InputStream(v)
    }

    public static func from(v: Array<Byte>): RequestBody {
        RequestBody.ByteArray(v)
    }

    public static func from(v: Form): RequestBody {
        RequestBody.UrlEncoded(v)
    }
    
    public static func from(v: DataModel): RequestBody {
        RequestBody.Object(v)
    }
    
    public static func from(v: JsonObject): RequestBody {
        RequestBody.Json(v)
    }

    public static func from(v: MultipartFormData): RequestBody {
        RequestBody.Multipart(v)
    }
}

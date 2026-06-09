package linderHttp


/**
 * HTTP便捷请求方法类
 * 
 * 提供类似axios风格的快捷请求方法，所有方法均为静态方法。
 * 
 * ## 使用示例
 * ```cangjie
 * // GET请求
 * let response = HttpQuick.get("https://api.example.com/data")
 * 
 * // POST请求
 * let response = HttpQuick.post("https://api.example.com/data", "{\"name\": \"test\"}")
 * ```
 */
public class HttpQuick {
    /**
     * 发送GET请求
     * @param url 请求URL
     * @return 响应对象
     */
    public static func get(url: String): LinderHttpResponse {
        LinderHttpClient(url: RequestUrl.from(url), method: RequestMethod.GET).send()
    }
    
    /**
     * 发送GET请求
     * @param url URL对象
     * @return 响应对象
     */
    public static func get(url: URL): LinderHttpResponse {
        LinderHttpClient(url: RequestUrl.from(url), method: RequestMethod.GET).send()
    }
    
    /**
     * 发送GET请求（带请求头）
     * @param url 请求URL
     * @param headers 请求头
     * @return 响应对象
     */
    public static func get(url: String, headers: HashMap<String, String>): LinderHttpResponse {
        LinderHttpClient(url: RequestUrl.from(url), method: RequestMethod.GET)
            .setHeader(headers)
            .send()
    }
    
    /**
     * 发送POST请求
     * @param url 请求URL
     * @param body 请求体
     * @return 响应对象
     */
    public static func post(url: String, body: String): LinderHttpResponse {
        LinderHttpClient(url: RequestUrl.from(url), method: RequestMethod.POST)
            .setBody(body)
            .send()
    }
    
    /**
     * 发送POST请求
     * @param url URL对象
     * @param body 请求体
     * @return 响应对象
     */
    public static func post(url: URL, body: String): LinderHttpResponse {
        LinderHttpClient(url: RequestUrl.from(url), method: RequestMethod.POST)
            .setBody(body)
            .send()
    }
    
    /**
     * 发送POST请求（JSON格式）
     * @param url 请求URL
     * @param body JSON对象
     * @return 响应对象
     */
    public static func post(url: String, body: JsonObject): LinderHttpResponse {
        LinderHttpClient(url: RequestUrl.from(url), method: RequestMethod.POST)
            .setBody(body)
            .send()
    }
    
    /**
     * 发送POST请求（表单格式）
     * @param url 请求URL
     * @param body 表单数据
     * @return 响应对象
     */
    public static func post(url: String, body: Form): LinderHttpResponse {
        LinderHttpClient(url: RequestUrl.from(url), method: RequestMethod.POST)
            .setBody(body)
            .send()
    }
    
    /**
     * 发送PUT请求
     * @param url 请求URL
     * @param body 请求体
     * @return 响应对象
     */
    public static func put(url: String, body: String): LinderHttpResponse {
        LinderHttpClient(url: RequestUrl.from(url), method: RequestMethod.PUT)
            .setBody(body)
            .send()
    }
    
    /**
     * 发送PUT请求（JSON格式）
     * @param url 请求URL
     * @param body JSON对象
     * @return 响应对象
     */
    public static func put(url: String, body: JsonObject): LinderHttpResponse {
        LinderHttpClient(url: RequestUrl.from(url), method: RequestMethod.PUT)
            .setBody(body)
            .send()
    }
    
    /**
     * 发送DELETE请求
     * @param url 请求URL
     * @return 响应对象
     */
    public static func delete(url: String): LinderHttpResponse {
        LinderHttpClient(url: RequestUrl.from(url), method: RequestMethod.DELETE).send()
    }
    
    /**
     * 发送DELETE请求
     * @param url URL对象
     * @return 响应对象
     */
    public static func delete(url: URL): LinderHttpResponse {
        LinderHttpClient(url: RequestUrl.from(url), method: RequestMethod.DELETE).send()
    }
    
    /**
     * 发送HEAD请求
     * @param url 请求URL
     * @return 响应对象
     */
    public static func head(url: String): LinderHttpResponse {
        LinderHttpClient(url: RequestUrl.from(url), method: RequestMethod.HEAD).send()
    }
    
    /**
     * 发送OPTIONS请求
     * @param url 请求URL
     * @return 响应对象
     */
    public static func options(url: String): LinderHttpResponse {
        LinderHttpClient(url: RequestUrl.from(url), method: RequestMethod.OPTIONS).send()
    }
    
    /**
     * 发送PATCH请求
     * @param url 请求URL
     * @param body 请求体
     * @return 响应对象
     */
    public static func patch(url: String, body: String): LinderHttpResponse {
        LinderHttpClient(url: RequestUrl.from(url), method: RequestMethod.PATCH)
            .setBody(body)
            .send()
    }
    
    /**
     * 发送PATCH请求（JSON格式）
     * @param url 请求URL
     * @param body JSON对象
     * @return 响应对象
     */
    public static func patch(url: String, body: JsonObject): LinderHttpResponse {
        LinderHttpClient(url: RequestUrl.from(url), method: RequestMethod.PATCH)
            .setBody(body)
            .send()
    }
}

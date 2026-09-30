package linderHttp.http

/**
 * 一行式全局入口。
 *
 * 设计取向对标 requests / axios 的模块级函数：不改任何配置、不建客户端，直接拿到结果。
 * 内部复用同一个全局 `HttpClient`（连接池、Cookie、重试策略都是共享的），
 * 因此「连续请求同一主机」同样是走长连接。
 *
 * ```cangjie
 * // 一行读文本
 * let text = LinderHttp.text("https://example.com/")
 * // 一行取 JSON
 * let value = LinderHttp.json("https://api.example.com/data")
 * // 一行下载
 * LinderHttp.download("https://example.com/big.zip", Path("./big.zip"))
 * ```
 *
 * 需要精细控制（超时、重试、连接池、拦截器、Cookie 隔离）时，改用
 * `HttpClientBuilder().build()` 建独立客户端，互不影响。
 */
public class LinderHttp {
    /** 全局共享客户端（可读连接池统计）。 */
    public static func client(): HttpClient {
        SharedClients.shared()
    }

    /** 关闭全局共享客户端并释放全部长连接。 */
    public static func shutdown(): Unit {
        SharedClients.shutdown()
    }

    /**
     * 设置全局配置（代理、超时、连接池……），并让共享客户端在下次请求时重建。
     *
     * 用途是"运行期改配置"：共享客户端建好之后代理就固定了，而用户改代理设置是真实需求。
     * 传入的是一份快照，之后改原对象不影响已生效的配置。
     *
     * ```cangjie
     * let config = ClientConfig()
     * config.httpsProxy = Some("http://127.0.0.1:7890")
     * LinderHttp.configure(config)
     * ```
     */
    public static func configure(config: ClientConfig): Unit {
        GlobalConfig.set(config)
        SharedClients.invalidate()
    }

    /** 当前的全局配置（没有显式设置过时为 None）。 */
    public static func configuration(): ?ClientConfig {
        GlobalConfig.current()
    }

    public static func get(url: String, headers!: ?Headers = None,
        timeouts!: ?Timeouts = None): Response {
        SharedClients.shared().get(url, headers: headers, timeouts: timeouts)
    }

    public static func head(url: String): Response {
        SharedClients.shared().head(url)
    }

    public static func options(url: String): Response {
        SharedClients.shared().options(url)
    }

    public static func delete(url: String): Response {
        SharedClients.shared().delete(url)
    }

    public static func post(url: String, body: String): Response {
        SharedClients.shared().post(url, body)
    }

    public static func post(url: String, body: JsonValue): Response {
        SharedClients.shared().post(url, body)
    }

    public static func post(url: String, body: JsonObject): Response {
        SharedClients.shared().post(url, body)
    }

    public static func post(url: String, body: HashMap<String, String>): Response {
        SharedClients.shared().post(url, body)
    }

    public static func post(url: String, body: Body): Response {
        SharedClients.shared().post(url, body)
    }

    public static func put(url: String, body: String): Response {
        SharedClients.shared().put(url, body)
    }

    public static func put(url: String, body: JsonObject): Response {
        SharedClients.shared().put(url, body)
    }

    public static func patch(url: String, body: JsonObject): Response {
        SharedClients.shared().patch(url, body)
    }

    /** 直接取文本。 */
    public static func text(url: String): String {
        get(url).text()
    }

    public static func json(url: String): JsonValue {
        get(url).json()
    }

    public static func jsonObject(url: String): JsonObject {
        get(url).jsonObject()
    }

    public static func dataModel(url: String): DataModel {
        get(url).dataModel()
    }

    public static func bytes(url: String): Array<Byte> {
        get(url).bytes()
    }

    /** 并发抓取多个 URL 的文本。 */
    public static func getAll(urls: Array<String>): Array<String> {
        let client = SharedClients.shared()
        let futures = ArrayList<Future<String>>()
        for (url in urls) {
            let captured = url
            futures.add(spawn {
                =>
                client.get(captured).text()
            })
        }
        let results = ArrayList<String>()
        for (future in futures) {
            results.add(future.get())
        }
        results.toArray()
    }
}

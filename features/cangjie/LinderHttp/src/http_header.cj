package linderHttp


/**
 * HTTP头部管理类
 * 
 * 提供HTTP请求头的设置、添加、删除和查询功能。
 * 
 * ## 功能特性
 * - 预置浏览器默认头部
 * - 支持链式调用
 * - 支持多值头部
 * 
 * ## 默认头部
 * - Sec-ch-ua: Chromium浏览器标识
 * - Sec-ch-ua-platform: Windows平台标识
 * - User-agent: Edge浏览器用户代理
 */
public class HttpHeader {
    /// 底层HTTP头存储容器（键值对集合）
    public var rawHeaders: HttpHeaders = HttpHeaders()

    /**
     * 初始化构造器
     *
     * 预置 浏览器头信息：
     * Sec-ch-ua: "Chromium";v="142", "Microsoft Edge";v="142", "Not_A Brand";v="99"
     * Sec-ch-ua-platform: "Windows"
     * User-agent: Mozilla/5.0 (Windows NT 10.0...)
     */
    public init() {
        this
            .add(key: "Sec-ch-ua", value: #""Chromium";v="142", "Microsoft Edge";v="142", "Not_A Brand";v="99""#)
            .add(key: "Sec-ch-ua-platform", value: "Windows")
            .add(key: "User-agent",
                value: "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36 Edg/143.0.0.0")
    }

    /**
     * 批量替换HTTP头
     *
     * @param v 新的HttpHeaders对象
     * @return 当前对象实例（支持链式调用）
     *
     * 注意：此操作将**完全覆盖**现有头信息
     */
    public func setAll(v: HttpHeaders): HttpHeader {
        rawHeaders = v
        this
    }

    /**
     * 设置单一头字段（覆盖模式）
     *
     * @param key 头字段名（如"Content-Type"）
     * @param value 头字段值（如"application/json"）
     * @return 当前对象实例（支持链式调用）
     *
     * 行为：若字段已存在则覆盖原有值
     */
    public func set(key!: String, value!: String): HttpHeader {
        rawHeaders.set(key, value)
        this
    }

    /**
     * 添加头字段
     *
     * @param key 头字段名（如"Accept"）
     * @param value 头字段值（如"text/html"）
     * @return 当前对象实例（支持链式调用）
     *
     * 行为：
     *   - 若字段不存在则创建
     *  - 若字段已经存在，将在其对应的值列表中添加 value
     */
    public func add(key!: String, value!: String): HttpHeader {
        rawHeaders.add(key, value)
        this
    }

    /**
     * 删除头字段
     *
     * @param key 要删除的字段名
     * @return 当前对象实例（支持链式调用）
     *
     * 说明：若字段不存在则无操作
     */
    public func delete(key!: String): HttpHeader {
        rawHeaders.del(key)
        this
    }

    /**
     * 获取头字段值集合
     *
     * @param key 头字段名
     * @return 值集合（可能为空集合）
     *
     * 特性：
     *   - 返回值为不可变集合
     *   - 多值头字段返回所有值
     */
    public func get(key: String): Collection<String> {
        rawHeaders.get(key)
    }

    /**
     * 获取头字段首个值
     *
     * @param key 头字段名
     * @return 字段的第一个值，不存在返回None
     *
     * 适用场景：单值头字段快速访问（如Content-Type）
     */
    public func getFirst(key: String): ?String {
        rawHeaders.getFirst(key)
    }

    /**
     * 检查头是否为空
     *
     * @return 当不含任何头字段时返回true
     */
    public func isEmpty(): Bool {
        rawHeaders.isEmpty()
    }

    public func printlnAll(): Unit {
        for (i in rawHeaders) {
            i[0] + " " + i[1].toArray().toString() |> println
        }
    }
}

package linderHttp

/**
 * HTTP拦截器
 *
 * 拦截器允许在HTTP请求生命周期的关键点插入自定义逻辑：
 * - 请求发送前：可以修改请求参数、添加头部等
 * - 请求失败时：可以处理错误、记录日志等
 * - 响应接收后：可以处理响应数据、记录日志等
 *
 * 使用示例：
 * ```cangjie
 * let intercept = Interceptor(
 *     onRequest: {http => println("发送请求: ${http.url}")},
 *     onError: {error, http => println("请求失败: ${error.message}")},
 *     onResponse: {res => println("收到响应: ${res.status}")}
 * )
 *
 * // 或者只注册需要的拦截器
 * let intercept = Interceptor(
 *     onRequest: {http => println("请求: ${http.url}")}
 * )
 * ```
 */
public class Interceptor {
    /**
     * 请求发送前拦截函数
     * 触发时机：HTTP请求参数组装完成，即将发起网络请求前
     *
     * 使用场景：
     * - 添加统一的请求头（如认证token）
     * - 记录请求日志
     * - 修改请求参数
     */
    public let onRequest: ?(LinderHttpClient) -> Unit

    /**
     * 请求失败拦截函数
     * 触发时机：请求构建或发送过程中抛出异常时
     *
     * 使用场景：
     * - 错误日志记录
     * - 错误上报
     * - 请求重试
     */
    public let onError: ?(Exception, LinderHttpClient) -> Unit

    /**
     * 响应接收后拦截函数
     * 触发时机：成功接收到HTTP响应后
     *
     * 使用场景：
     * - 响应日志记录
     * - 响应数据预处理
     * - 性能监控
     */
    public let onResponse: ?(LinderHttpResponse) -> Unit

    /**
     * 构造拦截器
     *
     * @param onRequest 请求前拦截函数，默认为None（不执行）
     * @param onError 错误拦截函数，默认为None（不执行）
     * @param onResponse 响应拦截函数，默认为None（不执行）
     *
     * 示例：
     * ```cangjie
     * let intercept = Interceptor(
     *     onRequest: {http => println("请求: ${http.url}")},
     *     onResponse: {res => println("响应: ${res.status}")}
     * )
     * ```
     */
    public init(
        onRequest!: ?(LinderHttpClient) -> Unit = None,
        onError!: ?(Exception, LinderHttpClient) -> Unit = None,
        onResponse!: ?(LinderHttpResponse) -> Unit = None
    ) {
        this.onRequest = onRequest
        this.onError = onError
        this.onResponse = onResponse
    }
}

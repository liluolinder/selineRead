package linderHttp

/**
 * HTTP Cookie管理类
 * 
 * 提供Cookie的存储、添加、删除和序列化功能。
 * 用于在HTTP请求中维护服务端设置的Cookie状态。
 * 
 * ## 使用示例
 * ```cangjie
 * let cookie = LinderHttpCookie()
 * cookie.add("sessionId", "abc123")
 * cookie.add("userId", "42")
 * println(cookie.toString())  // 输出: "sessionId=abc123; userId=42"
 * cookie.delete("userId")
 * ```
 */
public class LinderHttpCookie {
    /**
     * 底层Cookie存储容器
     * Key: Cookie名称, Value: Cookie值
     */
    private var cookies: HashMap<String, String> = HashMap<String, String>()

    /**
     * 添加Cookie键值对
     * @param key Cookie名称
     * @param value Cookie值
     * @return 当前对象（支持链式调用）
     */
    public func add(key: String, value: String): LinderHttpCookie {
        cookies[key] = value
        this
    }

    /**
     * 删除指定名称的Cookie
     * @param key 要删除的Cookie名称
     * @return 当前对象（支持链式调用）
     */
    public func delete(key: String): LinderHttpCookie {
        cookies.remove(key)
        this
    }

    /**
     * 获取指定名称的Cookie值
     * @param key Cookie名称
     * @return Cookie值，不存在返回None
     */
    public func get(key: String): ?String {
        cookies.get(key)
    }

    /**
     * 获取所有Cookie名称集合
     * @return 所有Cookie名称的集合
     */
    public func keys(): HashSet<String> {
        let result = HashSet<String>()
        for ((k, _) in cookies) {
            result.add(k)
        }
        result
    }

    /**
     * 判断是否包含指定名称的Cookie
     * @param key Cookie名称
     * @return 存在返回true
     */
    public func contains(key: String): Bool {
        !cookies.get(key).isNone()
    }

    /**
     * 获取Cookie数量
     * @return Cookie的数量
     */
    public func size(): Int64 {
        var count: Int64 = 0
        for ((_, _) in cookies) {
            count++
        }
        count
    }

    /**
     * 清空所有Cookie
     * @return 当前对象（支持链式调用）
     */
    public func clear(): LinderHttpCookie {
        cookies.clear()
        this
    }

    /**
     * 将Cookie列表转换为HTTP Cookie请求头格式的字符串
     * 格式：name1=value1; name2=value2
     * 
     * @return Cookie字符串，无Cookie时返回空字符串
     */
    public func toString(): String {
        if (cookies.isEmpty()) {
            return ''
        }
        var result = ''
        var first = true
        for ((key, value) in cookies) {
            if (!first) {
                result = result + '; '
            }
            result = result + key + '=' + value
            first = false
        }
        result
    }

    /**
     * 从Cookie字符串解析并填充当前对象
     * 支持格式：name1=value1; name2=value2
     * 已存在的同名Cookie会被覆盖，其余保留
     * 
     * @param cookieStr Cookie字符串
     * @return 当前对象（支持链式调用）
     */
    public static func fromString(cookieStr: String): LinderHttpCookie {
        var cookie = LinderHttpCookie()
        if (cookieStr.isEmpty()) {
            return cookie
        }
        let pairs = cookieStr.split("; ")
        for (pair in pairs) {
            let eqIdx = pair.indexOf('=')
            if (!eqIdx.isNone() && eqIdx.getOrThrow() > 0) {
                let pos = eqIdx.getOrThrow()
                let name = pair[0..pos]
                let value = pair[(pos + 1)..]
                cookie.cookies[name] = value
            }
        }
        cookie
    }
}

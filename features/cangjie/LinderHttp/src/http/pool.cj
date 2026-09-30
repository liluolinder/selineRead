package linderHttp.http

/**
 * 连接池运行状态快照。
 */
public class PoolStats <: ToString {
    /** 当前持有的 host 连接组数量 */
    public let hostGroups: Int64
    /** 正在处理中的请求数（含尚未落地的响应体） */
    public let activeRequests: Int64
    /** 正在流式消费中的响应体数量 */
    public let openStreams: Int64
    /** 累计请求数 */
    public let totalRequests: Int64
    /** 累计新建的连接组数量（每次新建都意味着至少一次 TCP/TLS 握手） */
    public let createdGroups: Int64
    /** 累计命中已有连接组的次数（长连接复用证据） */
    public let reusedGroups: Int64
    /** 累计回收的连接组数量 */
    public let evictedGroups: Int64
    /** 累计重试次数 */
    public let retries: Int64

    public init(hostGroups: Int64, activeRequests: Int64, openStreams: Int64, totalRequests: Int64,
        createdGroups: Int64, reusedGroups: Int64, evictedGroups: Int64, retries: Int64) {
        this.hostGroups = hostGroups
        this.activeRequests = activeRequests
        this.openStreams = openStreams
        this.totalRequests = totalRequests
        this.createdGroups = createdGroups
        this.reusedGroups = reusedGroups
        this.evictedGroups = evictedGroups
        this.retries = retries
    }

    /** 复用率：命中 / 总请求。 */
    public func reuseRate(): Float64 {
        if (totalRequests == 0) {
            return 0.0
        }
        Float64(reusedGroups) / Float64(totalRequests)
    }

    public func toString(): String {
        "PoolStats(hosts=${hostGroups}, active=${activeRequests}, streams=${openStreams}, requests=${totalRequests}, created=${createdGroups}, reused=${reusedGroups}, evicted=${evictedGroups}, retries=${retries})"
    }
}

/**
 * 一个 host 对应的连接组。
 *
 * 一个 stdx `Client` 内部自带「同 host:port 的连接池」，所以本库对每个 host 只持有一个
 * `Client`，由它负责真正的长连接复用；本类只做上层的并发计数与生命周期管理。
 */
internal class HostConnection {
    let key: String
    let host: String
    let client: Client
    /** 正在处理中的请求 */
    var active: Int64 = 0
    /** 已被转成流式租约的响应体（槽位仍然占用） */
    var leases: Int64 = 0
    var leaseSince: ?DateTime = None
    var requests: Int64 = 0
    var lastUsed: DateTime
    var closed: Bool = false
    /** 连续传输层失败次数 */
    var consecutiveFailures: Int64 = 0
    /** 熔断截止时间；None 表示未熔断 */
    var openUntil: ?DateTime = None

    init(key: String, host: String, client: Client, now: DateTime) {
        this.key = key
        this.host = host
        this.client = client
        this.lastUsed = now
    }
}

/**
 * 一次借用的凭证。
 *
 * 通过状态机保证「只会归还一次」：请求正常结束调用 `finish()`，
 * 流式响应体则先 `toLease()`、读完再 `endLease()`。
 */
internal class PooledSlot {
    internal let key: String
    internal let host: String
    internal let client: Client
    internal let entry: HostConnection
    private let pool: ConnectionPool
    private var state: Int64 = 0
    private var released: Bool = false

    internal init(key: String, host: String, client: Client, entry: HostConnection,
        pool: ConnectionPool) {
        this.key = key
        this.host = host
        this.client = client
        this.entry = entry
        this.pool = pool
    }

    /** 请求结束（响应体已经落地到内存）。 */
    internal func finish(): Unit {
        if (state == 0 && !released) {
            released = true
            state = 2
            pool.finishRequest(this)
        }
    }

    /** 转成流式租约：槽位继续被占用到流读完。 */
    internal func toLease(): Unit {
        if (state == 0 && !released) {
            state = 1
            pool.toStreamLease(this)
        }
    }

    /** 流式响应体读完（或放弃）。 */
    internal func endLease(): Unit {
        if (state == 1 && !released) {
            released = true
            state = 2
            pool.endStreamLease(this)
        }
    }

}

/**
 * 连接池：每 host 一个连接组 + 每 host 并发闸门 + 空闲回收。
 *
 * 为什么需要并发闸门：stdx 在「同 server 并发数 > poolSize」时会直接抛
 * `HttpException: Too many connections to the same server!`（实测 poolSize=2、8 并发时 6 个失败）。
 * 本库把 `poolSize` 设为 `maxConnectionsPerHost`，并在上层用同一数值做闸门：
 * 超出并发就在闸门前排队，等到有槽位或等到 `acquireTimeout` 超时，得到的是可预期的等待，
 * 而不是随机失败。
 */
internal class ConnectionPool {
    private let mutex: Mutex = Mutex()
    private let cond: Condition
    private let options: PoolOptions
    private let capacity: Int64
    private let factory: (String, String) -> Client
    private let listener: ?EventListener
    private let health: HealthPolicy
    private let groups: HashMap<String, HostConnection> = HashMap<String, HostConnection>()
    private var totalRequests: Int64 = 0
    private var totalRetries: Int64 = 0
    private var createdGroups: Int64 = 0
    private var reusedGroups: Int64 = 0
    private var evictedGroups: Int64 = 0
    private var isClosed: Bool = false

    internal init(options: PoolOptions, factory: (String, String) -> Client,
        listener: ?EventListener, health: HealthPolicy) {
        this.options = options
        this.capacity = if (options.maxConnectionsPerHost < 1) {
            1
        } else {
            options.maxConnectionsPerHost
        }
        this.factory = factory
        this.listener = listener
        this.health = health
        synchronized(mutex) {
            cond = mutex.condition()
        }
    }

    /**
     * 借一个槽位。必要时新建该 host 的连接组；并发已满则等待。
     *
     * @throws HttpError(kind = PoolBusy) 等待超过 acquireTimeout
     * @throws HttpError(kind = Closed) 客户端已关闭
     */
    internal func acquire(key: String, host: String, waitLimit!: ?Duration = None): PooledSlot {
        let events = ArrayList<(Int64, String)>()
        let slot = synchronized(mutex) {
            if (isClosed) {
                throw HttpError(ErrorKind.Closed, "HttpClient 已关闭，无法继续发送请求", url: key)
            }
            maintainLocked(events)
            var entry = obtainLocked(key, host, events)
            var waitFor = options.acquireTimeout
            match (waitLimit) {
                case Some(limit) => if (limit < waitFor) {
                    waitFor = limit
                }
                case None => ()
            }
            let deadline = DateTime.now() + waitFor
            while (entry.active + entry.leases >= capacity) {
                let remaining = deadline - DateTime.now()
                if (remaining <= Duration.millisecond * 0) {
                    throw HttpError(ErrorKind.PoolBusy,
                        "连接池繁忙：${host} 并发上限 ${capacity}，等待 ${waitFor} 仍未获得槽位",
                        url: key)
                }
                cond.wait(timeout: remaining)
                if (isClosed) {
                    throw HttpError(ErrorKind.Closed, "HttpClient 已关闭，无法继续发送请求", url: key)
                }
                maintainLocked(events)
                entry = obtainLocked(key, host, events)
            }
            checkBreakerLocked(entry)
            entry.active++
            entry.lastUsed = DateTime.now()
            entry.requests++
            totalRequests++
            PooledSlot(key, host, entry.client, entry, this)
        }
        for (event in events) {
            emit(event)
        }
        slot
    }

    /** 请求完成：释放槽位。 */
    internal func finishRequest(slot: PooledSlot): Unit {
        synchronized(mutex) {
            if (slot.entry.active > 0) {
                slot.entry.active--
            }
            slot.entry.lastUsed = DateTime.now()
            cond.notifyAll()
        }
    }

    /** 转成流式租约：释放请求计数但继续占用槽位。 */
    internal func toStreamLease(slot: PooledSlot): Unit {
        synchronized(mutex) {
            if (slot.entry.active > 0) {
                slot.entry.active--
            }
            slot.entry.leases++
            if (slot.entry.leaseSince.isNone()) {
                slot.entry.leaseSince = Some(DateTime.now())
            }
            slot.entry.lastUsed = DateTime.now()
            cond.notifyAll()
        }
    }

    /** 流式响应体结束：释放租约。 */
    internal func endStreamLease(slot: PooledSlot): Unit {
        synchronized(mutex) {
            if (slot.entry.leases > 0) {
                slot.entry.leases--
            }
            if (slot.entry.leases == 0) {
                slot.entry.leaseSince = None
            }
            slot.entry.lastUsed = DateTime.now()
            cond.notifyAll()
        }
    }

    // ---------- 熔断 ----------

    /** 冷却期内的请求快速失败；冷却结束后放行一次探测。 */
    private func checkBreakerLocked(entry: HostConnection): Unit {
        if (!health.enabled) {
            return
        }
        if (let Some(deadline) <- entry.openUntil) {
            if (DateTime.now() < deadline) {
                throw HttpError(ErrorKind.CircuitOpen,
                    "目标已熔断：${entry.host} 连续 ${entry.consecutiveFailures} 次传输失败，冷却至 ${deadline}",
                    url: entry.key)
            }
            // 冷却结束：放行一次探测，计数清零，失败后重新累积
            entry.openUntil = None
            entry.consecutiveFailures = 0
        }
    }

    /** 传输层成功：清空失败计数并解除熔断。 */
    internal func noteSuccess(slot: PooledSlot): Unit {
        if (!health.enabled) {
            return
        }
        synchronized(mutex) {
            slot.entry.consecutiveFailures = 0
            slot.entry.openUntil = None
        }
    }

    /** 传输层失败：累加失败计数，达到阈值即熔断。 */
    internal func noteFailure(slot: PooledSlot): Unit {
        if (!health.enabled) {
            return
        }
        synchronized(mutex) {
            slot.entry.consecutiveFailures++
            if (slot.entry.consecutiveFailures >= health.failureThreshold) {
                slot.entry.openUntil = Some(DateTime.now() + health.cooldown)
            }
        }
    }

    internal func noteRetry(): Unit {
        synchronized(mutex) {
            totalRetries++
        }
    }

    /**
     * 只关闭空闲连接组；仍有请求在跑或仍有流式租约的组会跳过。
     * 返回被关闭的组数量。
     */
    internal func closeIdle(): Int64 {
        let events = ArrayList<(Int64, String)>()
        var count = 0
        synchronized(mutex) {
            let candidates = ArrayList<String>()
            for ((key, entry) in groups) {
                if (entry.active == 0 && entry.leases == 0) {
                    candidates.add(key)
                }
            }
            for (key in candidates) {
                removeLocked(key, events)
                count++
            }
        }
        for (event in events) {
            emit(event)
        }
        count
    }

    internal func stats(): PoolStats {
        synchronized(mutex) {
            var active = 0
            var leases = 0
            for ((_, entry) in groups) {
                active += entry.active
                leases += entry.leases
            }
            PoolStats(groups.size, active, leases, totalRequests, createdGroups, reusedGroups,
                evictedGroups, totalRetries)
        }
    }

    /** 关闭全部连接。调用前应确保没有在途请求。 */
    internal func close(): Unit {
        let events = ArrayList<(Int64, String)>()
        synchronized(mutex) {
            isClosed = true
            let keys = ArrayList<String>()
            for ((key, _) in groups) {
                keys.add(key)
            }
            for (key in keys) {
                removeLocked(key, events)
            }
            cond.notifyAll()
        }
        for (event in events) {
            emit(event)
        }
    }

    // ---------- 以下方法必须在持锁状态下调用 ----------

    private func obtainLocked(key: String, host: String,
        events: ArrayList<(Int64, String)>): HostConnection {
        if (let Some(existing) <- groups.get(key)) {
            if (!existing.closed) {
                // 之前已有过请求、且当前完全空闲 —— 本次极可能直接复用已有长连接
                if (existing.active == 0 && existing.leases == 0 && existing.requests > 0) {
                    reusedGroups++
                    events.add((1, key))
                }
                return existing
            }
        }
        if (groups.size >= options.maxHosts) {
            if (!evictLruIdleLocked(events)) {
                throw HttpError(ErrorKind.PoolBusy,
                    "连接池 host 数已达上限 ${options.maxHosts}，且没有空闲连接组可回收", url: key)
            }
        }
        let client = factory(key, host)
        let entry = HostConnection(key, host, client, DateTime.now())
        groups[key] = entry
        createdGroups++
        events.add((0, key))
        entry
    }

    private func evictLruIdleLocked(events: ArrayList<(Int64, String)>): Bool {
        var victimKey = ""
        var victimAt: ?DateTime = None
        for ((key, entry) in groups) {
            if (entry.active == 0 && entry.leases == 0) {
                match (victimAt) {
                    case Some(current) =>
                        if (entry.lastUsed < current) {
                            victimKey = key
                            victimAt = Some(entry.lastUsed)
                        }
                    case None =>
                        victimKey = key
                        victimAt = Some(entry.lastUsed)
                }
            }
        }
        if (victimAt.isNone()) {
            return false
        }
        removeLocked(victimKey, events)
        true
    }

    /**
     * 回收两类连接组：
     * 1. 空闲超时（idleTimeout）；
     * 2. 流式租约超时（liveLeaseTimeout）—— 调用方忘记读完响应体时的兜底，
     *    此时直接关掉整个连接组，避免 stdx 侧连接被永久占住。
     */
    private func maintainLocked(events: ArrayList<(Int64, String)>): Unit {
        let now = DateTime.now()
        let stale = ArrayList<String>()
        for ((key, entry) in groups) {
            if (entry.active == 0 && entry.leases == 0) {
                if (now - entry.lastUsed > options.idleTimeout) {
                    stale.add(key)
                }
            } else if (entry.active == 0 && entry.leases > 0) {
                match (entry.leaseSince) {
                    case Some(since) =>
                        if (now - since > options.liveLeaseTimeout) {
                            stale.add(key)
                        }
                    case None => ()
                }
            }
        }
        for (key in stale) {
            removeLocked(key, events)
        }
    }

    private func removeLocked(key: String, events: ArrayList<(Int64, String)>): Unit {
        match (groups.remove(key)) {
            case Some(entry) =>
                entry.closed = true
                entry.client.close()
                evictedGroups++
                events.add((2, key))
            case None => ()
        }
    }

    private func emit(event: (Int64, String)): Unit {
        match (listener) {
            case Some(handler) =>
                match (event[0]) {
                    case 0 => handler.connectionCreated(event[1])
                    case 1 => handler.connectionReused(event[1])
                    case 2 => handler.connectionEvicted(event[1])
                    case _ => ()
                }
            case None => ()
        }
    }
}

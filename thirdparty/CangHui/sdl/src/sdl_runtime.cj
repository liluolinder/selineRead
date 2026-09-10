package sdl

/** Process-wide SDL lifecycle. All leases and event polling stay on the first native thread. */
public class SdlRuntime <: Resource {
    // 可重绑：调度器可能迁移运行 run 循环的绿色线程（见 pollEvent）
    private var ownerThreadId: UInt64
    private var closed: Bool = false

    public init() {
        ownerThreadId = unsafe { SDL_GetCurrentThreadID() }
        acquireSdlRuntime(ownerThreadId)
    }

    public func pollEvent(): ?SdlEventEnvelope {
        let current = unsafe { SDL_GetCurrentThreadID() }
        if (!sameNativeThread(ownerThreadId, current)) {
            // Windows 上 SDL_PollEvent 只要求单线程串行，重绑而不是抛异常
            ownerThreadId = current
        }
        if (closed) { throw IllegalStateException("cannot poll a closed SDL runtime") }
        var raw = SdlEvent()
        if (!unsafe { SDL_PollEvent(inout raw) }) { return None }
        let decoded = decodeEventEnvelope(raw)
        Some(SdlEventEnvelope(decoded.windowId, enrichSharedGamepad(decoded.event)))
    }

    public func isClosed(): Bool { closed }

    public func close(): Unit {
        if (closed) { return }
        ensureSdlRuntimeOwner(ownerThreadId)
        closed = true
        releaseSdlRuntime(ownerThreadId)
    }
}

private let sharedSdlRuntimeGate = SdlRuntimeGate()
private var sdlRuntimeGamepads: ?GamepadRuntime = None

private func acquireSdlRuntime(ownerThreadId: UInt64): Unit {
    if (!sharedSdlRuntimeGate.ownerAllows(ownerThreadId)) {
        throw CuiException("SDL runtime leases must remain on their first native thread")
    }
    let acquired = sharedSdlRuntimeGate.acquire(ownerThreadId, { =>
        let initialized = unsafe { SDL_Init(SDL_INIT_VIDEO) }
        if (initialized) { sdlRuntimeGamepads = Some(GamepadRuntime()) }
        initialized
    })
    if (!acquired) {
        throw CuiException("SDL_Init failed: ${lastSdlError()}")
    }
}

private func releaseSdlRuntime(ownerThreadId: UInt64): Unit {
    let released = sharedSdlRuntimeGate.release(ownerThreadId, { =>
        match (sdlRuntimeGamepads) {
            case Some(runtime) => runtime.close()
            case None => ()
        }
        sdlRuntimeGamepads = None
        unsafe { SDL_Quit() }
    })
    if (!released) {
        throw IllegalStateException("SDL runtime lease accounting rejected release")
    }
}

private func enrichSharedGamepad(event: UiEvent): UiEvent {
    match (sdlRuntimeGamepads) {
        case Some(runtime) => runtime.enrich(event)
        case None => event
    }
}

private func ensureSdlRuntimeOwner(expected: UInt64): Unit {
    let current = unsafe { SDL_GetCurrentThreadID() }
    if (!sameNativeThread(expected, current)) {
        throw CuiException("SDL runtime polling and first close must run on its owner native thread")
    }
}

/** Native-free state machine used to prove first-start/last-stop refcount semantics. */
internal class SdlRuntimeGate {
    private var owner: UInt64 = UInt64(0)
    private var references: Int64 = 0

    func acquire(ownerThreadId: UInt64, start: () -> Bool): Bool {
        if (references > 0) {
            if (owner != ownerThreadId) { return false }
            references += 1
            return true
        }
        if (!start()) { return false }
        owner = ownerThreadId
        references = 1
        true
    }

    func release(ownerThreadId: UInt64, stop: () -> Unit): Bool {
        if (references == 0 || owner != ownerThreadId) { return false }
        references -= 1
        if (references == 0) {
            owner = UInt64(0)
            stop()
        }
        true
    }

    func referenceCount(): Int64 { references }

    func ownerAllows(ownerThreadId: UInt64): Bool {
        references == 0 || owner == ownerThreadId
    }
}

package chui.kmode

@When[debug]
import std.env.{getStdIn, getStdOut}

@When[debug]
public func runKModeStdio(policy!: KModePolicy = KModePolicy()): Int64 {
    if (!policy.enabled) {
        return 2
    }
    let input = getStdIn()
    let output = getStdOut()
    var running = true
    while (running) {
        match (input.readln()) {
            case Some(line) =>
                var requestId: Int64 = 0
                var shouldStop = false
                let response = try {
                    let request = decodeKModeRequest(line)
                    requestId = request.id
                    shouldStop = request.operation == KModeOperation.Shutdown
                    dispatchKModeRequest(request, policy: policy)
                } catch (error: Exception) {
                    KModeResponse(
                        requestId,
                        false,
                        "protocol-error",
                        errorCode: -32700,
                        errorMessage: error.message
                    )
                }
                output.writeln(encodeKModeResponse(response))
                output.flush()
                if (shouldStop && response.ok) {
                    running = false
                }
            case None => running = false
        }
    }
    0
}

@When[!debug]
public func runKModeStdio(policy!: KModePolicy = KModePolicy()): Int64 {
    if (policy.enabled) { () }
    2
}

/** Call before constructing DesktopApp so the control plane stays headless. */
@When[debug]
public func runKModeStdioIfRequested(): Bool {
    if (!kModeEnabled() || !kModeStdioRequested()) {
        return false
    }
    _ = runKModeStdio()
    true
}

@When[!debug]
public func runKModeStdioIfRequested(): Bool {
    false
}

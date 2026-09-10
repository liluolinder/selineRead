package cuic

@When[debug]
import std.collection.{ArrayList, HashMap}
@When[debug]
import std.fs.{Directory, File, FileInfo, OpenMode, Path, canonicalize, exists, removeIfExists}
@When[debug]
import std.process.{ProcessRedirect, launch}

@When[debug]
let FRAME_TRACE_MAX_BYTES: Int64 = 512 * 1024
@When[debug]
let FRAME_TRACE_MAX_FRAMES: Int64 = 64
@When[debug]
let FRAME_SCENARIO_MAX_BYTES: Int64 = 64

@When[debug]
class FrameTraceSelection {
    let requested: String
    let scenario: String

    init(requested: String, scenario: String) {
        this.requested = requested
        this.scenario = scenario
    }
}

@When[debug]
class FrameReplaySelection {
    let tracePath: String
    let executor: String

    init(tracePath: String, executor: String) {
        this.tracePath = tracePath
        this.executor = executor
    }
}

@When[debug]
func frameCommand(args: Array<String>, start: Int64): Int64 {
    // The build gate deliberately precedes parsing and all filesystem access.
    requireDebugChannelBuild("cuic frame")
    if (start >= args.size) {
        throw CuicError("frame requires trace or replay")
    }
    let action = args[start]
    if (action == "trace") {
        return runFrameTrace(parseFrameTraceSelection(args, start + 1))
    }
    if (action == "replay") {
        return runFrameReplay(parseFrameReplaySelection(args, start + 1))
    }
    throw CuicError("unknown frame action '${action}'")
}

@When[!debug]
func frameCommand(_: Array<String>, _: Int64): Int64 {
    // Keep a stable release CLI surface, but do not retain or enter any privileged implementation.
    requireDebugChannelBuild("cuic frame")
    1
}

@When[debug]
func parseFrameTraceSelection(args: Array<String>, start: Int64): FrameTraceSelection {
    var requested = ""
    var scenario = ""
    var sawScenario = false
    var i = start
    while (i < args.size) {
        let value = args[i]
        if (value == "--scenario") {
            if (sawScenario) { throw CuicError("frame trace accepts one --scenario") }
            if (i + 1 >= args.size) { throw CuicError("--scenario requires a name") }
            scenario = args[i + 1]
            validateFrameScenario(scenario)
            sawScenario = true
            i += 2
            continue
        }
        if (startsWithText(value, "-")) {
            throw CuicError("unknown frame trace option '${value}'")
        }
        if (!requested.isEmpty()) { throw CuicError("frame trace accepts one project") }
        requested = value
        i += 1
    }
    if (requested.isEmpty()) { throw CuicError("frame trace requires a project") }
    if (!sawScenario) { throw CuicError("frame trace requires --scenario <name>") }
    FrameTraceSelection(requested, scenario)
}

@When[debug]
func parseFrameReplaySelection(args: Array<String>, start: Int64): FrameReplaySelection {
    var tracePath = ""
    var executor = ""
    var sawExecutor = false
    var i = start
    while (i < args.size) {
        let value = args[i]
        if (value == "--executor") {
            if (sawExecutor) { throw CuicError("frame replay accepts one --executor") }
            if (i + 1 >= args.size) { throw CuicError("--executor requires null") }
            executor = args[i + 1]
            sawExecutor = true
            i += 2
            continue
        }
        if (startsWithText(value, "-")) {
            throw CuicError("unknown frame replay option '${value}'")
        }
        if (!tracePath.isEmpty()) { throw CuicError("frame replay accepts one trace file") }
        tracePath = value
        i += 1
    }
    if (tracePath.isEmpty()) { throw CuicError("frame replay requires a trace file") }
    if (!sawExecutor) { throw CuicError("frame replay requires --executor null") }
    if (executor != "null") { throw CuicError("frame replay rev1 only supports --executor null") }
    FrameReplaySelection(tracePath, executor)
}

@When[debug]
func validateFrameScenario(value: String): Unit {
    let bytes = value.toArray()
    if (bytes.isEmpty()) { throw CuicError("frame scenario must not be empty") }
    if (bytes.size > FRAME_SCENARIO_MAX_BYTES) {
        throw CuicError("frame scenario must not exceed ${FRAME_SCENARIO_MAX_BYTES} bytes")
    }
    let runes = value.toRuneArray()
    if (!isFrameScenarioLetter(runes[0])) {
        throw CuicError("frame scenario must start with an ASCII letter")
    }
    for (r in runes) {
        let allowed = isFrameScenarioLetter(r) || (r >= r'0' && r <= r'9') ||
            r == r'.' || r == r'-' || r == r'_'
        if (!allowed) {
            throw CuicError("frame scenario accepts only ASCII letters, digits, '.', '-' and '_'")
        }
    }
}

@When[debug]
func isFrameScenarioLetter(value: Rune): Bool {
    (value >= r'a' && value <= r'z') || (value >= r'A' && value <= r'Z')
}

@When[debug]
func frameTraceOutputPath(context: ExecutionContext, scenario: String): String {
    validateFrameScenario(scenario)
    joinPath(context.targetDir, "cuic/frame-traces/${scenario}.json")
}

@When[debug]
func runFrameTrace(selection: FrameTraceSelection): Int64 {
    let project = resolveProject(selection.requested, "")
    let framework = ensureFrameworkRoot(project)
    let context = ExecutionContext(project, framework)
    let boot = bootstrap(hostPlatform(), framework, stagingRoot: context.stagingRoot)
    if (boot != 0) { return boot }
    let output = frameTraceOutputPath(context, selection.scenario)
    let lease = context.acquireLease()
    try {
        ensureFrameTraceOutputDirectory(context)
        if (exists(output) && FileInfo(output).isSymbolicLink()) {
            throw CuicError("frame trace output must not be a symbolic link: ${output}")
        }
        removeIfExists(output)
        println("==> building ${basename(project)} (debug frame trace)")
        let buildCode = executeCjpm(context, ["build", "-g"])
        if (buildCode != 0) { return buildCode }
        let executable = debugUiExecutable(context.targetDir)
        let environment = frameTraceEnvironment(framework, output, selection.scenario)
        let process = launch(
            executable,
            [],
            workingDirectory: Path(project),
            environment: environment,
            stdIn: ProcessRedirect.Discard,
            stdOut: ProcessRedirect.Inherit,
            stdErr: ProcessRedirect.Inherit
        )
        let exitCode = process.wait()
        if (exitCode != 0) { return exitCode }
    } finally {
        context.releaseLease(lease)
    }
    if (!exists(output)) {
        throw CuicError("debug child exited without producing a frame trace")
    }
    // A child exit and a JSON-looking file are not acceptance evidence. Reuse the
    // frozen offline verifier so trace and replay fail closed on the same schema.
    validateFrameTraceEnvelope(readBoundedFrameTrace(output))
    println("frame trace: ${output}")
    0
}

@When[debug]
func ensureFrameTraceOutputDirectory(context: ExecutionContext): Unit {
    let cuicDirectory = joinPath(context.targetDir, "cuic")
    let traceDirectory = joinPath(cuicDirectory, "frame-traces")
    ensureFrameTraceDirectory(context.targetDir)
    ensureFrameTraceDirectory(cuicDirectory)
    ensureFrameTraceDirectory(traceDirectory)
}

@When[debug]
func ensureFrameTraceDirectory(path: String): Unit {
    if (exists(path)) {
        let info = FileInfo(path)
        if (info.isSymbolicLink()) {
            throw CuicError("frame trace directory must not be a symbolic link: ${path}")
        }
        if (!info.isDirectory()) {
            throw CuicError("frame trace directory is not a directory: ${path}")
        }
        return
    }
    Directory.create(path)
}

@When[debug]
func frameTraceEnvironment(framework: String, output: String, scenario: String): HashMap<String, String> {
    validateFrameScenario(scenario)
    let environment = applicationEnvironment(framework, "", UInt64(0))
    environment.add("CANGHUI_FRAME_TRACE_PATH", output)
    environment.add("CANGHUI_FRAME_TRACE_SCENARIO", scenario)
    environment.add("CANGHUI_FRAME_TRACE_MAX_FRAMES", FRAME_TRACE_MAX_FRAMES.toString())
    environment
}

@When[debug]
func runFrameReplay(selection: FrameReplaySelection): Int64 {
    if (selection.executor != "null") {
        throw CuicError("frame replay rev1 only supports --executor null")
    }
    let trace = readBoundedFrameTrace(selection.tracePath)
    println(verifyCompiledFrameTraceReceipt(trace))
    0
}

@When[debug]
func readBoundedFrameTrace(requested: String): String {
    if (requested.isEmpty()) { throw CuicError("frame replay requires a trace file") }
    let normalized = Path(requested).normalize().toString()
    if (!exists(normalized)) { throw CuicError("frame trace does not exist: ${requested}") }
    if (FileInfo(normalized).isSymbolicLink()) {
        throw CuicError("frame trace must not be a symbolic link: ${requested}")
    }
    let resolved = try {
        canonicalize(normalized).toString()
    } catch (_: Exception) {
        throw CuicError("frame trace path cannot be resolved: ${requested}")
    }
    let bytes = ArrayList<UInt8>()
    try {
        let input = File(resolved, OpenMode.Read)
        try {
            let buffer = Array<UInt8>(65536, repeat: UInt8(0))
            while (true) {
                let count = input.read(buffer)
                if (count <= 0) { break }
                if (bytes.size + count > FRAME_TRACE_MAX_BYTES) {
                    throw CuicError("frame trace exceeds ${FRAME_TRACE_MAX_BYTES} bytes")
                }
                for (i in 0..count) { bytes.add(buffer[i]) }
            }
        } finally {
            input.close()
        }
    } catch (error: CuicError) {
        throw error
    } catch (_: Exception) {
        throw CuicError("frame trace is not a readable regular file: ${requested}")
    }
    try {
        String.fromUtf8(bytes.toArray())
    } catch (_: Exception) {
        throw CuicError("frame trace must contain valid UTF-8")
    }
}

@When[debug]
func validateFrameTraceEnvelope(trace: String): Unit {
    let _ = verifyCompiledFrameTraceReceipt(trace)
}

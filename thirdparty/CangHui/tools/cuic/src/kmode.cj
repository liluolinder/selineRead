package cuic

import std.collection.{ArrayList, HashMap}
import std.convert.*
import std.env.getVariables
import std.fs.{Directory, File, Path, exists}
import std.io.{InputStream, OutputStream, StringReader, StringWriter}
import std.process.{ProcessRedirect, SubProcess, launch}

let CUIC_KMODE_PROTOCOL = "canghui.kmode.v0"

class KModeLinkLocation {
    let endpoint: String
    let path: String
    let line: Int64

    init(endpoint: String, path: String, line: Int64) {
        this.endpoint = endpoint
        this.path = path
        this.line = line
    }
}

class ProbeLinkLocation {
    let endpoint: String
    let path: String
    let line: Int64

    init(endpoint: String, path: String, line: Int64) {
        this.endpoint = endpoint
        this.path = path
        this.line = line
    }
}

class CuicKModeResponse {
    let id: Int64
    let ok: Bool
    let status: String
    let payload: String
    let errorCode: Int64
    let errorMessage: String

    init(id: Int64, ok: Bool, status: String, payload: String, errorCode: Int64, errorMessage: String) {
        this.id = id
        this.ok = ok
        this.status = status
        this.payload = payload
        this.errorCode = errorCode
        this.errorMessage = errorMessage
    }
}

class CuicKModeSession {
    private let process: SubProcess
    private let reader: StringReader<InputStream>
    private let writer: StringWriter<OutputStream>
    private var nextRequestId: Int64 = 1
    private var closed = false

    init(project: String, framework: String) {
        requireDebugChannelBuild("cuic kMode/probe runtime")
        let environment = kModeChildEnvironment(framework)
        this.process = launch(
            "cjpm",
            ["run", "-g"],
            workingDirectory: Path(project),
            environment: environment,
            stdIn: ProcessRedirect.Pipe,
            stdOut: ProcessRedirect.Pipe,
            stdErr: ProcessRedirect.Inherit
        )
        this.reader = StringReader<InputStream>(process.stdOutPipe)
        this.writer = StringWriter<OutputStream>(process.stdInPipe)
    }

    func exchange(operation: String, endpoint!: String = "", payload!: String = ""): CuicKModeResponse {
        if (closed) { throw CuicError("kMode session is closed") }
        let requestId = nextRequestId
        nextRequestId += 1
        writer.write(encodeCuicKModeRequest(requestId, operation, endpoint, payload))
        writer.write("\n")
        writer.flush()
        let line = readFrame()
        let response = decodeCuicKModeResponse(line)
        if (response.id != requestId) {
            throw CuicError("kMode response id mismatch")
        }
        response
    }

    func close(): Int64 {
        if (closed) { return 0 }
        closed = true
        try {
            let requestId = nextRequestId
            writer.write(encodeCuicKModeRequest(requestId, "shutdown", "", ""))
            writer.write("\n")
            writer.flush()
            try {
                let response = decodeCuicKModeResponse(readFrame())
                if (response.id != requestId || !response.ok) {
                    process.terminate(force: true)
                }
            } catch (_: Exception) {
                process.terminate(force: true)
            }
        } catch (_: Exception) {
            process.terminate(force: true)
        }
        process.wait()
    }

    private func readFrame(): String {
        while (true) {
            match (reader.readln()) {
                case Some(line) =>
                    if (startsWithText(line, CUIC_KMODE_PROTOCOL + "|")) {
                        return line
                    }
                    if (!isKModeLauncherNoise(line)) {
                        throw CuicError("unexpected stdout before kMode response: ${line}")
                    }
                case None => throw CuicError("kMode process closed before responding")
            }
        }
        throw CuicError("kMode response loop ended unexpectedly")
    }

    func abort(): Unit {
        if (!closed) {
            closed = true
            process.terminate(force: true)
            let _ = process.wait()
        }
    }
}

func isKModeLauncherNoise(line: String): Bool {
    line.isEmpty() || startsWithText(line, "cjpm ") ||
        startsWithText(line, "Warning: the functionality of 'CJPM_CONFIG' will be deprecated") ||
        startsWithText(line, "Warning: field 'profile.build.combined' in '") ||
        startsWithText(line, "Warning: field 'profile.build.combined' only supports") ||
        isCjpmEmptyPackageWarning(line)
}

func isCjpmEmptyPackageWarning(line: String): Bool {
    let prefix = "Warning: there is no '.cj' file in directory '"
    let suffix = "', and its subdirectories will not be scanned as source code"
    line.size > prefix.size + suffix.size && startsWithText(line, prefix) && endsWithText(line, suffix)
}

func kModeCommand(args: Array<String>, start: Int64): Int64 {
    if (start >= args.size) {
        throw CuicError("kmode requires diff, list, describe, or call")
    }
    let action = args[start]
    if (action == "diff") {
        let requested = if (start + 1 < args.size) { args[start + 1] } else { "" }
        if (start + 2 < args.size) { throw CuicError("kmode diff accepts one project") }
        return runKModeDiff(resolveProject(requested, ""))
    }
    requireDebugChannelBuild("cuic kmode ${action}")
    if (action == "list") {
        let requested = if (start + 1 < args.size) { args[start + 1] } else { "" }
        if (start + 2 < args.size) { throw CuicError("kmode list accepts one project") }
        return runKModeExchange(resolveProject(requested, ""), "list", "", "")
    }
    if (action == "describe") {
        let remaining = args.size - (start + 1)
        if (remaining == 1) {
            return runKModeExchange(resolveProject("", ""), "describe", args[start + 1], "")
        }
        if (remaining == 2) {
            return runKModeExchange(resolveProject(args[start + 1], ""), "describe", args[start + 2], "")
        }
        throw CuicError("kmode describe requires [project] <endpoint>")
    }
    if (action == "call") {
        return kModeCallCommand(args, start + 1)
    }
    throw CuicError("unknown kmode action '${action}'")
}

func probeCommand(args: Array<String>, start: Int64): Int64 {
    if (start >= args.size) {
        throw CuicError("probe requires diff, list, describe, run, or ascii")
    }
    let action = args[start]
    if (action == "diff") {
        let requested = if (start + 1 < args.size) { args[start + 1] } else { "" }
        if (start + 2 < args.size) { throw CuicError("probe diff accepts one project") }
        return runProbeDiff(resolveProject(requested, ""))
    }
    requireDebugChannelBuild("cuic probe ${action}")
    if (action == "list") {
        var projectValue = ""
        var json = false
        var i = start + 1
        while (i < args.size) {
            if (args[i] == "--json") { json = true }
            else if (projectValue.isEmpty()) { projectValue = args[i] }
            else { throw CuicError("probe list accepts one project and --json") }
            i += 1
        }
        return runProbeExchange(resolveProject(projectValue, ""), "cui.probe.list",
            if (json) { "json" } else { "" }, "", json)
    }
    if (action == "describe") {
        let parsed = parseProbeTarget(args, start + 1, false)
        return runProbeExchange(parsed.project, "cui.probe.describe",
            parsed.name + "\n" + (if (parsed.json) { "json" } else { "" }), parsed.name, parsed.json)
    }
    if (action == "run") {
        let parsed = parseProbeTarget(args, start + 1, true)
        return runProbeExchange(parsed.project, "cui.probe.run", parsed.name + "\n" + parsed.script,
            parsed.name, parsed.json)
    }
    if (action == "ascii") {
        return runProbeAscii(args, start + 1, "probe ascii")
    }
    throw CuicError("unknown probe action '${action}'")
}

func pviewCommand(args: Array<String>, start: Int64): Int64 {
    requireDebugChannelBuild("cuic pview")
    return runProbeAscii(args, start, "pview")
}

func designCommand(args: Array<String>, start: Int64): Int64 {
    if (start >= args.size || args[start] != "snapshot") {
        throw CuicError("design requires snapshot")
    }
    requireDebugChannelBuild("cuic design snapshot")
    let parsed = parseProbeTarget(args, start + 1, true)
    if (parsed.json) { throw CuicError("design snapshot always emits canonical JSON") }
    let request = "@cui-design-snapshot\n" + parsed.script
    runProbeExchange(parsed.project, "cui.probe.run", parsed.name + "\n" + request,
        parsed.name, true)
}

func uiCommand(args: Array<String>, start: Int64): Int64 {
    if (start >= args.size || args[start] != "audit") {
        throw CuicError("ui requires audit")
    }
    requireDebugChannelBuild("cuic ui audit")
    let parsed = parseProbeTarget(args, start + 1, true, allowAudit: true)
    if (parsed.json) { throw CuicError("ui audit always emits canonical JSON") }
    let request = "@cui-ui-audit ${parsed.failOn}\n" + parsed.script
    runProbeExchange(parsed.project, "cui.probe.run", parsed.name + "\n" + request,
        parsed.name, true)
}

func runProbeAscii(args: Array<String>, start: Int64, commandName: String): Int64 {
    let parsed = parseProbeTarget(args, start, true, allowAscii: true)
    if (parsed.json) { throw CuicError(commandName + " does not accept --json") }
    let request = "@cui-ascii ${parsed.columns} ${parsed.rows}\n" + parsed.script
    return runProbeExchange(parsed.project, "cui.probe.run", parsed.name + "\n" + request,
        parsed.name, false)
}

class ProbeTargetSelection {
    let project: String
    let name: String
    let script: String
    let json: Bool
    let columns: Int64
    let rows: Int64
    let failOn: String

    init(project: String, name: String, script: String, json: Bool, columns: Int64, rows: Int64,
        failOn!: String = "warning") {
        this.project = project
        this.name = name
        this.script = script
        this.json = json
        this.columns = columns
        this.rows = rows
        this.failOn = failOn
    }
}

func parseProbeTarget(args: Array<String>, start: Int64, allowScript: Bool,
    allowAscii!: Bool = false, allowAudit!: Bool = false): ProbeTargetSelection {
    let positional = ArrayList<String>()
    var script = ""
    var json = false
    var columns: Int64 = 96
    var rows: Int64 = 32
    var failOn = "warning"
    var i = start
    while (i < args.size) {
        let value = args[i]
        if (value == "--json") { json = true; i += 1; continue }
        if (value == "--fail-on") {
            if (!allowAudit) { throw CuicError("--fail-on is only valid for ui audit") }
            if (i + 1 >= args.size) { throw CuicError("--fail-on requires info, warning, or error") }
            failOn = args[i + 1]
            if (failOn != "info" && failOn != "warning" && failOn != "error") {
                throw CuicError("--fail-on requires info, warning, or error")
            }
            i += 2
            continue
        }
        if (value == "--columns" || value == "--rows") {
            if (!allowAscii) { throw CuicError("${value} is only valid for probe ascii") }
            if (i + 1 >= args.size) { throw CuicError(value + " requires a value") }
            if (value == "--columns") { columns = Int64.parse(args[i + 1]) }
            else { rows = Int64.parse(args[i + 1]) }
            i += 2
            continue
        }
        if (value == "--script" || value == "--events") {
            if (!allowScript) { throw CuicError("probe describe does not accept event scripts") }
            if (i + 1 >= args.size) { throw CuicError(value + " requires a value") }
            script = if (value == "--script") {
                String.fromUtf8(File.readFrom(args[i + 1]))
            } else {
                args[i + 1]
            }
            i += 2
            continue
        }
        if (startsWithText(value, "-")) { throw CuicError("unknown probe option '${value}'") }
        positional.add(value)
        i += 1
    }
    if (positional.isEmpty() || positional.size > 2) {
        throw CuicError("probe requires [project] <probe>")
    }
    let project = if (positional.size == 2) {
        resolveProject(positional[0], "")
    } else {
        resolveProject("", "")
    }
    let name = positional[positional.size - 1]
    if (allowAscii) {
        if (columns < 20 || columns > 240) { throw CuicError("probe ascii columns must be between 20 and 240") }
        if (rows < 8 || rows > 100) { throw CuicError("probe ascii rows must be between 8 and 100") }
    }
    ProbeTargetSelection(project, name, script, json, columns, rows, failOn: failOn)
}

func runProbeExchange(projectValue: String, endpoint: String, payload: String,
    probeName: String, json: Bool): Int64 {
    let project = normalizeKModePath(projectValue)
    let framework = ensureFrameworkRoot(project)
    let context = ExecutionContext(project, framework)
    let diffCode = runKModeDiff(project, quiet: true)
    if (diffCode != 0) { return diffCode }
    let probeDiffCode = runProbeDiff(project, quiet: true)
    if (probeDiffCode != 0) { return probeDiffCode }
    let boot = bootstrap(hostPlatform(), framework, stagingRoot: context.stagingRoot)
    if (boot != 0) { return boot }
    let lease = context.acquireLease()
    var buildCode = 0
    try {
        buildCode = if (json) {
            executeCjpmQuiet(context, ["build", "-g"])
        } else {
            executeCjpm(context, ["build", "-g"])
        }
    } finally {
        context.releaseLease(lease)
    }
    if (buildCode != 0) { return buildCode }
    let session = CuicKModeSession(project, framework)
    try {
        let response = session.exchange("invoke", endpoint: endpoint, payload: payload)
        if (!response.ok) {
            throw CuicError("probe ${response.status} (${response.errorCode}): ${response.errorMessage}")
        }
        let rendered = if (json && !startsWithText(trimAscii(response.payload), "{")) {
            "{\"protocol\":\"cui.probe.v0\",\"probe\":" + cuicJsonQuote(probeName) +
                ",\"ok\":true,\"result\":" + cuicJsonQuote(response.payload) + "}"
        } else {
            response.payload
        }
        if (!rendered.isEmpty()) { println(rendered) }
        let exitCode = session.close()
        if (exitCode != 0) { throw CuicError("probe process exited with ${exitCode}") }
        if (containsText(rendered, "\"ok\":false") ||
            (containsText(rendered, "\"protocol\":\"canghui.ui-health/v1\"") &&
                containsText(rendered, "\"passed\":false")) ||
            startsWithText(rendered, "CUI_PROBE_ASCII_ERROR:")) { return 1 }
        0
    } catch (error: Exception) {
        session.abort()
        throw error
    }
}

func cuicJsonQuote(value: String): String {
    let out = StringBuilder()
    out.append("\"")
    for (r in value.toRuneArray()) {
        if (r == r'\"') { out.append("\\\"") }
        else if (r == r'\\') { out.append("\\\\") }
        else if (r == r'\n') { out.append("\\n") }
        else if (r == r'\r') { out.append("\\r") }
        else if (r == r'\t') { out.append("\\t") }
        else { out.append(r.toString()) }
    }
    out.append("\"")
    out.toString()
}

func kModeCallCommand(args: Array<String>, start: Int64): Int64 {
    let remaining = args.size - start
    if (remaining <= 0 || remaining > 3) {
        throw CuicError("kmode call requires [project] <endpoint> [payload]")
    }
    if (remaining == 1) {
        return runKModeExchange(resolveProject("", ""), "invoke", args[start], "")
    }
    if (remaining == 2 && !kModeProjectCandidate(args[start])) {
        return runKModeExchange(resolveProject("", ""), "invoke", args[start], args[start + 1])
    }
    let project = resolveProject(args[start], "")
    let endpoint = args[start + 1]
    let payload = if (remaining == 3) { args[start + 2] } else { "" }
    runKModeExchange(project, "invoke", endpoint, payload)
}

func kModeProjectCandidate(value: String): Bool {
    if (exists(joinPath(value, "cjpm.toml"))) { return true }
    try {
        let example = joinPath(joinPath(resolveFrameworkRoot(""), "examples"), value)
        exists(joinPath(example, "cjpm.toml"))
    } catch (_: Exception) {
        false
    }
}

func runKModeExchange(projectValue: String, operation: String, endpoint: String, payload: String): Int64 {
    let project = normalizeKModePath(projectValue)
    let framework = ensureFrameworkRoot(project)
    let context = ExecutionContext(project, framework)
    let diffCode = runKModeDiff(project, quiet: true)
    if (diffCode != 0) { return diffCode }
    let boot = bootstrap(hostPlatform(), framework, stagingRoot: context.stagingRoot)
    if (boot != 0) { return boot }
    let lease = context.acquireLease()
    var buildCode = 0
    try {
        buildCode = executeCjpm(context, ["build", "-g"])
    } finally {
        context.releaseLease(lease)
    }
    if (buildCode != 0) { return buildCode }
    let session = CuicKModeSession(project, framework)
    try {
        let response = session.exchange(operation, endpoint: endpoint, payload: payload)
        if (!response.ok) {
            throw CuicError("kMode ${response.status} (${response.errorCode}): ${response.errorMessage}")
        }
        if (!response.payload.isEmpty()) {
            println(response.payload)
        } else {
            println(response.status)
        }
        let exitCode = session.close()
        if (exitCode != 0) {
            throw CuicError("kMode process exited with ${exitCode}")
        }
        0
    } catch (error: Exception) {
        session.abort()
        throw error
    }
}

@When[debug]
func kModeChildEnvironment(framework: String): HashMap<String, String> {
    requireDebugChannelBuild("cuic kMode/probe runtime")
    let environment = HashMap<String, String>()
    for ((key, value) in getVariables()) {
        environment.add(key, value)
    }
    environment.add("CANGHUI_KMODE", "1")
    environment.add("CANGHUI_KMODE_TRANSPORT", "stdio")
    environment.add("CANGHUI_HARMONYOS_SANS", runtimeHarmonyFont(framework))
    let sdl = joinPath(framework, "sdl/.sdl3")
    if (hostPlatform() == "macos") {
        environment.add("DYLD_LIBRARY_PATH", sdl + ":" + readEnv("DYLD_LIBRARY_PATH"))
    } else if (hostPlatform() == "linux") {
        environment.add("LD_LIBRARY_PATH", sdl + ":" + readEnv("LD_LIBRARY_PATH"))
    } else {
        environment.add("PATH", sdl + ";" + readEnv("PATH"))
    }
    environment
}

@When[!debug]
func kModeChildEnvironment(_framework: String): HashMap<String, String> {
    requireDebugChannelBuild("cuic kMode/probe runtime")
    HashMap<String, String>()
}

func runKModeDiff(projectValue: String, quiet!: Bool = false): Int64 {
    let project = normalizeKModePath(projectValue)
    let roots = ArrayList<String>()
    collectKModeRoots(project, roots)
    let framework = tryResolveFrameworkRoot(project)
    if (!framework.isEmpty()) { collectKModeRoots(framework, roots) }
    let links = ArrayList<KModeLinkLocation>()
    for (root in roots) {
        let sourceRoot = kModeSourceRoot(root)
        if (exists(sourceRoot)) {
            scanKModeDirectory(sourceRoot, links)
        }
    }
    var duplicateEndpoints: Int64 = 0
    var i: Int64 = 0
    while (i < links.size) {
        if (!hasEarlierKModeEndpoint(links, i)) {
            var count: Int64 = 0
            for (candidate in links) {
                if (candidate.endpoint == links[i].endpoint) { count += 1 }
            }
            if (count > 1) {
                duplicateEndpoints += 1
                println("duplicate kMode endpoint '${links[i].endpoint}':")
                for (candidate in links) {
                    if (candidate.endpoint == links[i].endpoint) {
                        println("  ${candidate.path}:${candidate.line}")
                    }
                }
            }
        }
        i += 1
    }
    if (duplicateEndpoints > 0) {
        println("kMode diff failed: ${duplicateEndpoints} duplicate endpoint(s)")
        return 1
    }
    if (!quiet) {
        println("kMode diff passed: ${links.size} link(s) across ${roots.size} local package root(s)")
    }
    0
}

func runProbeDiff(projectValue: String, quiet!: Bool = false): Int64 {
    let project = normalizeKModePath(projectValue)
    let roots = ArrayList<String>()
    collectKModeRoots(project, roots)
    let framework = tryResolveFrameworkRoot(project)
    if (!framework.isEmpty()) { collectKModeRoots(framework, roots) }
    let links = ArrayList<ProbeLinkLocation>()
    for (root in roots) {
        let sourceRoot = kModeSourceRoot(root)
        if (exists(sourceRoot)) { scanProbeDirectory(sourceRoot, links) }
    }
    var duplicateEndpoints: Int64 = 0
    var i: Int64 = 0
    while (i < links.size) {
        if (!hasEarlierProbeEndpoint(links, i)) {
            var count: Int64 = 0
            for (candidate in links) { if (candidate.endpoint == links[i].endpoint) { count += 1 } }
            if (count > 1) {
                duplicateEndpoints += 1
                println("duplicate probe '${links[i].endpoint}':")
                for (candidate in links) {
                    if (candidate.endpoint == links[i].endpoint) {
                        println("  ${candidate.path}:${candidate.line}")
                    }
                }
            }
        }
        i += 1
    }
    if (duplicateEndpoints > 0) {
        println("probe diff failed: ${duplicateEndpoints} duplicate probe name(s)")
        return 1
    }
    if (!quiet) {
        println("probe diff passed: ${links.size} probe(s) across ${roots.size} local package root(s)")
    }
    0
}

func kModeSourceRoot(root: String): String {
    let manifest = joinPath(root, "cjpm.toml")
    if (exists(manifest)) {
        let text = String.fromUtf8(File.readFrom(manifest))
        for (line in text.split("\n")) {
            let trimmed = trimAscii(line)
            if (startsWithText(trimmed, "src-dir")) {
                let firstQuote = indexOfText(trimmed, "\"")
                if (firstQuote >= 0) {
                    let quoted = substringFrom(trimmed, firstQuote + 1)
                    let secondQuote = indexOfText(quoted, "\"")
                    if (secondQuote > 0) {
                        return joinPath(root, substringTo(quoted, secondQuote))
                    }
                }
            }
        }
    }
    joinPath(root, "src")
}

func collectKModeRoots(rootValue: String, roots: ArrayList<String>): Unit {
    let root = normalizeKModePath(rootValue)
    for (existing in roots) {
        if (existing == root) { return }
    }
    roots.add(root)
    let manifest = joinPath(root, "cjpm.toml")
    if (!exists(manifest)) { return }
    let text = String.fromUtf8(File.readFrom(manifest))
    for (value in kModeLocalDependencyPaths(text)) {
        let dependency = if (startsWithText(value, "/") || isWindowsAbsolute(value)) {
            value
        } else {
            joinPath(root, value)
        }
        if (exists(joinPath(dependency, "cjpm.toml"))) {
            collectKModeRoots(dependency, roots)
        }
    }
}

func kModeLocalDependencyPaths(manifest: String): Array<String> {
    let paths = ArrayList<String>()
    var inDependencies = false
    for (line in manifest.split("\n")) {
        let trimmed = trimAscii(line)
        if (startsWithText(trimmed, "[")) {
            inDependencies = trimmed == "[dependencies]" ||
                startsWithText(trimmed, "[dependencies.")
            continue
        }
        if (inDependencies) {
            match (extractLocalDependencyPath(trimmed)) {
                case Some(value) => paths.add(value)
                case None => ()
            }
        }
    }
    paths.toArray()
}

func extractLocalDependencyPath(line: String): ?String {
    let trimmed = trimAscii(line)
    let pathIndex = indexOfText(trimmed, "path")
    if (pathIndex < 0) { return None }
    let afterPath = substringFrom(trimmed, pathIndex + 4)
    let equalsIndex = indexOfText(afterPath, "=")
    if (equalsIndex < 0) { return None }
    let afterEquals = substringFrom(afterPath, equalsIndex + 1)
    let firstQuote = indexOfText(afterEquals, "\"")
    if (firstQuote < 0) { return None }
    let quoted = substringFrom(afterEquals, firstQuote + 1)
    let secondQuote = indexOfText(quoted, "\"")
    if (secondQuote < 0) { return None }
    let value = substringTo(quoted, secondQuote)
    if (value.isEmpty()) { None } else { Some(value) }
}

func scanKModeDirectory(root: String, links: ArrayList<KModeLinkLocation>): Unit {
    for (entry in Directory.readFrom(root)) {
        let path = entry.path.toString()
        let name = basename(path)
        if (entry.isDirectory()) {
            if (name != ".git" && name != ".cache" && name != "target") {
                scanKModeDirectory(path, links)
            }
        } else if (endsWithText(name, ".cj") && !endsWithText(name, "_test.cj")) {
            scanKModeSource(path, links)
        }
    }
}

func scanProbeDirectory(root: String, links: ArrayList<ProbeLinkLocation>): Unit {
    for (entry in Directory.readFrom(root)) {
        let path = entry.path.toString()
        let name = basename(path)
        if (entry.isDirectory()) {
            if (name != ".git" && name != ".cache" && name != "target") {
                scanProbeDirectory(path, links)
            }
        } else if (endsWithText(name, ".cj") && !endsWithText(name, "_test.cj")) {
            scanProbeSource(path, links)
        }
    }
}

func scanKModeSource(path: String, links: ArrayList<KModeLinkLocation>): Unit {
    let text = String.fromUtf8(File.readFrom(path))
    let lines = text.split("\n")
    var index: Int64 = 0
    while (index < lines.size) {
        match (extractKModeLinkEndpoint(lines[index])) {
            case Some(endpoint) => links.add(KModeLinkLocation(endpoint, path, index + 1))
            case None => ()
        }
        index += 1
    }
}

func scanProbeSource(path: String, links: ArrayList<ProbeLinkLocation>): Unit {
    let text = String.fromUtf8(File.readFrom(path))
    let lines = text.split("\n")
    var index: Int64 = 0
    while (index < lines.size) {
        match (extractCuiProbeEndpoint(lines[index])) {
            case Some(endpoint) => links.add(ProbeLinkLocation(endpoint, path, index + 1))
            case None => ()
        }
        index += 1
    }
}

func extractKModeLinkEndpoint(line: String): ?String {
    let value = trimAscii(line)
    let prefix = "@KModeLink[\""
    if (!startsWithText(value, prefix)) { return None }
    let remainder = substringFrom(value, Int64(prefix.toRuneArray().size))
    let close = indexOfText(remainder, "\"]")
    if (close <= 0 || !trimAscii(substringFrom(remainder, close + 2)).isEmpty()) { return None }
    Some(substringTo(remainder, close))
}

func extractCuiProbeEndpoint(line: String): ?String {
    let value = trimAscii(line)
    let prefix = "@CuiProbe[\""
    if (!startsWithText(value, prefix)) { return None }
    let remainder = substringFrom(value, Int64(prefix.toRuneArray().size))
    let close = indexOfText(remainder, "\"]")
    if (close <= 0 || !trimAscii(substringFrom(remainder, close + 2)).isEmpty()) { return None }
    Some(substringTo(remainder, close))
}

func hasEarlierKModeEndpoint(links: ArrayList<KModeLinkLocation>, index: Int64): Bool {
    var i: Int64 = 0
    while (i < index) {
        if (links[i].endpoint == links[index].endpoint) { return true }
        i += 1
    }
    false
}

func hasEarlierProbeEndpoint(links: ArrayList<ProbeLinkLocation>, index: Int64): Bool {
    var i: Int64 = 0
    while (i < index) {
        if (links[i].endpoint == links[index].endpoint) { return true }
        i += 1
    }
    false
}

func normalizeKModePath(value: String): String {
    let path = if (startsWithText(value, "/") || isWindowsAbsolute(value)) {
        value
    } else {
        joinPath(currentDirectory(), value)
    }
    Path(path).normalize().toString()
}

func encodeCuicKModeRequest(id: Int64, operation: String, endpoint: String, payload: String): String {
    CUIC_KMODE_PROTOCOL + "|" + id.toString() + "|" + operation + "|" +
        encodeCuicKModeText(endpoint) + "|" + encodeCuicKModeText(payload)
}

func decodeCuicKModeResponse(line: String): CuicKModeResponse {
    let parts = line.split("|")
    if (parts.size != 7 || parts[0] != CUIC_KMODE_PROTOCOL) {
        throw CuicError("invalid kMode response frame: ${line}")
    }
    CuicKModeResponse(
        Int64.parse(parts[1]),
        parts[2] == "1",
        decodeCuicKModeText(parts[3]),
        decodeCuicKModeText(parts[4]),
        Int64.parse(parts[5]),
        decodeCuicKModeText(parts[6])
    )
}

func encodeCuicKModeText(value: String): String {
    let digits = "0123456789abcdef".toRuneArray()
    var out = ""
    for (byte in value.toArray()) {
        out += digits[Int64(byte >> 4)].toString()
        out += digits[Int64(byte & 0x0f)].toString()
    }
    out
}

func decodeCuicKModeText(value: String): String {
    let runes = value.toRuneArray()
    if (runes.size % 2 != 0) { throw CuicError("kMode hex field has odd length") }
    let bytes = ArrayList<UInt8>()
    var i: Int64 = 0
    while (i < runes.size) {
        let high = decodeCuicHexNibble(runes[i])
        let low = decodeCuicHexNibble(runes[i + 1])
        bytes.add(UInt8((high << 4) | low))
        i += 2
    }
    String.fromUtf8(bytes.toArray())
}

func decodeCuicHexNibble(value: Rune): Int64 {
    if (value >= r'0' && value <= r'9') { return Int64(UInt32(value) - UInt32(r'0')) }
    if (value >= r'a' && value <= r'f') { return Int64(UInt32(value) - UInt32(r'a')) + 10 }
    if (value >= r'A' && value <= r'F') { return Int64(UInt32(value) - UInt32(r'A')) + 10 }
    throw CuicError("invalid kMode hex digit")
}

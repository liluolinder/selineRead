package cuic

import std.env.getVariable
import std.fs.{File, exists}

let DEFAULT_CANGHUI_GIT = "https://github.com/Celading/CangHui.git"
let DEFAULT_CANGHUI_COMMIT = "a15593ddc03ff3b7ec913c2ac2b3abe22ce74f02"

class FrameworkDependencySpec {
    let path: String
    let git: String
    let commitId: String

    init(path: String, git: String, commitId: String) {
        this.path = path
        this.git = git
        this.commitId = commitId
    }

    func isLocal(): Bool { !path.isEmpty() }
    func isGit(): Bool { !git.isEmpty() }
    func isConfigured(): Bool { isLocal() || isGit() }
}

func emptyFrameworkDependencySpec(): FrameworkDependencySpec {
    FrameworkDependencySpec("", "", "")
}

func defaultFrameworkDependencySpec(): FrameworkDependencySpec {
    FrameworkDependencySpec("", DEFAULT_CANGHUI_GIT, DEFAULT_CANGHUI_COMMIT)
}

func frameworkDependencySpec(project: String): FrameworkDependencySpec {
    let manifest = joinPath(project, "cjpm.toml")
    if (!exists(manifest)) { return emptyFrameworkDependencySpec() }
    let text = String.fromUtf8(File.readFrom(manifest))
    var inDependencies = false
    for (line in text.split("\n")) {
        let trimmed = trimAscii(line)
        if (startsWithText(trimmed, "[")) {
            inDependencies = trimmed == "[dependencies]"
            continue
        }
        if (!inDependencies || !frameworkDependencyLine(trimmed)) { continue }
        return FrameworkDependencySpec(
            extractInlineTomlString(trimmed, "path"),
            extractInlineTomlString(trimmed, "git"),
            extractInlineTomlString(trimmed, "commitId")
        )
    }
    emptyFrameworkDependencySpec()
}

func frameworkDependencyLine(line: String): Bool {
    if (line.isEmpty() || startsWithText(line, "#")) { return false }
    let equals = indexOfText(line, "=")
    if (equals <= 0) { return false }
    let name = trimAscii(substringTo(line, equals))
    name == "chui" || name == "\"chui\""
}

func extractInlineTomlString(line: String, key: String): String {
    let token = key + " ="
    var keyIndex = indexOfText(line, token)
    if (keyIndex < 0) {
        keyIndex = indexOfText(line, key + "=")
    }
    if (keyIndex < 0) { return "" }
    let afterKey = substringFrom(line, keyIndex + Int64(key.toRuneArray().size))
    let equals = indexOfText(afterKey, "=")
    if (equals < 0) { return "" }
    let afterEquals = substringFrom(afterKey, equals + 1)
    let firstQuote = indexOfText(afterEquals, "\"")
    if (firstQuote < 0) { return "" }
    let quoted = substringFrom(afterEquals, firstQuote + 1)
    let secondQuote = indexOfText(quoted, "\"")
    if (secondQuote < 0) { return "" }
    substringTo(quoted, secondQuote)
}

func lockedFrameworkCommit(project: String): String {
    let lock = joinPath(project, "cjpm.lock")
    if (!exists(lock)) { return "" }
    let text = String.fromUtf8(File.readFrom(lock))
    var inRequires = false
    for (line in text.split("\n")) {
        let trimmed = trimAscii(line)
        if (startsWithText(trimmed, "[")) {
            inRequires = trimmed == "[requires]"
            continue
        }
        if (inRequires && frameworkDependencyLine(trimmed)) {
            return extractInlineTomlString(trimmed, "commitId")
        }
    }
    ""
}

func frameworkDependencyLockProblem(spec: FrameworkDependencySpec, locked: String): String {
    if (spec.isLocal()) { return "" }
    if (!spec.isGit()) { return "The project does not declare a chui dependency." }
    if (spec.commitId.isEmpty()) {
        return "The CangHui Git dependency must declare an exact commitId."
    }
    if (locked.isEmpty()) {
        return "The CangHui dependency lock is missing."
    }
    if (locked != spec.commitId) {
        return "The CangHui dependency lock does not match the manifest commitId " +
            "(manifest ${spec.commitId}, lock ${locked})."
    }
    ""
}

func requireFrozenFrameworkDependency(project: String): Unit {
    if (frameworkRootCandidate(project)) { return }
    let spec = frameworkDependencySpec(project)
    let integrated = integratedFrameworkRoot()
    let normalizedProject = trimTrailingSlash(project)
    if (!spec.isGit() && !integrated.isEmpty() &&
        (normalizedProject == integrated || startsWithText(normalizedProject, integrated + "/"))) {
        return
    }
    let problem = frameworkDependencyLockProblem(spec, lockedFrameworkCommit(project))
    if (!problem.isEmpty()) {
        throw CuicError("${problem} Run 'cuic dependency update ${project}' explicitly before build-like commands.")
    }
}

func cjpmCacheRoot(project: String): String {
    let home = readEnv("HOME")
    if (!project.isEmpty()) {
        let projectConfig = joinPath(project, "cangjie-repo.toml")
        let configured = repositoryCachePath(projectConfig, home)
        if (!configured.isEmpty()) { return configured }
    }
    if (!home.isEmpty()) {
        let userConfig = joinPath(home, ".cjpm/cangjie-repo.toml")
        let configured = repositoryCachePath(userConfig, home)
        if (!configured.isEmpty()) { return configured }
    }
    match (getVariable("CJPM_CONFIG")) {
        case Some(value) where !trimAscii(value).isEmpty() => return trimTrailingSlash(trimAscii(value))
        case _ => ()
    }
    if (!home.isEmpty()) { return joinPath(home, ".cjpm") }
    ""
}

func repositoryCachePath(config: String, home: String): String {
    if (!exists(config)) { return "" }
    repositoryCachePathFromText(String.fromUtf8(File.readFrom(config)), home)
}

func repositoryCachePathFromText(text: String, home: String): String {
    var inCache = false
    for (line in text.split("\n")) {
        let trimmed = trimAscii(line)
        if (startsWithText(trimmed, "[")) {
            inCache = trimmed == "[repository.cache]"
            continue
        }
        if (!inCache || !startsWithText(trimmed, "path")) { continue }
        let value = extractTomlAssignmentString(trimmed)
        return expandHomePath(value, home)
    }
    ""
}

func extractTomlAssignmentString(line: String): String {
    let equals = indexOfText(line, "=")
    if (equals < 0) { return "" }
    let value = substringFrom(line, equals + 1)
    let firstQuote = indexOfText(value, "\"")
    if (firstQuote < 0) { return "" }
    let quoted = substringFrom(value, firstQuote + 1)
    let secondQuote = indexOfText(quoted, "\"")
    if (secondQuote < 0) { return "" }
    substringTo(quoted, secondQuote)
}

func expandHomePath(value: String, home: String): String {
    if (startsWithText(value, "$" + "{HOME}")) {
        return trimTrailingSlash(home + substringFrom(value, 7))
    }
    if (startsWithText(value, "$HOME")) {
        return trimTrailingSlash(home + substringFrom(value, 5))
    }
    if (startsWithText(value, "~/")) {
        return trimTrailingSlash(joinPath(home, substringFrom(value, 2)))
    }
    trimTrailingSlash(value)
}

func cachedFrameworkRoot(project: String): String {
    let spec = frameworkDependencySpec(project)
    if (!spec.isGit()) { return "" }
    let commit = if (!lockedFrameworkCommit(project).isEmpty()) {
        lockedFrameworkCommit(project)
    } else {
        spec.commitId
    }
    let cache = cjpmCacheRoot(project)
    if (commit.isEmpty() || cache.isEmpty()) { return "" }
    let candidate = joinPath(joinPath(joinPath(cache, "git"), "chui"), commit)
    if (frameworkRootCandidate(candidate)) { trimTrailingSlash(candidate) } else { "" }
}

func ensureFrameworkRoot(project: String): String {
    requireFrozenFrameworkDependency(project)
    try {
        return resolveFrameworkRoot(project)
    } catch (_: CuicError) {
        let spec = frameworkDependencySpec(project)
        if (spec.isGit()) {
            throw CuicError("The locked CangHui dependency is not available in the CJPM cache. " +
                "Run 'cuic dependency update ${project}' explicitly.")
        }
        throw CuicError("CangHui dependency is not resolved; configure [dependencies].chui or set CANGHUI_FRAMEWORK_ROOT")
    }
}

func dependencyCommand(args: Array<String>, start: Int64): Int64 {
    if (start >= args.size || args[start] != "update") {
        throw CuicError("dependency requires the 'update' action")
    }
    if (start + 2 < args.size) { throw CuicError("dependency update accepts at most one project") }
    let requested = if (start + 1 < args.size) { args[start + 1] } else { "" }
    let direct = if (requested.isEmpty()) { currentDirectory() } else { requested }
    if (!exists(joinPath(direct, "cjpm.toml"))) {
        throw CuicError("no cjpm.toml found in ${direct}")
    }
    let project = trimTrailingSlash(direct)
    let spec = frameworkDependencySpec(project)
    if (spec.isLocal()) {
        println("CangHui uses a local path dependency; no lock update is required.")
        return 0
    }
    if (!spec.isGit()) { throw CuicError("The project does not declare a chui Git dependency.") }
    if (spec.commitId.isEmpty()) {
        throw CuicError("The CangHui Git dependency must declare an exact commitId before update.")
    }
    println("==> explicitly updating the CangHui dependency lock in ${project}")
    let code = executeCommand("cjpm", ["update"], project)
    if (code != 0) { return code }
    requireFrozenFrameworkDependency(project)
    println("CangHui dependency locked at ${spec.commitId}")
    0
}

func tryResolveFrameworkRoot(project: String): String {
    try {
        resolveFrameworkRoot(project)
    } catch (_: Exception) {
        ""
    }
}

func renderFrameworkDependency(spec: FrameworkDependencySpec): String {
    if (spec.isLocal()) {
        return "chui = { path = \"${spec.path}\" }"
    }
    if (spec.isGit() && !spec.commitId.isEmpty()) {
        return "chui = { git = \"${spec.git}\", commitId = \"${spec.commitId}\" }"
    }
    if (spec.isGit()) {
        return "chui = { git = \"${spec.git}\" }"
    }
    throw CuicError("CangHui dependency is not configured")
}

func shortCommit(value: String): String {
    if (value.toRuneArray().size <= 12) { return value }
    substringTo(value, 12)
}

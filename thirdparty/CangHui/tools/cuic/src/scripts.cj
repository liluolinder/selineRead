package cuic

import std.collection.ArrayList
import std.fs.{File, exists}

let PROJECT_MANIFEST = "canghui.toml"

class ProjectScript {
    let name: String
    let steps: Array<String>

    init(name: String, steps: Array<String>) {
        this.name = name
        this.steps = steps
    }
}

func scriptsCommand(args: Array<String>, start: Int64): Int64 {
    let action = if (start < args.size) { args[start] } else { "list" }
    if (action == "init") {
        let requested = if (start + 1 < args.size) { args[start + 1] } else { "" }
        let project = resolveProject(requested, "")
        return initializeProjectScripts(project)
    }
    if (action == "list") {
        let requested = if (start + 1 < args.size) { args[start + 1] } else { "" }
        let project = resolveProject(requested, "")
        return listProjectScripts(project)
    }
    if (action == "run") {
        if (start + 1 >= args.size) { throw CuicError("scripts run requires a script name") }
        let name = args[start + 1]
        let requested = if (start + 2 < args.size) { args[start + 2] } else { "" }
        let project = resolveProject(requested, "")
        return runProjectScript(project, name)
    }
    throw CuicError("unknown scripts action '${action}'")
}

func initializeProjectScripts(project: String): Int64 {
    let manifest = joinPath(project, PROJECT_MANIFEST)
    if (exists(manifest)) { throw CuicError("project script manifest already exists: ${manifest}") }
    File.writeTo(manifest, defaultProjectManifest().toArray())
    println("created project scripts: ${manifest}")
    0
}

func listProjectScripts(project: String): Int64 {
    let scripts = loadProjectScripts(project)
    if (scripts.isEmpty()) {
        println("no project scripts in ${joinPath(project, PROJECT_MANIFEST)}")
        return 0
    }
    println("Project scripts (${basename(project)}):")
    for (script in scripts) {
        println("  ${script.name}: ${joinScriptSteps(script.steps)}")
    }
    0
}

func tryRunProjectScript(args: Array<String>, command: String): ?Int64 {
    if (args.size > 3) { return None }
    let requested = if (args.size == 3) { args[2] } else { "" }
    let project = tryResolveScriptProject(requested)
    match (project) {
        case Some(value) =>
            match (findProjectScript(loadProjectScripts(value), command)) {
                case Some(_) => Some(runProjectScript(value, command))
                case None => None
            }
        case None => None
    }
}

func tryResolveScriptProject(requested: String): ?String {
    let direct = if (requested.isEmpty()) { currentDirectory() } else { requested }
    if (exists(joinPath(direct, "cjpm.toml")) && exists(joinPath(direct, PROJECT_MANIFEST))) {
        return Some(trimTrailingSlash(direct))
    }
    None
}

func runProjectScript(project: String, name: String): Int64 {
    let script = findProjectScript(loadProjectScripts(project), name)
    match (script) {
        case None => throw CuicError("project script '${name}' is not declared in ${joinPath(project, PROJECT_MANIFEST)}")
        case Some(value) =>
            println("==> script ${value.name} (${basename(project)})")
            var index: Int64 = 0
            for (step in value.steps) {
                println("--> ${step}")
                let code = runCuicInternal(scriptStepCommand(step, project), false)
                if (code != 0) {
                    println("script '${value.name}' stopped at step ${index + 1}")
                    return code
                }
                index += 1
            }
            0
    }
}

func loadProjectScripts(project: String): Array<ProjectScript> {
    let manifest = joinPath(project, PROJECT_MANIFEST)
    if (!exists(manifest)) { return [] }
    parseProjectScripts(String.fromUtf8(File.readFrom(manifest)))
}

func parseProjectScripts(text: String): Array<ProjectScript> {
    let scripts = ArrayList<ProjectScript>()
    var inScripts = false
    var lineNumber: Int64 = 0
    for (rawLine in text.split("\n")) {
        lineNumber += 1
        let line = trimAscii(rawLine)
        if (line.isEmpty() || startsWithText(line, "#")) { continue }
        if (startsWithText(line, "[")) {
            inScripts = line == "[scripts]"
            continue
        }
        if (!inScripts) { continue }
        let equals = indexOfText(line, "=")
        if (equals <= 0) { throw CuicError("invalid project script at line ${lineNumber}") }
        let name = trimAscii(substringTo(line, equals))
        validateProjectScriptName(name, lineNumber)
        if (findProjectScript(scripts.toArray(), name).isSome()) {
            throw CuicError("duplicate project script '${name}' at line ${lineNumber}")
        }
        let steps = parseScriptSteps(trimAscii(substringFrom(line, equals + 1)), lineNumber)
        scripts.add(ProjectScript(name, steps))
    }
    scripts.toArray()
}

func validateProjectScriptName(name: String, lineNumber: Int64): Unit {
    if (name.isEmpty()) { throw CuicError("empty project script name at line ${lineNumber}") }
    for (rune in name.toRuneArray()) {
        if (!isScriptNameRune(rune)) {
            throw CuicError("invalid project script name '${name}' at line ${lineNumber}")
        }
    }
    if (isReservedCuicCommand(name)) {
        throw CuicError("project script '${name}' conflicts with a cuic command")
    }
}

func isScriptNameRune(value: Rune): Bool {
    (value >= r'a' && value <= r'z') || (value >= r'0' && value <= r'9') || value == r'-' || value == r'_'
}

func isReservedCuicCommand(name: String): Bool {
    for (command in ["help", "version", "examples", "doctor", "bootstrap", "font", "symbol",
        "kmode", "probe", "design", "frame", "scripts", "dependency", "package", "init", "build", "test", "run", "prnt", "print",
        "snapshot", "clean"]) {
        if (name == command) { return true }
    }
    false
}

func parseScriptSteps(value: String, lineNumber: Int64): Array<String> {
    let runes = value.toRuneArray()
    let steps = ArrayList<String>()
    var index: Int64 = 0
    while (index < runes.size && isWhitespace(runes[index])) { index += 1 }
    if (index >= runes.size || runes[index] != r'[') {
        throw CuicError("project script at line ${lineNumber} must be an array of quoted cuic commands")
    }
    index += 1
    while (true) {
        while (index < runes.size && isWhitespace(runes[index])) { index += 1 }
        if (index < runes.size && runes[index] == r']') { index += 1; break }
        if (index >= runes.size || runes[index] != r'\"') {
            throw CuicError("project script at line ${lineNumber} expects a quoted command")
        }
        index += 1
        let step = StringBuilder()
        var closed = false
        while (index < runes.size) {
            let current = runes[index]
            if (current == r'\"') { closed = true; index += 1; break }
            if (current == r'\\') {
                index += 1
                if (index >= runes.size || (runes[index] != r'\\' && runes[index] != r'\"')) {
                    throw CuicError("project script at line ${lineNumber} has an unsupported escape")
                }
                step.append(runes[index].toString())
                index += 1
                continue
            }
            step.append(current.toString())
            index += 1
        }
        if (!closed) { throw CuicError("unterminated project script command at line ${lineNumber}") }
        let command = trimAscii(step.toString())
        if (command.isEmpty()) { throw CuicError("empty project script command at line ${lineNumber}") }
        validateScriptStep(command, lineNumber)
        steps.add(command)
        while (index < runes.size && isWhitespace(runes[index])) { index += 1 }
        if (index < runes.size && runes[index] == r',') { index += 1; continue }
        if (index < runes.size && runes[index] == r']') { index += 1; break }
        throw CuicError("project script at line ${lineNumber} expects ',' or ']'")
    }
    while (index < runes.size && isWhitespace(runes[index])) { index += 1 }
    if (index < runes.size && runes[index] != r'#') {
        throw CuicError("unexpected project script text at line ${lineNumber}")
    }
    if (steps.isEmpty()) { throw CuicError("project script at line ${lineNumber} has no commands") }
    steps.toArray()
}

func validateScriptStep(step: String, lineNumber: Int64): Unit {
    let words = splitScriptCommand(step)
    if (words.isEmpty()) { throw CuicError("empty project script command at line ${lineNumber}") }
    let command = words[0]
    var supported = false
    for (allowed in ["doctor", "build", "test", "run", "prnt", "clean"]) {
        if (command == allowed) { supported = true }
    }
    if (!supported) {
        throw CuicError("project script command '${command}' at line ${lineNumber} is not a portable lifecycle action")
    }
    if (command == "clean" && words.size != 1) {
        throw CuicError("clean project script commands do not accept arguments at line ${lineNumber}")
    }
    if ((command == "build" || command == "test" || command == "run") &&
        (words.size > 2 || (words.size == 2 && !isPlatform(words[1])))) {
        throw CuicError("${command} project script commands accept only an optional platform at line ${lineNumber}")
    }
    for (word in words) {
        if (word == "--project") {
            throw CuicError("project script at line ${lineNumber} cannot override its owning project")
        }
    }
}

func scriptStepCommand(step: String, project: String): Array<String> {
    let words = splitScriptCommand(step)
    let command = words[0]
    let out = ArrayList<String>()
    out.add("cuic")
    for (word in words) { out.add(word) }
    if (command == "doctor") {
        out.add("--project")
        out.add(project)
    } else if (command == "prnt") {
        let values = out.toArray()
        out.clear()
        var inserted = false
        for (value in values) {
            if (!inserted && value == "--") {
                out.add(project)
                inserted = true
            }
            out.add(value)
        }
        if (!inserted) { out.add(project) }
    } else {
        out.add(project)
    }
    out.toArray()
}

func splitScriptCommand(value: String): Array<String> {
    let words = ArrayList<String>()
    var current = StringBuilder()
    var quoteRune: Rune = r'\0'
    let runes = value.toRuneArray()
    var index: Int64 = 0
    while (index < runes.size) {
        let rune = runes[index]
        if (quoteRune != r'\0') {
            if (rune == quoteRune) {
                quoteRune = r'\0'
                index += 1
                continue
            }
            if (rune == r'\\' && index + 1 < runes.size &&
                (runes[index + 1] == quoteRune || runes[index + 1] == r'\\')) {
                current.append(runes[index + 1].toString())
                index += 2
                continue
            }
            current.append(rune.toString())
            index += 1
            continue
        }
        if (rune == r'\"' || rune == r'\'') { quoteRune = rune; index += 1; continue }
        if (rune == r'\\' && index + 1 < runes.size &&
            (isWhitespace(runes[index + 1]) || runes[index + 1] == r'\\' ||
                runes[index + 1] == r'\"' || runes[index + 1] == r'\'')) {
            current.append(runes[index + 1].toString())
            index += 2
            continue
        }
        if (isWhitespace(rune)) {
            if (current.toString().size > 0) {
                words.add(current.toString())
                current = StringBuilder()
            }
            index += 1
            continue
        }
        current.append(rune.toString())
        index += 1
    }
    if (quoteRune != r'\0') { throw CuicError("unterminated quote in project script command") }
    if (current.toString().size > 0) { words.add(current.toString()) }
    words.toArray()
}

func findProjectScript(scripts: Array<ProjectScript>, name: String): ?ProjectScript {
    for (script in scripts) {
        if (script.name == name) { return Some(script) }
    }
    None
}

func joinScriptSteps(steps: Array<String>): String {
    let out = StringBuilder()
    var index: Int64 = 0
    for (step in steps) {
        if (index > 0) { out.append(" -> ") }
        out.append(step)
        index += 1
    }
    out.toString()
}

func defaultProjectManifest(packageName!: String = "demo"): String {
    "# CangHui project lifecycle aliases. Commands are interpreted by cuic, not a shell.\n" +
    "[application]\n" +
    "name = \"${packageName}\"\n" +
    "identifier = \"dev.canghui.${packageName}\"\n" +
    "version = \"0.1.0\"\n" +
    "publisher = \"\"\n\n" +
    "[assets]\n" +
    "resources = []\n\n" +
    "[system]\n" +
    "single-instance = true\n" +
    "status-item = false\n" +
    "notifications = true\n" +
    "settings = true\n\n" +
    "[scripts]\n" +
    "check = [\"doctor\", \"test\", \"build\"]\n" +
    "dev = [\"run\"]\n" +
    "snapshot-ui = [\"prnt --output dist/preview.png\"]\n"
}

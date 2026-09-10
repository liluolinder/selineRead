package cuic

import std.collection.{ArrayList, HashSet}
import std.fs.{Directory, File, FileInfo, Path, canonicalize, exists}

let HARMONY_PROJECTION_PROTOCOL = "canghui.harmony-projection/v1"
let HARMONY_PROJECTION_MAX_SOURCE_BYTES: Int64 = 4 * 1024 * 1024

private class HarmonyProjectionSource {
    let relativePath: String
    let sourcePath: String
    let content: String
    let digest: String

    init(relativePath: String, sourcePath: String, content: String) {
        this.relativePath = relativePath
        this.sourcePath = sourcePath
        this.content = content
        this.digest = harmonyStableDigest(content)
    }
}

func harmonyPrepareCommand(args: Array<String>, start: Int64, framework: String): Int64 {
    var requested = ""
    var json = false
    var i = start
    while (i < args.size) {
        if (args[i] == "--json") { json = true; i += 1; continue }
        if (startsWithText(args[i], "-")) { throw CuicError("unknown prepare harmony option '${args[i]}'") }
        if (!requested.isEmpty()) { throw CuicError("prepare harmony accepts one project") }
        requested = args[i]
        i += 1
    }
    let project = resolveProject(requested, "")
    let manifest = loadApplicationManifest(project)
    if (manifest.harmonySourceRoots.isEmpty()) {
        throw CuicError("canghui.toml does not declare a [harmony] projection")
    }
    let receipt = prepareHarmonyProjection(project, framework, manifest)
    if (json) { println(receipt) }
    else {
        println("Harmony projection ready (${HARMONY_PROJECTION_PROTOCOL})")
        println("Output: ${harmonyProjectionOutput(project, manifest)}")
        println("Receipt: ${receipt}")
    }
    0
}

func prepareHarmonyProjection(project: String, framework: String, manifest: ApplicationManifest): String {
    validateHarmonyProjectionManifest(manifest, project)
    let output = harmonyProjectionOutput(project, manifest)
    ensureHarmonyOutputInsideProject(project, output)
    let sources = collectHarmonySources(project, manifest, output)
    let inputDigest = harmonyProjectionInputDigest(project, framework, manifest, sources)
    let receiptPath = joinPath(output, "canghui-harmony-projection-receipt.json")
    if (exists(output)) {
        if (!exists(receiptPath)) {
            throw CuicError("Harmony projection output already exists without a CangHui receipt: ${output}")
        }
        let existing = String.fromUtf8(File.readFrom(receiptPath))
        if (!containsText(existing, "\"inputDigest\":\"${inputDigest}\"")) {
            throw CuicError("Harmony projection source drift detected; review and remove the generated output before regenerating")
        }
        validateHarmonyGeneratedReceipt(existing, output)
        return existing
    }

    ensurePackagingDirectory(output)
    let generated = ArrayList<String>()
    for (source in sources) {
        let destination = joinPath(output, "cangjie/${source.relativePath}")
        writeHarmonyGeneratedFile(destination, source.content)
        generated.add("cangjie/${source.relativePath}")
    }
    copyHarmonyTemplates(framework, output, generated)
    copyHarmonyResources(project, manifest.resources, output, generated)
    let receipt = renderHarmonyProjectionReceipt(
        output, manifest, inputDigest, sources, generated.toArray())
    writeHarmonyGeneratedFile(receiptPath, receipt)
    receipt
}

func harmonyProjectionOutput(project: String, manifest: ApplicationManifest): String {
    let relative = if (manifest.harmonyOutput.isEmpty()) {".canghui/generated/harmony"}
        else {manifest.harmonyOutput}
    joinPath(project, relative)
}

private func collectHarmonySources(project: String, manifest: ApplicationManifest,
    output: String): Array<HarmonyProjectionSource> {
    let files = ArrayList<(String, String)>()
    let outputRelative = harmonyProjectRelative(project, output)
    for (rootRelative in manifest.harmonySourceRoots) {
        let root = joinPath(project, rootRelative)
        collectHarmonySourceTree(project, root, manifest.harmonyExclude, outputRelative, files)
    }
    let sorted = sortHarmonySourcePaths(files.toArray())
    let seen = HashSet<String>()
    let sources = ArrayList<HarmonyProjectionSource>()
    for ((relative, path) in sorted) {
        if (seen.contains(relative)) { throw CuicError("duplicate Harmony projection source: ${relative}") }
        seen.add(relative)
        if (FileInfo(path).isSymbolicLink()) {
            throw CuicError("Harmony projection source must not be a symbolic link: ${relative}")
        }
        let bytes = File.readFrom(path)
        if (bytes.size > HARMONY_PROJECTION_MAX_SOURCE_BYTES) {
            throw CuicError("Harmony projection source is too large: ${relative}")
        }
        var content = String.fromUtf8(bytes)
        for (rule in manifest.harmonyTransforms) { content = applyHarmonyTransform(content, rule) }
        sources.add(HarmonyProjectionSource(relative, path, content))
    }
    if (sources.isEmpty()) { throw CuicError("Harmony projection contains no Cangjie source") }
    sources.toArray()
}

private func collectHarmonySourceTree(project: String, path: String, excludes: Array<String>,
    outputRelative: String, output: ArrayList<(String, String)>): Unit {
    let relative = harmonyProjectRelative(project, path)
    if (harmonyPathExcluded(relative, excludes, outputRelative)) { return }
    if (FileInfo(path).isSymbolicLink()) {
        throw CuicError("Harmony projection source tree must not contain symbolic links: ${relative}")
    }
    if (packagingDirectoryExists(path)) {
        for (entry in Directory.readFrom(path)) {
            collectHarmonySourceTree(project, entry.path.toString(), excludes, outputRelative, output)
        }
    } else if (endsWithText(path, ".cj")) {
        output.add((relative, path))
    }
}

private func harmonyPathExcluded(relative: String, excludes: Array<String>, outputRelative: String): Bool {
    if (relative == outputRelative || startsWithText(relative, outputRelative + "/")) { return true }
    for (excluded in excludes) {
        let normalized = trimTrailingSlash(Path(excluded).normalize().toString())
        if (relative == normalized || startsWithText(relative, normalized + "/")) { return true }
    }
    false
}

private func applyHarmonyTransform(content: String, rule: String): String {
    validateHarmonyTransformRule(rule)
    let body = substringFrom(rule, Int64("replace:".toRuneArray().size))
    let separator = indexOfText(body, "=>")
    let source = substringTo(body, separator)
    let replacement = substringFrom(body, separator + 2)
    if (!content.contains(source)) {
        throw CuicError("reviewed Harmony transform source was not found: ${source}")
    }
    content.replace(source, replacement)
}

private func copyHarmonyTemplates(framework: String, output: String, generated: ArrayList<String>): Unit {
    let templateRoot = joinPath(framework, "platform/harmony/template")
    for (name in ["CangHuiHost.ets", "CangHuiTextInputHost.ets", "CangHuiAbilityHost.ets",
        "module.json5.fragment"]) {
        let source = joinPath(templateRoot, name)
        if (!exists(source)) { throw CuicError("CangHui Harmony host template is missing: ${source}") }
        let destination = joinPath(output, "host/${name}")
        copyPackagingFile(source, destination)
        generated.add("host/${name}")
    }
    let header = joinPath(framework, "platform/harmony/include/CangHuiHarmonyXComponentHost.h")
    copyPackagingFile(header, joinPath(output, "native/include/CangHuiHarmonyXComponentHost.h"))
    generated.add("native/include/CangHuiHarmonyXComponentHost.h")
}

private func copyHarmonyResources(project: String, resources: Array<String>, output: String,
    generated: ArrayList<String>): Unit {
    for (resource in resources) {
        let source = joinPath(project, resource)
        let destination = joinPath(output, "entry/src/main/resources/rawfile/${resource}")
        copyPackagingTree(source, destination)
        generated.add("entry/src/main/resources/rawfile/${resource}")
    }
}

private func harmonyProjectionInputDigest(project: String, framework: String,
    manifest: ApplicationManifest, sources: Array<HarmonyProjectionSource>): String {
    let value = StringBuilder()
    value.append(manifest.harmonyTargetPackage)
    value.append("|")
    for (rule in manifest.harmonyTransforms) { value.append(rule); value.append("|") }
    for (source in sources) {
        value.append(source.relativePath); value.append("="); value.append(source.digest); value.append("|")
    }
    for (resource in manifest.resources) {
        value.append("resource:"); value.append(resource); value.append("=")
        value.append(harmonyPathDigest(joinPath(project, resource))); value.append("|")
    }
    for (template in ["CangHuiHost.ets", "CangHuiTextInputHost.ets", "CangHuiAbilityHost.ets",
        "module.json5.fragment"]) {
        value.append("template:"); value.append(template); value.append("=")
        value.append(harmonyPathDigest(joinPath(framework, "platform/harmony/template/${template}")))
        value.append("|")
    }
    value.append("header=")
    value.append(harmonyPathDigest(joinPath(
        framework, "platform/harmony/include/CangHuiHarmonyXComponentHost.h")))
    harmonyStableDigest(value.toString())
}

private func renderHarmonyProjectionReceipt(output: String, manifest: ApplicationManifest,
    inputDigest: String, sources: Array<HarmonyProjectionSource>, generated: Array<String>): String {
    let out = StringBuilder()
    out.append("{\"protocol\":\""); out.append(HARMONY_PROJECTION_PROTOCOL)
    out.append("\",\"inputDigest\":\""); out.append(inputDigest)
    out.append("\",\"targetPackage\":"); out.append(cuicJsonQuote(manifest.harmonyTargetPackage))
    out.append(",\"sources\":[")
    var first = true
    for (source in sources) {
        if (!first) { out.append(",") }; first = false
        out.append("{\"path\":"); out.append(cuicJsonQuote(source.relativePath))
        out.append(",\"digest\":"); out.append(cuicJsonQuote(source.digest)); out.append("}")
    }
    out.append("],\"generated\":[")
    first = true
    for (path in generated) {
        if (!first) { out.append(",") }; first = false
        out.append(cuicJsonQuote(path))
    }
    out.append("],\"outputDigest\":")
    out.append(cuicJsonQuote(harmonyPathDigest(output)))
    out.append(",\"resourceMapping\":\"ApplicationResources.mobileRawfile\",")
    out.append("\"limitations\":[\"accessibility-actions-field-gated\",\"device-ime-field-gated\",")
    out.append("\"signing-and-product-permissions-owned-by-consumer\"]}")
    out.toString()
}

// Receipt validation is deliberately bounded: a same-input second run is a no-write replay. The
// generator never trusts a foreign directory merely because it happens to share the output name.
private func validateHarmonyGeneratedReceipt(receipt: String, output: String): Unit {
    if (!containsText(receipt, "\"protocol\":\"${HARMONY_PROJECTION_PROTOCOL}\"") ||
        !containsText(receipt, "\"generated\"")) {
        throw CuicError("Harmony projection receipt is invalid: ${output}")
    }
    let digest = harmonyPathDigest(output)
    if (!containsText(receipt, "\"outputDigest\":\"${digest}\"")) {
        throw CuicError("Harmony projection output drift detected; generated files require review")
    }
}

private func writeHarmonyGeneratedFile(path: String, content: String): Unit {
    if (exists(path)) { throw CuicError("Harmony generator refuses to overwrite: ${path}") }
    let parent = parentPath(path)
    if (!parent.isEmpty()) { ensurePackagingDirectory(parent) }
    File.writeTo(path, content.toArray())
}

private func ensureHarmonyOutputInsideProject(project: String, output: String): Unit {
    let root = canonicalPackagingPath(project, "project")
    let candidate = canonicalPackagingPathIfExists(output, "Harmony projection output")
    if (candidate != root && !startsWithText(candidate, root + "/")) {
        throw CuicError("Harmony projection output must stay inside the project")
    }
    if (exists(output) && FileInfo(output).isSymbolicLink()) {
        throw CuicError("Harmony projection output must not be a symbolic link")
    }
}

private func harmonyProjectRelative(project: String, path: String): String {
    let root = trimTrailingSlash(Path(project).normalize().toString())
    let normalized = Path(path).normalize().toString()
    if (normalized == root) { return "." }
    if (!startsWithText(normalized, root + "/")) {
        throw CuicError("Harmony projection path escapes the project: ${path}")
    }
    substringFrom(normalized, Int64((root + "/").toRuneArray().size))
}

private func sortHarmonySourcePaths(values: Array<(String, String)>): Array<(String, String)> {
    let result = values.clone()
    var i: Int64 = 1
    while (i < result.size) {
        let value = result[i]
        var j = i
        while (j > 0 && result[j - 1][0] > value[0]) { result[j] = result[j - 1]; j -= 1 }
        result[j] = value; i += 1
    }
    result
}

private func harmonyStableDigest(value: String): String {
    var code: Int64 = 71
    for (byte in value.toArray()) { code = (code * 131 + Int64(byte)) % 2147483647 }
    "chui-harmony-v1:${value.toArray().size}:${max(Int64(1), code)}"
}

private func harmonyPathDigest(path: String): String {
    let files = ArrayList<(String, String)>()
    collectHarmonyDigestFiles(path, path, files)
    let sorted = sortHarmonySourcePaths(files.toArray())
    let value = StringBuilder()
    for ((relative, file) in sorted) {
        if (relative == "canghui-harmony-projection-receipt.json") { continue }
        value.append(relative); value.append("=")
        value.append(harmonyByteDigest(File.readFrom(file))); value.append("|")
    }
    harmonyStableDigest(value.toString())
}

private func collectHarmonyDigestFiles(root: String, path: String,
    output: ArrayList<(String, String)>): Unit {
    if (!exists(path)) { throw CuicError("Harmony projection input is missing: ${path}") }
    if (FileInfo(path).isSymbolicLink()) {
        throw CuicError("Harmony projection tree must not contain symbolic links: ${path}")
    }
    if (packagingDirectoryExists(path)) {
        for (entry in Directory.readFrom(path)) {
            collectHarmonyDigestFiles(root, entry.path.toString(), output)
        }
        return
    }
    let normalizedRoot = trimTrailingSlash(Path(root).normalize().toString())
    let normalizedPath = Path(path).normalize().toString()
    let relative = if (normalizedPath == normalizedRoot) { basename(path) }
        else { substringFrom(normalizedPath, Int64((normalizedRoot + "/").toRuneArray().size)) }
    output.add((relative, path))
}

private func harmonyByteDigest(bytes: Array<UInt8>): String {
    var code: Int64 = 71
    for (byte in bytes) { code = (code * 131 + Int64(byte)) % 2147483647 }
    "chui-harmony-bytes-v1:${bytes.size}:${max(Int64(1), code)}"
}

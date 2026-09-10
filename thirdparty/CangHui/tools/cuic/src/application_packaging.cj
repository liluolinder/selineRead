package cuic

import std.collection.ArrayList
import std.fs.{Directory, File, FileInfo, OpenMode, Path, canonicalize, exists, removeIfExists}

let PACKAGING_ARTIFACT_SCHEMA = "canghui.packaging-artifact.v0"

class ApplicationPackagingArtifactReceipt {
    let platform: String
    let artifactKind: String
    let manifest: ApplicationManifest
    let generatedFiles: Array<String>
    let copiedAssets: Array<String>
    let executableIncluded: Bool
    let signed: Bool
    let hostReplay: String
    let limitations: Array<String>

    init(platform: String, artifactKind: String, manifest: ApplicationManifest,
        generatedFiles: Array<String>, copiedAssets: Array<String>, executableIncluded: Bool,
        signed: Bool, hostReplay: String, limitations: Array<String>) {
        this.platform = platform
        this.artifactKind = artifactKind
        this.manifest = manifest
        this.generatedFiles = generatedFiles
        this.copiedAssets = copiedAssets
        this.executableIncluded = executableIncluded
        this.signed = signed
        this.hostReplay = hostReplay
        this.limitations = limitations
    }
}

func buildApplicationArtifact(project: String, platform: String, requestedOutput: String, json: Bool): Int64 {
    let manifest = loadApplicationManifest(project)
    let output = resolvePackagingOutputRoot(project, platform, manifest, requestedOutput)
    ensurePackagingDestinationAvailable(output)
    ensurePackagingOutputDoesNotOverlapInputs(project, output, manifest)

    var executable = ""
    var hostReplay = "metadata-only"
    let limitations = ArrayList<String>()
    let plan = applicationPackagingPlanForManifest(project, platform, manifest)
    for (value in plan.unsupportedCapabilities) { limitations.add(value) }
    if (platform == "macos" && hostPlatform() == "macos") {
        let buildCode = runMacPackagingBuild(project, json)
        if (buildCode != 0) { return buildCode }
        let framework = ensureFrameworkRoot(project)
        let context = ExecutionContext(project, framework)
        executable = builtExecutable(context.targetDir)
        hostReplay = "same-host-build-complete-not-launched"
        limitations.add("runtime-dependencies-remain-host-managed")
    } else if (platform != hostPlatform()) {
        limitations.add("target-host-build-not-run-on-${hostPlatform()}")
        limitations.add("executable-and-native-runtime-not-included")
    } else {
        limitations.add("platform-runtime-packaging-is-separate-from-this-input-tree")
        limitations.add("executable-and-native-runtime-not-included")
    }
    limitations.add("release-trimpath-and-strip-not-verified")
    limitations.add("release-security-audit-not-run")
    limitations.add("publisher-signing-and-notarization-not-run")
    limitations.add("unsigned-artifact")

    let receipt = writeApplicationPackagingArtifact(
        project, platform, manifest, output, executable, hostReplay, limitations.toArray()
    )
    let receiptPath = joinPath(output, applicationPackagingReceiptPath(platform))
    File.writeTo(receiptPath, renderApplicationPackagingReceiptJson(receipt).toArray())
    if (json) {
        println(renderApplicationPackagingReceiptJson(receipt))
    } else {
        renderApplicationPackagingReceipt(receipt, output)
    }
    0
}

func applicationPackagingReceiptPath(platform: String): String {
    if (platform == "macos") {
        "Contents/Resources/canghui-packaging-receipt.json"
    } else {
        "canghui-packaging-receipt.json"
    }
}

func runMacPackagingBuild(project: String, quiet: Bool): Int64 {
    let framework = ensureFrameworkRoot(project)
    let context = ExecutionContext(project, framework)
    let diffCode = runKModeDiff(project, quiet: true)
    if (diffCode != 0) { return diffCode }
    let probeDiffCode = runProbeDiff(project, quiet: true)
    if (probeDiffCode != 0) { return probeDiffCode }
    let boot = bootstrapMacPackaging(context.stagingRoot, quiet)
    if (boot != 0) { return boot }
    let lease = context.acquireLease()
    try {
        if (!quiet) { println("==> cjpm build (macos) in ${project}") }
        if (quiet) { executeCjpmQuiet(context, ["build"]) } else { executeCjpm(context, ["build"]) }
    } finally {
        context.releaseLease(lease)
    }
}

func bootstrapMacPackaging(stagingRoot: String, quiet: Bool): Int64 {
    let sdlDirectory = joinPath(stagingRoot, "sdl/.sdl3")
    ensurePackagingDirectory(sdlDirectory)
    let sdl3 = homebrewLibrary("sdl3", "libSDL3.dylib")
    let sdl3Ttf = homebrewLibrary("sdl3_ttf", "libSDL3_ttf.dylib")
    copyNativeLibrary(sdl3, joinPath(sdlDirectory, "libSDL3.dylib"))
    copyNativeLibrary(sdl3Ttf, joinPath(sdlDirectory, "libSDL3_ttf.dylib"))
    if (!quiet) { println("macos SDL libraries are ready in ${sdlDirectory}") }
    0
}

func resolvePackagingOutputRoot(project: String, platform: String, manifest: ApplicationManifest,
    requested: String): String {
    let artifactName = if (platform == "macos") { manifest.name + ".app" } else { manifest.name }
    let relative = if (requested.isEmpty()) { "dist/${artifactName}" } else { requested }
    validateManifestRelativePath(relative, "output")
    let projectRoot = Path(project).normalize().toString()
    let output = Path(joinPath(projectRoot, relative)).normalize().toString()
    if (output == projectRoot || !startsWithText(output, projectRoot + "/")) {
        throw CuicError("package output must remain inside the project: ${relative}")
    }
    ensurePackagingPathStaysInsideProject(projectRoot, output, "package output")
    output
}

func ensurePackagingDestinationAvailable(output: String): Unit {
    if (!exists(output)) { return }
    try {
        if (FileInfo(output).isSymbolicLink()) {
            throw CuicError("package output must not be a symbolic link: ${output}")
        }
    } catch (e: CuicError) {
        throw e
    } catch (_: Exception) {
        throw CuicError("package output is not a readable directory: ${output}")
    }
    try {
        for (_ in Directory.readFrom(output)) {
            throw CuicError("package output is not empty: ${output}")
        }
    } catch (e: CuicError) {
        throw e
    } catch (_: Exception) {
        throw CuicError("package output is not a writable directory: ${output}")
    }
}

func ensurePackagingOutputDoesNotOverlapInputs(project: String, output: String,
    manifest: ApplicationManifest): Unit {
    let projectRoot = canonicalPackagingPath(project, "project")
    ensurePackagingPathStaysInsideProject(projectRoot, output, "package output")
    let normalizedOutput = canonicalPackagingPathIfExists(output, "package output")
    for (resource in manifest.resources) {
        let source = Path(joinPath(project, resource)).normalize().toString()
        let canonicalSource = canonicalPackagingPath(source, "declared resource")
        if (packagingDirectoryExists(source) &&
            (normalizedOutput == canonicalSource || startsWithText(normalizedOutput, canonicalSource + "/"))) {
            throw CuicError("package output must not be nested inside declared resource: ${resource}")
        }
    }
}

func canonicalPackagingPath(path: String, role: String): String {
    try {
        canonicalize(path).toString()
    } catch (_: Exception) {
        throw CuicError("${role} path cannot be resolved: ${path}")
    }
}

func canonicalPackagingPathIfExists(path: String, role: String): String {
    if (exists(path)) { return canonicalPackagingPath(path, role) }
    var current = path
    while (!exists(current)) {
        let parent = parentPath(current)
        if (parent.isEmpty() || parent == current) {
            throw CuicError("${role} parent path cannot be resolved: ${path}")
        }
        current = parent
    }
    canonicalPackagingPath(current, role)
}

func ensurePackagingPathStaysInsideProject(projectRoot: String, path: String, role: String): Unit {
    let canonicalProject = canonicalPackagingPath(projectRoot, "project")
    let canonicalCandidate = canonicalPackagingPathIfExists(path, role)
    if (canonicalCandidate != canonicalProject &&
        !startsWithText(canonicalCandidate, canonicalProject + "/")) {
        throw CuicError("${role} must remain inside the project: ${path}")
    }
}

func ensurePackagingInputTreeStaysInsideProject(
    projectRoot: String,
    path: String,
    role: String
): Unit {
    if (FileInfo(path).isSymbolicLink()) {
        throw CuicError("${role} must not contain symbolic links: ${path}")
    }
    ensurePackagingPathStaysInsideProject(projectRoot, path, role)
    if (!packagingDirectoryExists(path)) { return }
    for (entry in Directory.readFrom(path)) {
        ensurePackagingInputTreeStaysInsideProject(
            projectRoot, entry.path.toString(), role)
    }
}

func writeApplicationPackagingArtifact(project: String, platform: String,
    manifest: ApplicationManifest, output: String, executable: String,
    hostReplay: String, limitations: Array<String>): ApplicationPackagingArtifactReceipt {
    ensurePackagingDirectory(output)
    let generated = ArrayList<String>()
    let copied = ArrayList<String>()
    var executableIncluded = false
    if (platform == "macos") {
        executableIncluded = writeMacApplicationArtifact(
            project, manifest, output, executable, generated, copied
        )
    } else if (platform == "windows") {
        copyWindowsApplicationArtifact(project, manifest, output, generated, copied)
    } else {
        writeLinuxApplicationArtifact(project, manifest, output, generated, copied)
    }
    generated.add(applicationPackagingReceiptPath(platform))
    ApplicationPackagingArtifactReceipt(
        platform, packagingArtifactKind(platform), manifest, generated.toArray(), copied.toArray(),
        executableIncluded, false, hostReplay, limitations
    )
}

func writeMacApplicationArtifact(project: String, manifest: ApplicationManifest, output: String,
    executable: String, generated: ArrayList<String>, copied: ArrayList<String>): Bool {
    let contents = joinPath(output, "Contents")
    let resources = joinPath(contents, "Resources")
    ensurePackagingDirectory(joinPath(contents, "MacOS"))
    ensurePackagingDirectory(joinPath(resources, "assets"))

    let iconDestination = copyMacIcon(project, manifest.applicationIcon, resources, copied)
    let info = macInfoPlist(manifest, iconDestination)
    writePackagingFile(output, "Contents/Info.plist", info, generated)
    writePackagingFile(output, "Contents/PkgInfo", "APPL????\n", generated)
    copyMacSystemAssets(project, manifest, resources, copied)
    copyMacResources(project, manifest.resources, joinPath(resources, "assets"), copied)
    if (!executable.isEmpty()) {
        let destination = joinPath(contents, "MacOS/${manifest.name}")
        copyPackagingFile(executable, destination)
        let chmod = executeCommand("chmod", ["+x", destination], output)
        if (chmod != 0) { throw CuicError("cannot mark macOS application executable: ${destination}") }
        generated.add("Contents/MacOS/${manifest.name}")
        return true
    }
    false
}

func copyMacIcon(project: String, sourcePath: String, resources: String, copied: ArrayList<String>): String {
    if (sourcePath.isEmpty()) { return "" }
    let source = joinPath(project, sourcePath)
    if (packagingDirectoryExists(source)) { throw CuicError("application icon must be a file: ${sourcePath}") }
    let extension = packagingExtension(sourcePath)
    let name = if (extension == "icns") { "application.icns" } else { packagingNameWithExtension("application-icon", extension) }
    let destination = joinPath(resources, name)
    copyPackagingFile(source, destination)
    copied.add("${sourcePath} -> Contents/Resources/${name}")
    destination
}

func macInfoPlist(manifest: ApplicationManifest, iconDestination: String): String {
    let icon = if (endsWithText(iconDestination, "/application.icns")) {
        "    <key>CFBundleIconFile</key>\n    <string>application.icns</string>\n"
    } else { "" }
    "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n" +
    "<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">\n" +
    "<plist version=\"1.0\"><dict>\n" +
    "    <key>CFBundleDisplayName</key><string>${packageXmlEscape(manifest.name)}</string>\n" +
    "    <key>CFBundleExecutable</key><string>${packageXmlEscape(manifest.name)}</string>\n" +
    "    <key>CFBundleIdentifier</key><string>${packageXmlEscape(manifest.identifier)}</string>\n" +
    "    <key>CFBundleName</key><string>${packageXmlEscape(manifest.name)}</string>\n" +
    "    <key>CFBundlePackageType</key><string>APPL</string>\n" +
    "    <key>CFBundleShortVersionString</key><string>${packageXmlEscape(manifest.version)}</string>\n" +
    "    <key>CFBundleVersion</key><string>${packageXmlEscape(manifest.version)}</string>\n" +
    icon +
    "</dict></plist>\n"
}

func copyMacSystemAssets(project: String, manifest: ApplicationManifest, resources: String,
    copied: ArrayList<String>): Unit {
    let destination = joinPath(resources, "assets/system-icons")
    copyRoleAsset(project, manifest.statusItemIcon, destination, "status-item-icon", copied,
        "Contents/Resources/assets/system-icons")
    copyRoleAsset(project, manifest.notificationIcon, destination, "notification-icon", copied,
        "Contents/Resources/assets/system-icons")
    copyRoleAsset(project, manifest.documentIcon, destination, "document-icon", copied,
        "Contents/Resources/assets/system-icons")
    copyRoleAsset(project, manifest.monochromeIcon, destination, "monochrome-icon", copied,
        "Contents/Resources/assets/system-icons")
}

func copyWindowsApplicationArtifact(project: String, manifest: ApplicationManifest, output: String,
    generated: ArrayList<String>, copied: ArrayList<String>): Unit {
    copyWindowsIcon(project, manifest.applicationIcon, output, manifest.name, copied)
    writePackagingFile(output, "${manifest.name}.exe.manifest", windowsManifest(manifest), generated)
    writePackagingFile(output, "${manifest.name}.version.rc", windowsVersionResource(manifest), generated)
    writePackagingFile(output, "AppUserModelID.txt", manifest.identifier + "\n", generated)
    copyRoleAsset(project, manifest.statusItemIcon, joinPath(output, "assets/system-icons"),
        "status-item-icon", copied, "assets/system-icons")
    copyRoleAsset(project, manifest.notificationIcon, joinPath(output, "assets/system-icons"),
        "notification-icon", copied, "assets/system-icons")
    copyRoleAsset(project, manifest.documentIcon, joinPath(output, "assets/system-icons"),
        "document-icon", copied, "assets/system-icons")
    copyRoleAsset(project, manifest.monochromeIcon, joinPath(output, "assets/system-icons"),
        "monochrome-icon", copied, "assets/system-icons")
    copyPackagingResources(project, manifest.resources, joinPath(output, "assets"), copied, "assets")
}

func copyWindowsIcon(project: String, sourcePath: String, output: String, applicationName: String,
    copied: ArrayList<String>): String {
    if (sourcePath.isEmpty()) { return "" }
    let source = joinPath(project, sourcePath)
    if (packagingDirectoryExists(source)) { throw CuicError("application icon must be a file: ${sourcePath}") }
    let extension = packagingExtension(sourcePath)
    let name = if (extension == "ico") { "${applicationName}.ico" } else {
        packagingNameWithExtension("${applicationName}.icon", extension)
    }
    copyPackagingFile(source, joinPath(output, name))
    copied.add("${sourcePath} -> ${name}")
    name
}

func windowsManifest(manifest: ApplicationManifest): String {
    "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n" +
    "<assembly xmlns=\"urn:schemas-microsoft-com:asm.v1\" manifestVersion=\"1.0\">\n" +
    "  <description>${packageXmlEscape(manifest.name)}</description>\n" +
    "  <dependency>\n" +
    "    <dependentAssembly>\n" +
    "      <assemblyIdentity type=\"win32\" name=\"Microsoft.Windows.Common-Controls\" " +
        "version=\"6.0.0.0\" processorArchitecture=\"*\" publicKeyToken=\"6595b64144ccf1df\" language=\"*\"/>\n" +
    "    </dependentAssembly>\n" +
    "  </dependency>\n" +
    "  <trustInfo xmlns=\"urn:schemas-microsoft-com:asm.v3\"><security><requestedPrivileges>\n" +
    "    <requestedExecutionLevel level=\"asInvoker\" uiAccess=\"false\"/>\n" +
    "  </requestedPrivileges></security></trustInfo>\n" +
    "</assembly>\n"
}

func windowsVersionResource(manifest: ApplicationManifest): String {
    let version = windowsVersionTuple(manifest.version)
    "#include <winver.h>\n\n" +
    "VS_VERSION_INFO VERSIONINFO\n" +
    " FILEVERSION ${version}\n PRODUCTVERSION ${version}\n" +
    " FILEFLAGSMASK 0x3fL\n FILEFLAGS 0x0L\n FILEOS 0x40004L\n FILETYPE 0x1L\n FILESUBTYPE 0x0L\nBEGIN\n" +
    " BLOCK \"StringFileInfo\"\n BEGIN\n  BLOCK \"040904B0\"\n  BEGIN\n" +
    "   VALUE \"CompanyName\", \"${windowsResourceEscape(manifest.publisher)}\\0\"\n" +
    "   VALUE \"FileDescription\", \"${windowsResourceEscape(manifest.name)}\\0\"\n" +
    "   VALUE \"FileVersion\", \"${windowsResourceEscape(manifest.version)}\\0\"\n" +
    "   VALUE \"InternalName\", \"${windowsResourceEscape(manifest.name)}\\0\"\n" +
    "   VALUE \"OriginalFilename\", \"${windowsResourceEscape(manifest.name)}.exe\\0\"\n" +
    "   VALUE \"ProductName\", \"${windowsResourceEscape(manifest.name)}\\0\"\n" +
    "   VALUE \"ProductVersion\", \"${windowsResourceEscape(manifest.version)}\\0\"\n" +
    "  END\n END\n" +
    " BLOCK \"VarFileInfo\"\n BEGIN\n  VALUE \"Translation\", 0x409, 1200\n END\nEND\n"
}

func windowsVersionTuple(value: String): String {
    let parts = value.split(".")
    let numbers = ArrayList<String>()
    for (part in parts) {
        var numeric = true
        if (part.isEmpty()) { numeric = false }
        for (r in part.toRuneArray()) {
            if (r < r'0' || r > r'9') { numeric = false }
        }
        numbers.add(if (numeric) { part } else { "0" })
    }
    while (numbers.size < 4) { numbers.add("0") }
    if (numbers.size > 4) { return "0,0,0,0" }
    joinStrings(numbers.toArray(), ",")
}

func writeLinuxApplicationArtifact(project: String, manifest: ApplicationManifest, output: String,
    generated: ArrayList<String>, copied: ArrayList<String>): Unit {
    let desktop = linuxDesktopEntry(manifest)
    writePackagingFile(output, "${manifest.name}.desktop", desktop, generated)
    writePackagingFile(output, "share/applications/${manifest.identifier}.desktop", desktop, generated)
    if (!manifest.applicationIcon.isEmpty()) {
        let source = joinPath(project, manifest.applicationIcon)
        if (packagingDirectoryExists(source)) { throw CuicError("application icon must be a file: ${manifest.applicationIcon}") }
        let extension = packagingExtension(manifest.applicationIcon)
        let destination = "share/icons/hicolor/128x128/apps/${manifest.identifier}${if (extension.isEmpty()) { "" } else { ".${extension}" }}"
        copyPackagingFile(source, joinPath(output, destination))
        copied.add("${manifest.applicationIcon} -> ${destination}")
    }
    copyRoleAsset(project, manifest.statusItemIcon, joinPath(output, "share/${manifest.identifier}/icons"),
        "status-item-icon", copied, "share/${manifest.identifier}/icons")
    copyRoleAsset(project, manifest.notificationIcon, joinPath(output, "share/${manifest.identifier}/icons"),
        "notification-icon", copied, "share/${manifest.identifier}/icons")
    copyRoleAsset(project, manifest.documentIcon, joinPath(output, "share/${manifest.identifier}/icons"),
        "document-icon", copied, "share/${manifest.identifier}/icons")
    copyRoleAsset(project, manifest.monochromeIcon, joinPath(output, "share/${manifest.identifier}/icons"),
        "monochrome-icon", copied, "share/${manifest.identifier}/icons")
    copyPackagingResources(project, manifest.resources,
        joinPath(output, "share/${manifest.identifier}/resources"), copied,
        "share/${manifest.identifier}/resources")
}

func linuxDesktopEntry(manifest: ApplicationManifest): String {
    "[Desktop Entry]\n" +
    "Type=Application\n" +
    "Name=${desktopEscape(manifest.name)}\n" +
    "Comment=${desktopEscape(manifest.publisher)}\n" +
    "Exec=\"${desktopEscape(manifest.name)}\"\n" +
    "Icon=${manifest.identifier}\n" +
    "Terminal=false\n" +
    "StartupNotify=true\n" +
    "StartupWMClass=${manifest.identifier}\n" +
    "Categories=Utility;\n"
}

func copyMacResources(project: String, resources: Array<String>, destinationRoot: String,
    copied: ArrayList<String>): Unit {
    copyPackagingResources(project, resources, destinationRoot, copied, "Contents/Resources/assets")
}

func copyPackagingResources(project: String, resources: Array<String>, destinationRoot: String,
    copied: ArrayList<String>, receiptPrefix: String): Unit {
    for (resource in resources) {
        let source = joinPath(project, resource)
        let destination = joinPath(destinationRoot, resource)
        copyPackagingTree(source, destination)
        copied.add("${resource} -> ${receiptPrefix}/${resource}")
    }
}

func copyRoleAsset(project: String, sourcePath: String, destinationRoot: String, role: String,
    copied: ArrayList<String>, receiptPrefix: String): Unit {
    if (sourcePath.isEmpty()) { return }
    let source = joinPath(project, sourcePath)
    if (packagingDirectoryExists(source)) { throw CuicError("${role} must be a file: ${sourcePath}") }
    let extension = packagingExtension(sourcePath)
    let name = packagingNameWithExtension(role, extension)
    copyPackagingFile(source, joinPath(destinationRoot, name))
    copied.add("${sourcePath} -> ${receiptPrefix}/${name}")
}

func copyPackagingTree(source: String, destination: String): Unit {
    if (packagingDirectoryExists(source)) {
        ensurePackagingDirectory(destination)
        for (entry in Directory.readFrom(source)) {
            let childSource = entry.path.toString()
            let childDestination = joinPath(destination, basename(childSource))
            if (entry.isDirectory()) {
                copyPackagingTree(childSource, childDestination)
            } else {
                copyPackagingFile(childSource, childDestination)
            }
        }
        return
    }
    copyPackagingFile(source, destination)
}

func packagingDirectoryExists(path: String): Bool {
    if (!exists(path)) { return false }
    try {
        let _ = Directory.readFrom(path)
        true
    } catch (_: Exception) {
        false
    }
}

func copyPackagingFile(source: String, destination: String): Unit {
    if (!exists(source)) { throw CuicError("packaging input is missing: ${source}") }
    if (FileInfo(source).isSymbolicLink()) {
        throw CuicError("packaging input must not be a symbolic link: ${source}")
    }
    if (exists(destination)) {
        throw CuicError("packaging destination already exists: ${destination}")
    }
    let parent = parentPath(destination)
    if (!parent.isEmpty()) { ensurePackagingDirectory(parent) }
    try {
        let input = File(source, OpenMode.Read)
        try {
            let output = File(destination, OpenMode.Write)
            try {
                let buffer = Array<UInt8>(65536, repeat: 0)
                while (true) {
                    let count = input.read(buffer)
                    if (count <= 0) { break }
                    if (count == buffer.size) {
                        output.write(buffer)
                    } else {
                        let tail = Array<UInt8>(count, repeat: 0)
                        for (i in 0..count) { tail[i] = buffer[i] }
                        output.write(tail)
                    }
                }
            } finally {
                output.close()
            }
        } finally {
            input.close()
        }
    } catch (_: Exception) {
        removeIfExists(destination)
        throw CuicError("cannot copy packaging input without replacing an existing file: ${destination}")
    }
}

func writePackagingFile(root: String, relative: String, content: String,
    generated: ArrayList<String>): Unit {
    let destination = joinPath(root, relative)
    let parent = parentPath(destination)
    if (!parent.isEmpty()) { ensurePackagingDirectory(parent) }
    File.writeTo(destination, content.toArray())
    generated.add(relative)
}

func packagingArtifactKind(platform: String): String {
    if (platform == "macos") { return "macos-unsigned-app-bundle" }
    if (platform == "windows") { return "windows-unsigned-resource-input-tree" }
    "linux-unsigned-desktop-input-tree"
}

func ensurePackagingDirectory(path: String): Unit {
    if (!exists(path)) { Directory.create(path, recursive: true) }
}

func packagingExtension(path: String): String {
    let name = basename(path)
    let runes = name.toRuneArray()
    var dot: Int64 = -1
    var i: Int64 = 0
    while (i < runes.size) {
        if (runes[i] == r'.') { dot = i }
        i += 1
    }
    if (dot <= 0 || dot + 1 >= runes.size) { return "" }
    asciiLowerText(substringFrom(name, dot + 1))
}

func packagingNameWithExtension(prefix: String, extension: String): String {
    if (extension.isEmpty()) { return prefix }
    prefix + "." + extension
}

func packageXmlEscape(value: String): String {
    let out = StringBuilder()
    for (r in value.toRuneArray()) {
        if (r == r'&') { out.append("&amp;") }
        else if (r == r'<') { out.append("&lt;") }
        else if (r == r'>') { out.append("&gt;") }
        else if (r == r'\"') { out.append("&quot;") }
        else if (r == r'\'') { out.append("&apos;") }
        else { out.append(r.toString()) }
    }
    out.toString()
}

func windowsResourceEscape(value: String): String {
    let out = StringBuilder()
    for (r in value.toRuneArray()) {
        if (r == r'\"') { out.append("\\\"") }
        else if (r == r'\\') { out.append("\\\\") }
        else if (r == r'\n' || r == r'\r') { out.append(" ") }
        else { out.append(r.toString()) }
    }
    out.toString()
}

func desktopEscape(value: String): String {
    let out = StringBuilder()
    for (r in value.toRuneArray()) {
        if (r == r'\\') { out.append("\\\\") }
        else if (r == r'\n' || r == r'\r') { out.append(" ") }
        else { out.append(r.toString()) }
    }
    out.toString()
}

func renderApplicationPackagingReceipt(receipt: ApplicationPackagingArtifactReceipt, output: String): Unit {
    println("CangHui packaging artifact (${PACKAGING_ARTIFACT_SCHEMA})")
    println("Platform: ${receipt.platform}")
    println("Artifact: ${output}")
    println("Kind: ${receipt.artifactKind}")
    println("Executable included: ${receipt.executableIncluded}")
    println("Signed: ${receipt.signed}")
    println("Host replay: ${receipt.hostReplay}")
    renderPlanList("Generated files", receipt.generatedFiles)
    renderPlanList("Copied assets", receipt.copiedAssets)
    renderPlanList("Limitations", receipt.limitations)
}

func renderApplicationPackagingReceiptJson(receipt: ApplicationPackagingArtifactReceipt): String {
    let out = StringBuilder()
    out.append("{\"schema\":")
    out.append(cuicJsonQuote(PACKAGING_ARTIFACT_SCHEMA))
    out.append(",\"platform\":")
    out.append(cuicJsonQuote(receipt.platform))
    out.append(",\"artifactKind\":")
    out.append(cuicJsonQuote(receipt.artifactKind))
    out.append(",\"identity\":{\"name\":")
    out.append(cuicJsonQuote(receipt.manifest.name))
    out.append(",\"identifier\":")
    out.append(cuicJsonQuote(receipt.manifest.identifier))
    out.append(",\"version\":")
    out.append(cuicJsonQuote(receipt.manifest.version))
    out.append(",\"publisher\":")
    out.append(cuicJsonQuote(receipt.manifest.publisher))
    out.append("}")
    out.append(",\"generatedFiles\":")
    appendApplicationPlanArray(out, receipt.generatedFiles)
    out.append(",\"copiedAssets\":")
    appendApplicationPlanArray(out, receipt.copiedAssets)
    out.append(",\"executableIncluded\":")
    out.append(receipt.executableIncluded.toString())
    out.append(",\"signed\":false")
    out.append(",\"hostReplay\":")
    out.append(cuicJsonQuote(receipt.hostReplay))
    out.append(",\"limitations\":")
    appendApplicationPlanArray(out, receipt.limitations)
    out.append("}")
    out.toString()
}

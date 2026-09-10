package cuic

import std.collection.ArrayList
import std.fs.{File, exists}

let APPLICATION_MANIFEST_FILE = "canghui.toml"
let PACKAGING_PLAN_SCHEMA = "canghui.packaging-plan.v0"

class ApplicationManifest {
    let name: String
    let identifier: String
    let version: String
    let publisher: String
    let applicationIcon: String
    let statusItemIcon: String
    let notificationIcon: String
    let documentIcon: String
    let monochromeIcon: String
    let resources: Array<String>
    let singleInstance: Bool
    let statusItem: Bool
    let notifications: Bool
    let settings: Bool
    let harmonySourceRoots: Array<String>
    let harmonyExclude: Array<String>
    let harmonyTargetPackage: String
    let harmonyOutput: String
    let harmonyTransforms: Array<String>

    init(name: String, identifier: String, version: String, publisher: String,
        applicationIcon: String, statusItemIcon: String, notificationIcon: String,
        documentIcon: String, monochromeIcon: String, resources: Array<String>,
        singleInstance: Bool, statusItem: Bool, notifications: Bool, settings: Bool,
        harmonySourceRoots!: Array<String> = [], harmonyExclude!: Array<String> = [],
        harmonyTargetPackage!: String = "", harmonyOutput!: String = "",
        harmonyTransforms!: Array<String> = []) {
        this.name = name
        this.identifier = identifier
        this.version = version
        this.publisher = publisher
        this.applicationIcon = applicationIcon
        this.statusItemIcon = statusItemIcon
        this.notificationIcon = notificationIcon
        this.documentIcon = documentIcon
        this.monochromeIcon = monochromeIcon
        this.resources = resources
        this.singleInstance = singleInstance
        this.statusItem = statusItem
        this.notifications = notifications
        this.settings = settings
        this.harmonySourceRoots = harmonySourceRoots
        this.harmonyExclude = harmonyExclude
        this.harmonyTargetPackage = harmonyTargetPackage
        this.harmonyOutput = harmonyOutput
        this.harmonyTransforms = harmonyTransforms
    }
}

class ApplicationPackagingPlan {
    let platform: String
    let project: String
    let manifest: ApplicationManifest
    let inputAssets: Array<String>
    let generatedFiles: Array<String>
    let nativeProviderState: Array<String>
    let unsupportedCapabilities: Array<String>
    let signingRequired: Bool

    init(platform: String, project: String, manifest: ApplicationManifest,
        inputAssets: Array<String>, generatedFiles: Array<String>,
        nativeProviderState: Array<String>, unsupportedCapabilities: Array<String>,
        signingRequired: Bool) {
        this.platform = platform
        this.project = project
        this.manifest = manifest
        this.inputAssets = inputAssets
        this.generatedFiles = generatedFiles
        this.nativeProviderState = nativeProviderState
        this.unsupportedCapabilities = unsupportedCapabilities
        this.signingRequired = signingRequired
    }
}

func applicationPackagingCommand(args: Array<String>, start: Int64): Int64 {
    if (start >= args.size) { throw CuicError("package requires 'plan' or 'build'") }
    if (args[start] == "build") { return applicationPackagingBuildCommand(args, start + 1) }
    if (args[start] != "plan") { throw CuicError("package supports only 'plan' or 'build'") }
    var platform = hostPlatform()
    var requested = ""
    var json = false
    var platformSet = false
    var i = start + 1
    while (i < args.size) {
        let value = args[i]
        if (value == "--json") { json = true; i += 1; continue }
        if (startsWithText(value, "-")) { throw CuicError("unknown package option '${value}'") }
        if (!platformSet && isPlatform(value)) {
            platform = normalizePlatform(value)
            platformSet = true
            i += 1
            continue
        }
        if (!requested.isEmpty()) { throw CuicError("package plan accepts one project") }
        requested = value
        i += 1
    }
    if (platform != "macos" && platform != "windows" && platform != "linux") {
        throw CuicError("package plan currently supports macos, windows and linux")
    }
    let project = resolveProject(requested, "")
    let plan = buildApplicationPackagingPlan(project, platform)
    if (json) {
        println(renderApplicationPackagingPlanJson(plan))
    } else {
        renderApplicationPackagingPlan(plan)
    }
    0
}

func applicationPackagingBuildCommand(args: Array<String>, start: Int64): Int64 {
    var platform = hostPlatform()
    var requested = ""
    var output = ""
    var json = false
    var platformSet = false
    var i = start
    while (i < args.size) {
        let value = args[i]
        if (value == "--json") { json = true; i += 1; continue }
        if (value == "--output") {
            if (i + 1 >= args.size || startsWithText(args[i + 1], "-")) {
                throw CuicError("--output requires a project-relative directory")
            }
            output = args[i + 1]
            i += 2
            continue
        }
        if (startsWithText(value, "-")) { throw CuicError("unknown package build option '${value}'") }
        if (!platformSet && isPlatform(value)) {
            platform = normalizePlatform(value)
            platformSet = true
            i += 1
            continue
        }
        if (!requested.isEmpty()) { throw CuicError("package build accepts one project") }
        requested = value
        i += 1
    }
    if (platform != "macos" && platform != "windows" && platform != "linux") {
        throw CuicError("package build currently supports macos, windows and linux")
    }
    let project = resolveProject(requested, "")
    buildApplicationArtifact(project, platform, output, json)
}

func loadApplicationManifest(project: String): ApplicationManifest {
    let path = joinPath(project, APPLICATION_MANIFEST_FILE)
    requireFile(path, "application manifest is missing: ${path}")
    let manifest = parseApplicationManifest(String.fromUtf8(File.readFrom(path)))
    validateApplicationManifest(manifest, project)
    manifest
}

func parseApplicationManifest(text: String): ApplicationManifest {
    var section = ""
    var name = ""
    var identifier = ""
    var version = ""
    var publisher = ""
    var applicationIcon = ""
    var statusItemIcon = ""
    var notificationIcon = ""
    var documentIcon = ""
    var monochromeIcon = ""
    var resources = ArrayList<String>()
    var singleInstance = false
    var statusItem = false
    var notifications = false
    var settings = false
    var harmonySourceRoots = ArrayList<String>()
    var harmonyExclude = ArrayList<String>()
    var harmonyTargetPackage = ""
    var harmonyOutput = ""
    var harmonyTransforms = ArrayList<String>()
    let seen = ArrayList<String>()
    var lineNumber: Int64 = 0
    for (rawLine in text.split("\n")) {
        lineNumber += 1
        let line = trimAscii(rawLine)
        if (line.isEmpty() || startsWithText(line, "#")) { continue }
        if (startsWithText(line, "[")) {
            if (!endsWithText(line, "]")) { throw CuicError("invalid application manifest section at line ${lineNumber}") }
            section = substringTo(substringFrom(line, 1), Int64(substringFrom(line, 1).toRuneArray().size - 1))
            if (section != "application" && section != "assets" && section != "system" && section != "scripts" &&
                section != "harmony") {
                throw CuicError("unsupported application manifest section '${section}' at line ${lineNumber}")
            }
            continue
        }
        let equals = indexOfText(line, "=")
        if (equals <= 0 || section.isEmpty()) { throw CuicError("invalid application manifest entry at line ${lineNumber}") }
        let key = trimAscii(substringTo(line, equals))
        if (applicationListContains(seen.toArray(), section + "." + key)) {
            throw CuicError("duplicate application manifest key '${section}.${key}' at line ${lineNumber}")
        }
        seen.add(section + "." + key)
        let value = trimAscii(substringFrom(line, equals + 1))
        if (section == "scripts") { continue }
        if (section == "application") {
            let parsed = parseManifestString(value, lineNumber)
            if (key == "name") { name = parsed }
            else if (key == "identifier") { identifier = parsed }
            else if (key == "version") { version = parsed }
            else if (key == "publisher") { publisher = parsed }
            else { throw CuicError("unsupported application key '${key}' at line ${lineNumber}") }
        } else if (section == "assets") {
            if (key == "resources") {
                resources = ArrayList<String>(parseManifestStringArray(value, lineNumber))
            } else {
                let parsed = parseManifestString(value, lineNumber)
                if (key == "application-icon") { applicationIcon = parsed }
                else if (key == "status-item-icon") { statusItemIcon = parsed }
                else if (key == "notification-icon") { notificationIcon = parsed }
                else if (key == "document-icon") { documentIcon = parsed }
                else if (key == "monochrome-icon") { monochromeIcon = parsed }
                else { throw CuicError("unsupported asset key '${key}' at line ${lineNumber}") }
            }
        } else if (section == "system") {
            let parsed = parseManifestBool(value, lineNumber)
            if (key == "single-instance") { singleInstance = parsed }
            else if (key == "status-item") { statusItem = parsed }
            else if (key == "notifications") { notifications = parsed }
            else if (key == "settings") { settings = parsed }
            else { throw CuicError("unsupported system key '${key}' at line ${lineNumber}") }
        } else if (section == "harmony") {
            if (key == "source-roots") {
                harmonySourceRoots = ArrayList<String>(parseManifestStringArray(value, lineNumber))
            } else if (key == "exclude") {
                harmonyExclude = ArrayList<String>(parseManifestStringArray(value, lineNumber))
            } else if (key == "transforms") {
                harmonyTransforms = ArrayList<String>(parseManifestStringArray(value, lineNumber))
            } else {
                let parsed = parseManifestString(value, lineNumber)
                if (key == "target-package") { harmonyTargetPackage = parsed }
                else if (key == "output") { harmonyOutput = parsed }
                else { throw CuicError("unsupported harmony key '${key}' at line ${lineNumber}") }
            }
        }
    }
    ApplicationManifest(name, identifier, version, publisher, applicationIcon,
        statusItemIcon, notificationIcon, documentIcon, monochromeIcon,
        resources.toArray(), singleInstance, statusItem, notifications, settings,
        harmonySourceRoots: harmonySourceRoots.toArray(), harmonyExclude: harmonyExclude.toArray(),
        harmonyTargetPackage: harmonyTargetPackage, harmonyOutput: harmonyOutput,
        harmonyTransforms: harmonyTransforms.toArray())
}

func validateApplicationManifest(manifest: ApplicationManifest, project: String): Unit {
    if (manifest.name.isEmpty()) { throw CuicError("application.name is required") }
    if (manifest.identifier.isEmpty()) { throw CuicError("application.identifier is required") }
    if (manifest.version.isEmpty()) { throw CuicError("application.version is required") }
    if (!isApplicationNameSafe(manifest.name)) {
        throw CuicError("application.name must be a safe display and artifact name")
    }
    if (!isApplicationIdentifier(manifest.identifier)) {
        throw CuicError("application.identifier must contain only letters, digits, '.', '-' or '_'")
    }
    if (!isApplicationVersion(manifest.version)) {
        throw CuicError("application.version must contain only letters, digits, '.', '+', '-' or '_'")
    }
    let paths = ArrayList<String>()
    addManifestAsset(paths, manifest.applicationIcon, "application-icon")
    addManifestAsset(paths, manifest.statusItemIcon, "status-item-icon")
    addManifestAsset(paths, manifest.notificationIcon, "notification-icon")
    addManifestAsset(paths, manifest.documentIcon, "document-icon")
    addManifestAsset(paths, manifest.monochromeIcon, "monochrome-icon")
    for (resource in manifest.resources) {
        validateManifestRelativePath(resource, "resource")
        if (applicationListContains(paths.toArray(), resource)) { throw CuicError("duplicate asset/resource path '${resource}'") }
        paths.add(resource)
    }
    for (path in paths) {
        if (!project.isEmpty()) {
            let asset = joinPath(project, path)
            if (!exists(asset)) {
                throw CuicError("declared application asset is missing: ${path}")
            }
            let projectRoot = canonicalPackagingPath(project, "project")
            ensurePackagingInputTreeStaysInsideProject(
                projectRoot, asset, "declared application asset")
        }
    }
    validateHarmonyProjectionManifest(manifest, project)
}

func validateHarmonyProjectionManifest(manifest: ApplicationManifest, project: String): Unit {
    let configured = !manifest.harmonySourceRoots.isEmpty() || !manifest.harmonyTargetPackage.isEmpty() ||
        !manifest.harmonyOutput.isEmpty() || !manifest.harmonyTransforms.isEmpty() || !manifest.harmonyExclude.isEmpty()
    if (!configured) { return }
    if (manifest.harmonySourceRoots.isEmpty()) { throw CuicError("harmony.source-roots is required") }
    if (manifest.harmonyTargetPackage.isEmpty() || !isApplicationIdentifier(manifest.harmonyTargetPackage)) {
        throw CuicError("harmony.target-package must be a safe package identifier")
    }
    let output = if (manifest.harmonyOutput.isEmpty()) {".canghui/generated/harmony"} else {manifest.harmonyOutput}
    validateManifestRelativePath(output, "harmony output")
    for (path in manifest.harmonySourceRoots) {
        validateManifestRelativePath(path, "harmony source root")
        if (!project.isEmpty() && !exists(joinPath(project, path))) {
            throw CuicError("harmony source root is missing: ${path}")
        }
    }
    for (path in manifest.harmonyExclude) { validateManifestRelativePath(path, "harmony exclude") }
    for (rule in manifest.harmonyTransforms) { validateHarmonyTransformRule(rule) }
}

func validateHarmonyTransformRule(rule: String): Unit {
    if (!startsWithText(rule, "replace:") || !containsText(rule, "=>")) {
        throw CuicError("harmony transform must use replace:<exact>=> <replacement> syntax")
    }
    let body = substringFrom(rule, Int64("replace:".toRuneArray().size))
    let separator = indexOfText(body, "=>")
    let source = if (separator < 0) {""} else {substringTo(body, separator)}
    if (source.isEmpty() || source.contains("\n") || source.contains("\r")) {
        throw CuicError("harmony transform source must be a non-empty single-line token")
    }
}

func addManifestAsset(paths: ArrayList<String>, value: String, role: String): Unit {
    if (value.isEmpty()) { return }
    validateManifestRelativePath(value, role)
    if (applicationListContains(paths.toArray(), value)) { throw CuicError("duplicate asset path '${value}'") }
    paths.add(value)
}

func validateManifestRelativePath(value: String, role: String): Unit {
    if (value.isEmpty()) { throw CuicError("${role} path cannot be empty") }
    if (startsWithText(value, "/") || startsWithText(value, "\\") || startsWithText(value, "~") ||
        isWindowsAbsolute(value) || manifestHasWindowsDrivePrefix(value)) {
        throw CuicError("${role} path must be relative: ${value}")
    }
    for (part in splitManifestPath(value)) {
        if (part == "..") { throw CuicError("${role} path must not escape the project: ${value}") }
    }
}

func splitManifestPath(value: String): Array<String> {
    let normalized = replaceManifestBackslashes(value)
    normalized.split("/")
}

func replaceManifestBackslashes(value: String): String {
    let out = StringBuilder()
    for (r in value.toRuneArray()) {
        out.append(if (r == r'\\') { "/" } else { r.toString() })
    }
    out.toString()
}

func isApplicationIdentifier(value: String): Bool {
    if (startsWithText(value, ".") || endsWithText(value, ".") || containsText(value, "..")) { return false }
    var hasAlphaNumeric = false
    for (r in value.toRuneArray()) {
        if ((r >= r'a' && r <= r'z') || (r >= r'A' && r <= r'Z') || (r >= r'0' && r <= r'9')) {
            hasAlphaNumeric = true
        }
        if (!((r >= r'a' && r <= r'z') || (r >= r'A' && r <= r'Z') ||
            (r >= r'0' && r <= r'9') || r == r'.' || r == r'-' || r == r'_')) { return false }
    }
    hasAlphaNumeric
}

func isApplicationNameSafe(value: String): Bool {
    if (value == "." || value == "..") { return false }
    let runes = value.toRuneArray()
    if (runes.isEmpty() || runes[0] == r' ' || runes[0] == r'.' ||
        runes[runes.size - 1] == r' ' || runes[runes.size - 1] == r'.') { return false }
    for (r in value.toRuneArray()) {
        if (r < r' ' || r == r'<' || r == r'>' || r == r':' || r == r'"' ||
            r == r'/' || r == r'\\' || r == r'|' || r == r'?' || r == r'*') { return false }
    }
    !isWindowsReservedArtifactName(value)
}

func isWindowsReservedArtifactName(value: String): Bool {
    let stem = asciiLowerText(value).split(".")[0]
    for (reserved in ["con", "prn", "aux", "nul",
        "com1", "com2", "com3", "com4", "com5", "com6", "com7", "com8", "com9",
        "lpt1", "lpt2", "lpt3", "lpt4", "lpt5", "lpt6", "lpt7", "lpt8", "lpt9"]) {
        if (stem == reserved) { return true }
    }
    false
}

func isApplicationVersion(value: String): Bool {
    for (r in value.toRuneArray()) {
        if (!((r >= r'a' && r <= r'z') || (r >= r'A' && r <= r'Z') ||
            (r >= r'0' && r <= r'9') || r == r'.' || r == r'+' || r == r'-' || r == r'_')) { return false }
    }
    true
}

func manifestHasWindowsDrivePrefix(value: String): Bool {
    let runes = value.toRuneArray()
    runes.size >= 2 && runes[1] == r':'
}

func parseManifestString(value: String, lineNumber: Int64): String {
    let trimmed = trimAscii(value)
    if (trimmed.size < 2 || !startsWithText(trimmed, "\"") || !endsWithText(trimmed, "\"")) {
        throw CuicError("manifest string expected at line ${lineNumber}")
    }
    substringTo(substringFrom(trimmed, 1), Int64(substringFrom(trimmed, 1).toRuneArray().size - 1))
}

func parseManifestBool(value: String, lineNumber: Int64): Bool {
    let trimmed = trimAscii(value)
    if (trimmed == "true") { return true }
    if (trimmed == "false") { return false }
    throw CuicError("manifest boolean expected at line ${lineNumber}")
}

func parseManifestStringArray(value: String, lineNumber: Int64): Array<String> {
    let trimmed = trimAscii(value)
    if (trimmed.size < 2 || !startsWithText(trimmed, "[") || !endsWithText(trimmed, "]")) {
        throw CuicError("manifest string array expected at line ${lineNumber}")
    }
    let inner = trimAscii(substringTo(substringFrom(trimmed, 1), Int64(substringFrom(trimmed, 1).toRuneArray().size - 1)))
    if (inner.isEmpty()) { return [] }
    let values = ArrayList<String>()
    for (raw in inner.split(",")) {
        let item = trimAscii(raw)
        let parsed = parseManifestString(item, lineNumber)
        if (applicationListContains(values.toArray(), parsed)) { throw CuicError("duplicate resource path '${parsed}'") }
        values.add(parsed)
    }
    values.toArray()
}

func buildApplicationPackagingPlan(project: String, platform: String): ApplicationPackagingPlan {
    let manifest = loadApplicationManifest(project)
    applicationPackagingPlanForManifest(project, platform, manifest)
}

func applicationPackagingPlanForManifest(project: String, platform: String,
    manifest: ApplicationManifest): ApplicationPackagingPlan {
    let inputAssets = ArrayList<String>()
    for (value in [manifest.applicationIcon, manifest.statusItemIcon, manifest.notificationIcon,
        manifest.documentIcon, manifest.monochromeIcon]) {
        if (!value.isEmpty()) { inputAssets.add(value) }
    }
    for (resource in manifest.resources) { inputAssets.add(resource) }
    let generated = ArrayList<String>()
    let providers = ArrayList<String>()
    let unsupported = ArrayList<String>()
    if (manifest.applicationIcon.isEmpty()) { unsupported.add("application-icon-not-declared") }
    if (manifest.statusItem && manifest.statusItemIcon.isEmpty()) { unsupported.add("status-item-icon-not-declared") }
    if (manifest.notifications && manifest.notificationIcon.isEmpty()) { unsupported.add("notification-icon-not-declared") }
    if (platform == "macos") {
        generated.add("dist/${manifest.name}.app/Contents/Info.plist")
        generated.add("dist/${manifest.name}.app/Contents/PkgInfo")
        generated.add("dist/${manifest.name}.app/Contents/MacOS/${manifest.name}")
        if (!manifest.applicationIcon.isEmpty()) {
            let extension = packagingExtension(manifest.applicationIcon)
            let icon = if (extension == "icns") { "application.icns" } else {
                packagingNameWithExtension("application-icon", extension)
            }
            generated.add("dist/${manifest.name}.app/Contents/Resources/${icon}")
        }
        generated.add("dist/${manifest.name}.app/Contents/Resources/assets")
        generated.add("dist/${manifest.name}.app/Contents/Resources/canghui-packaging-receipt.json")
        providers.add("application-menu=native-provider-pending")
        providers.add("status-item=${if (manifest.statusItem) { "native-provider-pending" } else { "disabled-by-manifest" }}")
        providers.add("notifications=${if (manifest.notifications) { "native-provider-pending" } else { "disabled-by-manifest" }}")
        unsupported.add("code-signing-and-notarization")
    } else if (platform == "windows") {
        generated.add("dist/${manifest.name}/${manifest.name}.exe.manifest")
        if (!manifest.applicationIcon.isEmpty()) {
            let extension = packagingExtension(manifest.applicationIcon)
            let icon = if (extension == "ico") { "${manifest.name}.ico" } else {
                packagingNameWithExtension("${manifest.name}.icon", extension)
            }
            generated.add("dist/${manifest.name}/${icon}")
        }
        generated.add("dist/${manifest.name}/${manifest.name}.version.rc")
        generated.add("dist/${manifest.name}/AppUserModelID.txt")
        generated.add("dist/${manifest.name}/canghui-packaging-receipt.json")
        providers.add("taskbar=provider-pending")
        providers.add("notifications=${if (manifest.notifications) { "provider-pending" } else { "disabled-by-manifest" }}")
        unsupported.add("code-signing-and-msix-publication")
    } else {
        generated.add("dist/${manifest.name}/${manifest.name}.desktop")
        generated.add("dist/${manifest.name}/icons/hicolor")
        generated.add("dist/${manifest.name}/share")
        generated.add("dist/${manifest.name}/canghui-packaging-receipt.json")
        providers.add("desktop-entry=plan-ready")
        providers.add("tray=provider-dependent")
        providers.add("notifications=provider-dependent")
        unsupported.add("distribution-signing-and-desktop-integration")
    }
    ApplicationPackagingPlan(platform, project, manifest, inputAssets.toArray(), generated.toArray(),
        providers.toArray(), unsupported.toArray(), platform != "linux")
}

func renderApplicationPackagingPlan(plan: ApplicationPackagingPlan): Unit {
    println("CangHui packaging plan (${PACKAGING_PLAN_SCHEMA})")
    println("Platform: ${plan.platform}")
    println("Project: ${plan.project}")
    println("Identity: ${plan.manifest.name} ${plan.manifest.version} (${plan.manifest.identifier})")
    renderPlanList("Input assets", plan.inputAssets)
    renderPlanList("Generated files", plan.generatedFiles)
    renderPlanList("Provider state", plan.nativeProviderState)
    renderPlanList("Unsupported or gated", plan.unsupportedCapabilities)
    println("Signing required: ${plan.signingRequired}")
    println("Plan only: no bundle, executable, signature or publication was generated.")
}

func renderPlanList(title: String, values: Array<String>): Unit {
    println("${title}:")
    if (values.isEmpty()) { println("  (none)"); return }
    for (value in values) { println("  - ${value}") }
}

func renderApplicationPackagingPlanJson(plan: ApplicationPackagingPlan): String {
    let out = StringBuilder()
    out.append("{\"schema\":")
    out.append(cuicJsonQuote(PACKAGING_PLAN_SCHEMA))
    out.append(",\"platform\":")
    out.append(cuicJsonQuote(plan.platform))
    out.append(",\"project\":")
    out.append(cuicJsonQuote(plan.project))
    out.append(",\"identity\":{\"name\":")
    out.append(cuicJsonQuote(plan.manifest.name))
    out.append(",\"identifier\":")
    out.append(cuicJsonQuote(plan.manifest.identifier))
    out.append(",\"version\":")
    out.append(cuicJsonQuote(plan.manifest.version))
    out.append(",\"publisher\":")
    out.append(cuicJsonQuote(plan.manifest.publisher))
    out.append("}")
    out.append(",\"inputAssets\":")
    appendApplicationPlanArray(out, plan.inputAssets)
    out.append(",\"generatedFiles\":")
    appendApplicationPlanArray(out, plan.generatedFiles)
    out.append(",\"nativeProviderState\":")
    appendApplicationPlanArray(out, plan.nativeProviderState)
    out.append(",\"signingRequired\":")
    out.append(plan.signingRequired.toString())
    out.append(",\"unsupportedCapabilities\":")
    appendApplicationPlanArray(out, plan.unsupportedCapabilities)
    out.append("}")
    out.toString()
}

func appendApplicationPlanArray(out: StringBuilder, values: Array<String>): Unit {
    out.append("[")
    var first = true
    for (value in values) {
        if (!first) { out.append(",") }
        first = false
        out.append(cuicJsonQuote(value))
    }
    out.append("]")
}

func applicationListContains(values: Array<String>, expected: String): Bool {
    for (value in values) {
        if (value == expected) { return true }
    }
    false
}

func applicationManifestDoctorChecks(project: String): Array<DoctorCheck> {
    let checks = ArrayList<DoctorCheck>()
    let manifest = joinPath(project, APPLICATION_MANIFEST_FILE)
    if (project.isEmpty() || !exists(manifest)) {
        checks.add(doctorDegraded("application.manifest", "Application declaration",
            "canghui.toml does not declare an application identity and asset graph.", DoctorActionKind.Automatic,
            "Run cuic init or add an [application] section to canghui.toml.", manifest))
        return checks.toArray()
    }
    try {
        let parsed = parseApplicationManifest(String.fromUtf8(File.readFrom(manifest)))
        validateApplicationManifest(parsed, project)
        checks.add(doctorReady("application.manifest", "Application declaration",
            "Application identity, declared asset paths and system settings are valid.", manifest))
        checks.add(applicationAssetDoctorCheck(project, "application.asset.application-icon",
            "Application icon", parsed.applicationIcon, true))
        checks.add(applicationAssetDoctorCheck(project, "application.asset.status-item-icon",
            "Status-item icon", parsed.statusItemIcon, parsed.statusItem))
        checks.add(applicationAssetDoctorCheck(project, "application.asset.notification-icon",
            "Notification icon", parsed.notificationIcon, parsed.notifications))
        checks.add(doctorReady("application.resources", "Application resources",
            "All ${parsed.resources.size} declared resource path(s) are present.", manifest))
    } catch (e: CuicError) {
        checks.add(doctorBlocked("application.manifest", "Application declaration", e.message,
            DoctorActionKind.Manual, "Fix canghui.toml, then rerun cuic doctor.", manifest))
    }
    checks.toArray()
}

func applicationAssetDoctorCheck(project: String, id: String, label: String,
    path: String, required: Bool): DoctorCheck {
    if (path.isEmpty()) {
        if (required) {
            return doctorDegraded(id, label, "No logical asset is declared for this enabled role.",
                DoctorActionKind.Manual, "Declare the role under [assets] in canghui.toml.", "")
        }
        return doctorReady(id, label, "The related system surface is disabled and needs no asset.", "")
    }
    doctorReady(id, label, "The declared logical asset is present.", joinPath(project, path))
}

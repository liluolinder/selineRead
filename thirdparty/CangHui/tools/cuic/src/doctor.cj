package cuic

import std.collection.ArrayList
import std.env.{getCommandLine, getVariable}
import std.fs.{Directory, Path, exists}
import std.process.executeWithOutput

let CANGHUI_DOCTOR_SCHEMA = "canghui.doctor.v0"

enum DoctorStatus {
    | Ready
    | Degraded
    | Blocked
    | Unsupported
}

enum DoctorActionKind {
    | NoAction
    | Automatic
    | Manual
    | Unsupported
}

class DoctorCheck {
    let id: String
    let label: String
    let status: DoctorStatus
    let reason: String
    let actionKind: DoctorActionKind
    let suggestion: String
    let evidence: String

    init(id: String, label: String, status: DoctorStatus, reason: String,
        actionKind: DoctorActionKind, suggestion: String, evidence: String) {
        this.id = id
        this.label = label
        this.status = status
        this.reason = reason
        this.actionKind = actionKind
        this.suggestion = suggestion
        this.evidence = evidence
    }
}

class DoctorGroup {
    let id: String
    let title: String
    let target: String
    let checks: Array<DoctorCheck>

    init(id: String, title: String, target: String, checks: Array<DoctorCheck>) {
        this.id = id
        this.title = title
        this.target = target
        this.checks = checks
    }

    func status(): DoctorStatus {
        var result = DoctorStatus.Ready
        for (check in checks) {
            if (doctorStatusRank(check.status) > doctorStatusRank(result)) {
                result = check.status
            }
        }
        result
    }

    func appliesTo(requestedTarget: String): Bool {
        target == "all" || target == requestedTarget
    }
}

class DoctorOptions {
    let target: String
    let project: String
    let json: Bool
    let verbose: Bool

    init(target: String, project: String, json: Bool, verbose: Bool) {
        this.target = target
        this.project = project
        this.json = json
        this.verbose = verbose
    }
}

class DoctorResult {
    let host: String
    let architecture: String
    let requestedTarget: String
    let groups: Array<DoctorGroup>

    init(host: String, architecture: String, requestedTarget: String, groups: Array<DoctorGroup>) {
        this.host = host
        this.architecture = architecture
        this.requestedTarget = requestedTarget
        this.groups = groups
    }

    func requestedStatus(): DoctorStatus {
        var result = DoctorStatus.Ready
        for (group in groups) {
            if (group.appliesTo(requestedTarget) &&
                doctorStatusRank(group.status()) > doctorStatusRank(result)) {
                result = group.status()
            }
        }
        result
    }

    func requestedBlockers(): Int64 {
        var count: Int64 = 0
        for (group in groups) {
            if (!group.appliesTo(requestedTarget)) { continue }
            for (check in group.checks) {
                if (doctorStatusBlocks(check.status)) { count += 1 }
            }
        }
        count
    }

    func exitCode(): Int64 {
        if (requestedBlockers() > 0) { 1 } else { 0 }
    }
}

class DoctorCommandFact {
    let ok: Bool
    let summary: String

    init(ok: Bool, summary: String) {
        this.ok = ok
        this.summary = summary
    }
}

func doctorCommand(args: Array<String>, start: Int64): Int64 {
    let options = parseDoctorOptions(args, start)
    let project = doctorProjectPath(options.project)
    let framework = tryResolveFrameworkRoot(project)
    let result = collectDoctorResult(options.target, framework, project: project)
    if (options.json) {
        println(renderDoctorJson(result, options.verbose))
    } else {
        renderDoctorHuman(result, options.verbose)
    }
    result.exitCode()
}

func parseDoctorOptions(args: Array<String>, start: Int64): DoctorOptions {
    var target = hostPlatform()
    var targetSet = false
    var project = ""
    var json = false
    var verbose = false
    var i = start
    while (i < args.size) {
        let value = args[i]
        if (value == "--json") { json = true; i += 1; continue }
        if (value == "--verbose" || value == "-v") { verbose = true; i += 1; continue }
        if (value == "--project") {
            if (i + 1 >= args.size) { throw CuicError("--project requires a directory") }
            project = args[i + 1]
            i += 2
            continue
        }
        if (startsWithText(value, "-")) { throw CuicError("unknown doctor option '${value}'") }
        if (targetSet) { throw CuicError("doctor accepts one requested target") }
        target = normalizeDoctorPlatform(value)
        targetSet = true
        i += 1
    }
    DoctorOptions(target, project, json, verbose)
}

func doctorProjectPath(requested: String): String {
    if (requested.isEmpty()) { return currentDirectory() }
    if (startsWithText(requested, "/") || isWindowsAbsolute(requested)) {
        return Path(requested).normalize().toString()
    }
    Path(joinPath(currentDirectory(), requested)).normalize().toString()
}

func normalizeDoctorPlatform(value: String): String {
    let lower = asciiLowerText(value)
    if (lower == "mac" || lower == "macos" || lower == "darwin") { return "macos" }
    if (lower == "win" || lower == "windows") { return "windows" }
    if (lower == "linux") { return "linux" }
    if (lower == "ios" || lower == "iphone" || lower == "ipad") { return "ios" }
    if (lower == "harmony" || lower == "harmonyos" || lower == "ohos" || lower == "openharmony") {
        return "harmonyos"
    }
    if (lower == "android") { return "android" }
    throw CuicError("unknown doctor target '${value}'")
}

func collectDoctorResult(requestedTarget: String, framework: String, project!: String = ""): DoctorResult {
    let host = hostPlatform()
    let architecture = doctorHostArchitecture()
    let groups = ArrayList<DoctorGroup>()
    groups.add(doctorToolchainGroup(host, architecture))
    groups.add(doctorConsumerProjectGroup(project, framework))
    groups.add(doctorRepositoryGroup(framework))
    groups.add(doctorMacosGroup(host, architecture, framework, project))
    groups.add(doctorWindowsGroup(host, framework))
    groups.add(doctorLinuxGroup(host))
    groups.add(doctorIosGroup(host, framework, requestedTarget == "ios"))
    groups.add(doctorHarmonyGroup(framework, requestedTarget == "harmonyos"))
    groups.add(doctorAndroidGroup(framework))
    groups.add(doctorFontGroup(framework))
    groups.add(doctorSymbolGroup(framework))
    groups.add(doctorApplicationShellGroup(framework, project: project))
    groups.add(doctorMobileApplicationHostGroup(framework))
    groups.add(doctorProbeGroup(framework))
    DoctorResult(host, architecture, requestedTarget, groups.toArray())
}

func doctorConsumerProjectGroup(project: String, framework: String): DoctorGroup {
    let checks = ArrayList<DoctorCheck>()
    let manifest = joinPath(project, "cjpm.toml")
    if (!exists(manifest)) {
        checks.add(doctorDegraded("project.manifest", "Application manifest",
            "The current directory is not a Cangjie application project.", DoctorActionKind.Manual,
            "Run cuic doctor from an application or pass --project <directory>.", project))
        return DoctorGroup("project", "Application dependency and cache", "all", checks.toArray())
    }
    checks.add(doctorReady("project.manifest", "Application manifest",
        "A Cangjie project manifest is available.", manifest))
    if (frameworkRootCandidate(project)) {
        checks.add(doctorReady("project.dependency", "Framework development checkout",
            "The current project is the CangHui framework itself; no external chui dependency is required.", project))
        checks.add(doctorReady("project.cache", "Resolved framework",
            "The integrated CLI uses the current framework checkout.", framework))
        return DoctorGroup("project", "Application dependency, lock, and CJPM cache", "all", checks.toArray())
    }
    let spec = frameworkDependencySpec(project)
    if (spec.isLocal()) {
        checks.add(doctorReady("project.dependency", "CangHui dependency",
            "The application uses an explicit local development dependency.", spec.path))
        checks.add(if (framework.isEmpty()) {
            doctorBlocked("project.cache", "Resolved framework", "The local CangHui path is invalid.",
                DoctorActionKind.Manual, "Repair --canghui-path or CANGHUI_FRAMEWORK_ROOT.", spec.path)
        } else {
            doctorReady("project.cache", "Resolved framework", "The local framework root is readable.", framework)
        })
    } else if (spec.isGit()) {
        checks.add(if (spec.commitId.isEmpty()) {
            doctorBlocked("project.dependency", "CangHui dependency",
                "The public Git dependency is not pinned to an exact commitId.", DoctorActionKind.Manual,
                "Pin [dependencies].chui to an exact commitId before updating the lock.", spec.git)
        } else {
            doctorReady("project.dependency", "CangHui dependency",
                "The application uses a pinned public Git dependency.", spec.git + "@" + shortCommit(spec.commitId))
        })
        let locked = lockedFrameworkCommit(project)
        let lockProblem = frameworkDependencyLockProblem(spec, locked)
        checks.add(if (!lockProblem.isEmpty()) {
            doctorBlocked("project.lock", "Dependency lock", lockProblem, DoctorActionKind.Manual,
                "Run cuic dependency update explicitly after reviewing the manifest pin.", joinPath(project, "cjpm.lock"))
        } else {
            doctorReady("project.lock", "Dependency lock",
                "cjpm.lock matches the manifest CangHui commitId.", locked)
        })
        let cached = cachedFrameworkRoot(project)
        checks.add(if (!lockProblem.isEmpty()) {
            doctorBlocked("project.cache", "CJPM source cache",
                "The cached source cannot be accepted until the dependency lock matches the manifest.",
                DoctorActionKind.Manual, "Repair the lock with cuic dependency update.", cjpmCacheRoot(project))
        } else if (cached.isEmpty()) {
            doctorDegraded("project.cache", "CJPM source cache", "The pinned CangHui source is not present in the CJPM cache.",
                DoctorActionKind.Manual, "Run cuic dependency update to populate the CJPM cache.", cjpmCacheRoot(project))
        } else {
            doctorReady("project.cache", "CJPM source cache", "The pinned framework is available from the user cache.", cached)
        })
    } else {
        checks.add(doctorBlocked("project.dependency", "CangHui dependency",
            "The project does not declare a chui dependency.", DoctorActionKind.Manual,
            "Run cuic init or add a pinned CangHui dependency under [dependencies].", manifest))
    }
    DoctorGroup("project", "Application dependency, lock, and CJPM cache", "all", checks.toArray())
}

func doctorToolchainGroup(host: String, architecture: String): DoctorGroup {
    let checks = ArrayList<DoctorCheck>()
    checks.add(doctorProgramCheck(
        "toolchain.cjpm", "Cangjie package manager", "cjpm", ["--version"],
        "Install a supported Cangjie SDK and add cjpm to PATH."
    ))
    checks.add(doctorProgramCheck(
        "toolchain.cjc", "Cangjie compiler", "cjc", ["--version"],
        "Install a supported Cangjie SDK and add cjc to PATH."
    ))
    checks.add(if (architecture.isEmpty()) {
        doctorBlocked("toolchain.architecture", "Host architecture", "The host architecture could not be detected.",
            DoctorActionKind.Manual, "Run the doctor from a native terminal and verify the operating-system toolchain.", "")
    } else {
        doctorReady("toolchain.architecture", "Host architecture", "The host architecture is available to target checks.",
            host + " " + architecture)
    })
    DoctorGroup("toolchain", "Cangjie SDK and target compatibility", "all", checks.toArray())
}

func doctorRepositoryGroup(framework: String): DoctorGroup {
    let checks = ArrayList<DoctorCheck>()
    checks.add(doctorFrameworkRequiredFile(framework,
        "repository.manifest", "CangHui package manifest", joinPath(framework, "cjpm.toml"),
        "Restore the CangHui package manifest."
    ))
    checks.add(doctorFrameworkRequiredFile(framework,
        "repository.umbrella", "CangHui umbrella package", joinPath(framework, "src/chui.cj"),
        "Restore the CangHui source package."
    ))
    let command = getCommandLine()[0]
    checks.add(if (!command.isEmpty()) {
        doctorReady("repository.cli", "cuic command", "The current CLI executable is running independently.", command)
    } else {
        doctorBlocked("repository.cli", "cuic command", "The current CLI executable path is unavailable.",
            DoctorActionKind.Manual, "Install cuic with the public installer.", "")
    })
    let integrated = integratedFrameworkRoot()
    checks.add(if (framework.isEmpty()) {
        doctorDegraded("repository.alignment", "CLI and framework resolution",
            "No application dependency or explicit framework root is currently resolved.", DoctorActionKind.Automatic,
            "Run cuic build from an initialized project or set CANGHUI_FRAMEWORK_ROOT for framework development.", "")
    } else if (!integrated.isEmpty() && Path(integrated).normalize().toString() == Path(framework).normalize().toString()) {
        doctorReady("repository.alignment", "Repository and CLI alignment",
            "The command resolves the repository that owns this integrated CLI.", framework)
    } else {
        doctorReady("repository.alignment", "CLI and framework resolution",
            "The installed CLI resolves CangHui through the application dependency cache.", framework)
    })
    DoctorGroup("repository", "CangHui repository, package, and CLI alignment", "all", checks.toArray())
}

func doctorMacosGroup(host: String, architecture: String, framework: String, project: String): DoctorGroup {
    let checks = ArrayList<DoctorCheck>()
    checks.add(doctorHostCheck("macos", host))
    let runtime = if (!framework.isEmpty() && !project.isEmpty() && exists(joinPath(project, "cjpm.toml"))) {
        ExecutionContext(project, framework).sdlDirectory()
    } else {
        joinPath(framework, "sdl/.sdl3")
    }
    checks.add(doctorMacosRuntimeProvider(host, "macos.sdl3", "SDL3 link/runtime provider",
        joinPath(runtime, "libSDL3.dylib"), "sdl3"))
    checks.add(doctorMacosRuntimeProvider(host, "macos.sdl3-ttf", "SDL3_ttf link/runtime provider",
        joinPath(runtime, "libSDL3_ttf.dylib"), "sdl3_ttf"))
    checks.add(if (host == "macos" && architecture == "arm64") {
        doctorReady("macos.architecture", "Native architecture", "The current arm64 host matches the bundled runtime proof.", architecture)
    } else if (host == "macos") {
        doctorDegraded("macos.architecture", "Native architecture",
            "The host architecture differs from the current arm64 proof baseline.", DoctorActionKind.Manual,
            "Rebuild or bootstrap SDL libraries for the current architecture.", architecture)
    } else {
        doctorUnsupported("macos.architecture", "Native architecture",
            "macOS architecture validation requires a macOS host.", "Run cuic doctor macos on macOS.", architecture)
    })
    checks.add(doctorRequiredFile(
        "macos.gallery", "Renderer acceptance project", joinPath(framework, "examples/component-gallery/cjpm.toml"),
        "Restore the Component Gallery example before renderer acceptance."
    ))
    DoctorGroup("platform.macos", "macOS host and renderer readiness", "macos", checks.toArray())
}

func doctorMacosRuntimeProvider(host: String, id: String, label: String,
    stagedLibrary: String, formula: String): DoctorCheck {
    if (exists(stagedLibrary)) {
        return doctorReady(id, label, "The isolated cuic native staging cache is ready.", stagedLibrary)
    }
    if (host != "macos") {
        return doctorUnsupported(id, label, "The native provider can only be validated on macOS.",
            "Run cuic doctor macos on macOS.", "host=" + host)
    }
    let fact = doctorCommandFact("brew", ["--prefix", formula])
    if (fact.ok) {
        doctorReady(id, label,
            "The Homebrew provider is installed; cuic build will populate the isolated staging cache automatically.",
            fact.summary)
    } else {
        doctorBlocked(id, label, "The Homebrew provider is unavailable.", DoctorActionKind.Automatic,
            "Install it with: brew install sdl3 sdl3_ttf", fact.summary)
    }
}

func doctorWindowsGroup(host: String, framework: String): DoctorGroup {
    let checks = ArrayList<DoctorCheck>()
    checks.add(doctorHostCheck("windows", host))
    checks.add(doctorRequiredFile(
        "windows.sdl3", "Bundled SDL3 DLL", joinPath(framework, "sdl/.sdl3/SDL3.dll"),
        "Run cuic bootstrap windows on a Windows host."
    ))
    checks.add(doctorRequiredFile(
        "windows.sdl3-ttf", "Bundled SDL3_ttf DLL", joinPath(framework, "sdl/.sdl3/SDL3_ttf.dll"),
        "Run cuic bootstrap windows on a Windows host."
    ))
    checks.add(if (host == "windows") {
        doctorProgramCheck("windows.toolchain", "Windows Cangjie toolchain", "cjc", ["--version"],
            "Install the Windows Cangjie SDK and make cjc available in PATH.")
    } else {
        doctorUnsupported("windows.toolchain", "Windows Cangjie toolchain",
            "Native linker and DLL loading checks cannot run on this host.",
            "Run cuic doctor windows on a Windows machine.", "host=" + host)
    })
    DoctorGroup("platform.windows", "Windows DLL and toolchain readiness", "windows", checks.toArray())
}

func doctorLinuxGroup(host: String): DoctorGroup {
    let checks = ArrayList<DoctorCheck>()
    checks.add(doctorHostCheck("linux", host))
    if (host == "linux") {
        checks.add(doctorProgramCheck("linux.pkg-config", "pkg-config", "pkg-config", ["--version"],
            "Install pkg-config with the host package manager."))
        checks.add(doctorInvocationCheck("linux.sdl3", "SDL3 development package", "pkg-config", ["--exists", "sdl3"],
            "Install the SDL3 development package and refresh PKG_CONFIG_PATH."))
        checks.add(doctorInvocationCheck("linux.sdl3-ttf", "SDL3_ttf development package", "pkg-config", ["--exists", "sdl3-ttf"],
            "Install the SDL3_ttf development package and refresh PKG_CONFIG_PATH."))
    } else {
        checks.add(doctorUnsupported("linux.pkg-config", "Linux native libraries",
            "Linux pkg-config and runtime loading checks require a Linux host.",
            "Run cuic doctor linux on Linux.", "host=" + host))
    }
    DoctorGroup("platform.linux", "Linux pkg-config, library, and runtime readiness", "linux", checks.toArray())
}

func doctorIosGroup(host: String, framework: String, liveChecks: Bool): DoctorGroup {
    let checks = ArrayList<DoctorCheck>()
    if (host == "macos") {
        checks.add(doctorProgramCheck("ios.xcode", "Xcode toolchain", "xcodebuild", ["-version"],
            "Install or select Xcode with xcode-select."))
        checks.add(doctorInvocationCheck("ios.sdk", "iPhoneOS SDK", "xcrun", ["--sdk", "iphoneos", "--show-sdk-path"],
            "Install the iOS platform in Xcode."))
    } else {
        checks.add(doctorUnsupported("ios.xcode", "Xcode and iPhoneOS SDK",
            "iOS builds require a macOS host with Xcode.", "Run cuic doctor ios on macOS.", "host=" + host))
    }
    let iosToolchain = doctorIosToolchainRoot()
    checks.add(doctorRequiredFile("ios.cangjie-compiler", "Cangjie iOS compiler", joinPath(iosToolchain, "bin/cjc"),
        "Install the Cangjie iOS toolchain under /Library/Frameworks/Cangjie."))
    checks.add(doctorRequiredDirectory("ios.runtime", "Cangjie iOS runtime", joinPath(iosToolchain, "lib/ios_aarch64_cjnative"),
        "Install a Cangjie toolchain that includes ios_aarch64_cjnative runtime libraries."))
    for (check in doctorIosFrameworkChecks(framework)) { checks.add(check) }
    checks.add(doctorIosSigningCheck(host, liveChecks))
    checks.add(doctorIosDeviceCheck(host, liveChecks))
    DoctorGroup("platform.ios", "iOS Xcode, SDK, signing, device, and Cangjie readiness", "ios", checks.toArray())
}

func doctorIosToolchainRoot(): String {
    for (name in ["CANGHUI_IOS_HOME", "CANGJIE_IOS_HOME"]) {
        match (getVariable(name)) {
            case Some(value) where !trimAscii(value).isEmpty() =>
                return trimTrailingSlash(trimAscii(value))
            case _ => ()
        }
    }
    "/Library/Frameworks/Cangjie/1.3.0-alpha-ios"
}

func doctorIosFrameworkChecks(framework: String): Array<DoctorCheck> {
    let checks = ArrayList<DoctorCheck>()
    checks.add(doctorRequiredFile("ios.host-script", "CangHui iOS static-library build",
        joinPath(framework, "scripts/build-ios-host-staticlibs.sh"),
        "Restore the CangHui iOS host build script."))
    checks.add(doctorRequiredFile("ios.bootstrap-helper", "CangHui iOS runtime bootstrap helper",
        joinPath(framework, "platform/ios/bootstrap/CangHuiRuntimeBootstrap.m"),
        "Use a CangHui revision that includes the Objective-C runtime bootstrap helper."))
    checks.add(doctorRequiredFile("ios.bootstrap-verifier", "CangHui iOS static-package verifier",
        joinPath(framework, "scripts/verify-ios-static-package.sh"),
        "Use a CangHui revision that includes simulator and device bootstrap verification."))
    checks.add(doctorRequiredFile("ios.bootstrap-proof", "CangHui iOS bootstrap proof receipt",
        joinPath(framework, "proofs/20260731-canghui-ios-static-package-bootstrap-v1.json"),
        "Re-run the iOS static-package verifier and retain its public proof receipt."))
    checks.add(doctorRequiredFile("ios.surface-header", "CangHui iOS native-surface ABI",
        joinPath(framework, "platform/ios/include/CangHuiNativeSurface.h"),
        "Use a CangHui revision that includes the integer-only native-surface ABI."))
    checks.add(doctorRequiredFile("ios.surface-view", "CangHui iOS Metal surface view",
        joinPath(framework, "platform/ios/runtime/CangHuiMetalSurfaceView.m"),
        "Use a CangHui revision that includes the UIKit CAMetalLayer adapter."))
    checks.add(doctorRequiredFile("ios.surface-clock", "CangHui iOS display-link driver",
        joinPath(framework, "platform/ios/runtime/CangHuiDisplayLinkDriver.m"),
        "Use a CangHui revision that includes the CADisplayLink frame clock."))
    checks.add(doctorReady("ios.renderer", "CangHui iOS native-surface adapter",
        "The UIKit CAMetalLayer adapter, lifecycle, safe-area, touch, frame-clock and surface-generation replay are present.",
        "platform/ios runtime and native-surface proof"))
    checks.toArray()
}

func doctorHarmonyGroup(framework: String, liveChecks: Bool): DoctorGroup {
    let checks = ArrayList<DoctorCheck>()
    let deveco = "/Applications/DevTools/DevEco-Studio.app"
    let sdk = joinPath(deveco, "Contents/sdk/default/openharmony")
    let hvigor = joinPath(deveco, "Contents/tools/hvigor/bin/hvigorw")
    let hdc = "/Library/Huawei/ohos/toolchains/hdc"
    checks.add(doctorRequiredDirectory("harmony.deveco", "DevEco Studio", deveco,
        "Install DevEco Studio and its OpenHarmony SDK."))
    checks.add(doctorRequiredDirectory("harmony.sdk", "OpenHarmony SDK", sdk,
        "Install an OpenHarmony SDK from DevEco Studio SDK Manager."))
    checks.add(doctorRequiredFile("harmony.hvigor", "hvigor", hvigor,
        "Install or repair the DevEco Studio hvigor toolchain."))
    checks.add(doctorRequiredFile("harmony.hdc", "hdc", hdc,
        "Install the OpenHarmony command-line toolchain."))
    checks.add(doctorRequiredFile("harmony.native", "OpenHarmony native compiler",
        joinPath(sdk, "native/llvm/bin/clang"),
        "Install the OpenHarmony native/NDK component from SDK Manager."))
    checks.add(doctorHarmonyDeviceCheck(hdc, liveChecks))
    checks.add(doctorBlocked("harmony.adapter", "CangHui HarmonyOS application adapter",
        "This repository does not ship an ArkTS/HAP host or application packaging project.",
        DoctorActionKind.Manual, "Configure a HarmonyOS platform adapter that consumes the public CangHui contracts.",
        "framework contract only"))
    DoctorGroup("platform.harmonyos", "HarmonyOS/OpenHarmony SDK, native toolchain, and device readiness",
        "harmonyos", checks.toArray())
}

func doctorAndroidGroup(framework: String): DoctorGroup {
    let checks = ArrayList<DoctorCheck>()
    let sdkRoot = doctorAndroidSdkRoot()
    checks.add(if (sdkRoot.isEmpty()) {
        doctorDegraded("android.sdk", "Android SDK", "ANDROID_SDK_ROOT or ANDROID_HOME is not configured.",
            DoctorActionKind.Manual, "Install Android Studio or the command-line SDK and set ANDROID_SDK_ROOT.", "")
    } else {
        doctorReady("android.sdk", "Android SDK", "An Android SDK root is configured.", sdkRoot)
    })
    let ndkRoot = doctorAndroidNdkRoot(sdkRoot)
    checks.add(if (ndkRoot.isEmpty()) {
        doctorDegraded("android.ndk", "Android NDK", "No Android NDK root was detected.",
            DoctorActionKind.Manual, "Install the Android NDK and set ANDROID_NDK_ROOT.", "")
    } else {
        doctorReady("android.ndk", "Android NDK", "An Android NDK root is configured.", ndkRoot)
    })
    let javaHost = joinPath(framework,
        "platform/android/src/main/java/dev/canghui/android/CangHuiNativeSurfaceHost.java")
    let activityHost = joinPath(framework,
        "platform/android/src/main/java/dev/canghui/android/CangHuiSurfaceActivity.java")
    let nativeHost = joinPath(framework, "platform/android/src/main/cpp/canghui_android_surface.cpp")
    let buildScript = joinPath(framework, "scripts/build-android-native-surface.sh")
    let verifyScript = joinPath(framework, "scripts/verify-android-toolchain.sh")
    checks.add(doctorRequiredFile("android.surface-java", "Android SurfaceView host", javaHost,
        "Use a CangHui revision that includes the Android native-surface bootstrap."))
    checks.add(doctorRequiredFile("android.surface-activity", "Android Activity lifecycle host", activityHost,
        "Use a CangHui revision that includes the Android Activity lifecycle bootstrap."))
    checks.add(doctorRequiredFile("android.surface-native", "Android ANativeWindow bridge", nativeHost,
        "Use a CangHui revision that includes the generation-safe JNI/ANativeWindow bridge."))
    checks.add(doctorRequiredFile("android.surface-build", "Android native-surface build", buildScript,
        "Restore the Android native-surface build verifier."))
    checks.add(doctorRequiredFile("android.surface-verify", "Android native-surface verification", verifyScript,
        "Restore the Android ABI and JNI export verifier."))

    let cangjieRoot = doctorAndroidCangjieRoot()
    let cangjieModules = doctorAndroidCrossDirectory(joinPath(cangjieRoot, "modules"))
    let cangjieRuntime = doctorAndroidCrossDirectory(joinPath(joinPath(cangjieRoot, "runtime"), "lib"))
    checks.add(if (!cangjieModules.isEmpty() && !cangjieRuntime.isEmpty()) {
        doctorReady("android.cangjie", "Cangjie Android cross SDK",
            "Android modules and runtime are available for the arm64 Cangjie target.",
            cangjieModules + " | " + cangjieRuntime)
    } else {
        doctorBlocked("android.cangjie", "Cangjie Android cross SDK",
            "The selected Cangjie SDK does not provide Android arm64 modules and runtime.",
            DoctorActionKind.Manual,
            "Install a Cangjie Android cross SDK before linking the framework bridge.", cangjieRoot)
    })

    let nativeBootstrap = exists(javaHost) && exists(activityHost) && exists(nativeHost) &&
        exists(buildScript) && exists(verifyScript)
    checks.add(if (nativeBootstrap) {
        doctorDegraded("android.backend", "CangHui Android renderer and package runner",
            "The Java/JNI/NDK native-surface and Activity lifecycle bootstrap is present, but the Cangjie " +
                "renderer bridge, input, IME, APK packaging and device runtime proof remain open.",
            DoctorActionKind.Manual,
            "Complete the shared Cangjie ABI and device-backed Android application host.",
            "native-surface and Activity lifecycle bootstrap only")
    } else {
        doctorUnsupported("android.backend", "CangHui Android renderer and package runner",
            "The Android native-surface bootstrap, renderer, package assembly, and runner are not available.",
            "Use a CangHui revision with the Android bootstrap before implementing the renderer.",
            "unsupported by current CangHui revision")
    })
    DoctorGroup("platform.android", "Android SDK, NDK, native surface, Cangjie, and package readiness",
        "android", checks.toArray())
}

func doctorFontGroup(framework: String): DoctorGroup {
    let checks = ArrayList<DoctorCheck>()
    checks.add(doctorRequiredFile("font.bundled", "Bundled HarmonyOS Sans", joinPath(framework, "assets/fonts/HarmonyOS_Sans_SC.ttf"),
        "Restore the unmodified HarmonyOS Sans asset."))
    checks.add(doctorRequiredFile("font.license", "HarmonyOS Sans license receipt", joinPath(framework, "assets/fonts/HARMONYOS_SANS_LICENSE.txt"),
        "Restore the HarmonyOS Sans license file beside the font asset."))
    checks.add(doctorRequiredFile("font.source", "HarmonyOS Sans source notice", joinPath(framework, "assets/fonts/HARMONYOS_SANS_SOURCE.txt"),
        "Restore the HarmonyOS Sans source notice beside the font asset."))
    let contract = joinPath(framework, "contracts/canghui-font-resolution-v0.json")
    checks.add(if (exists(contract)) {
        doctorReady("font.resolution", "Default and fallback resolution contract",
            "The framework publishes the explicit/theme/bundled/system resolution contract.", contract)
    } else {
        doctorDegraded("font.resolution", "Default and fallback resolution contract",
            "The bundled asset exists, but the complete renderer fallback contract is not present.",
            DoctorActionKind.Manual, "Use a CangHui build that includes the renderer font-resolution contract.", contract)
    })
    DoctorGroup("font", "Bundled default font and license readiness", "all", checks.toArray())
}

func doctorSymbolGroup(framework: String): DoctorGroup {
    let checks = ArrayList<DoctorCheck>()
    let core = joinPath(framework, "src/symbol/symbol.cj")
    checks.add(if (exists(core)) {
        doctorReady("symbol.core", "Provider-neutral Symbol core", "The Symbol call surface is available.", core)
    } else {
        doctorDegraded("symbol.core", "Provider-neutral Symbol core", "The Symbol call surface is not available yet.",
            DoctorActionKind.Manual, "Use a CangHui build that includes Symbol core contracts.", core)
    })
    for ((id, title, path) in [
        ("material", "Material provider", "packages/symbol-material/cjpm.toml"),
        ("ant", "Ant Design provider", "packages/symbol-ant/cjpm.toml"),
        ("arco", "Arco provider", "packages/symbol-arco/cjpm.toml")
    ]) {
        let full = joinPath(framework, path)
        checks.add(if (exists(full)) {
            doctorReady("symbol.provider." + id, title, "The optional provider package is available for on-demand import.", full)
        } else {
            doctorDegraded("symbol.provider." + id, title, "The optional provider package is not installed in this checkout.",
                DoctorActionKind.Manual, "Add the optional provider package only when the application references that family.", full)
        })
    }
    let generator = joinPath(framework, "tools/cuic/src/symbol.cj")
    checks.add(if (exists(generator)) {
        doctorReady("symbol.generator", "On-demand Symbol generator", "cuic can generate declared Symbol subsets.", generator)
    } else {
        doctorDegraded("symbol.generator", "On-demand Symbol generator", "cuic symbol generation is not available yet.",
            DoctorActionKind.Manual, "Use a CangHui build that includes cuic symbol generation.", generator)
    })
    DoctorGroup("symbol", "Configured Symbol providers and generated assets", "all", checks.toArray())
}

func doctorApplicationShellGroup(framework: String, project!: String = ""): DoctorGroup {
    let checks = ArrayList<DoctorCheck>()
    for (check in applicationManifestDoctorChecks(project)) { checks.add(check) }
    checks.add(doctorRequiredFile("application-shell.contract", "CangHui application shell contract",
        joinPath(framework, "src/system/application_shell.cj"),
        "Restore the CangHui system application-shell contract."))
    checks.add(doctorRequiredFile("application-shell.schema", "Application shell manifest schema",
        joinPath(framework, "contracts/canghui-application-shell-v0.json"),
        "Restore the public application-shell contract schema."))
    checks.add(doctorRequiredFile("application-shell.plan-schema", "Packaging plan schema",
        joinPath(framework, "contracts/canghui-packaging-plan-v0.schema.json"),
        "Restore the public packaging-plan schema."))
    checks.add(doctorRequiredFile("application-shell.artifact-schema", "Packaging artifact schema",
        joinPath(framework, "contracts/canghui-packaging-artifact-v0.schema.json"),
        "Restore the public packaging-artifact schema."))
    checks.add(if (exists(joinPath(framework, "manual/reference/application-shell.md"))) {
        doctorReady("application-shell.docs", "Application shell guide",
            "The public application-shell contract guide is available.", joinPath(framework, "manual/reference/application-shell.md"))
    } else {
        doctorDegraded("application-shell.docs", "Application shell guide",
            "The application-shell contract exists but its public guide is missing.",
            DoctorActionKind.Manual, "Restore manual/reference/application-shell.md.", joinPath(framework, "manual/reference/application-shell.md"))
    })
    DoctorGroup("application-shell", "Cangjie application identity, assets, settings and system surfaces", "all", checks.toArray())
}

func doctorMobileApplicationHostGroup(framework: String): DoctorGroup {
    let checks = ArrayList<DoctorCheck>()
    checks.add(doctorRequiredFile("mobile-host.contract", "Mobile application host contract",
        joinPath(framework, "src/host/mobile_application_host.cj"),
        "Restore the provider-neutral iOS, Android and HarmonyOS host contract."))
    checks.add(doctorRequiredFile("mobile-host.schema", "Mobile host package receipt schema",
        joinPath(framework, "contracts/canghui-mobile-host-package-v0.schema.json"),
        "Restore the public mobile host package receipt schema."))
    checks.add(doctorRequiredFile("mobile-host.signing-preparation", "Mobile signing preparation contract",
        joinPath(framework, "src/host/mobile_signing_preparation.cj"),
        "Restore the non-secret external-signer preparation contract."))
    checks.add(doctorRequiredFile("mobile-host.signing-preparation-schema", "Mobile signing preparation schema",
        joinPath(framework, "contracts/canghui-mobile-signing-preparation-v0.schema.json"),
        "Restore the public mobile signing preparation receipt schema."))
    checks.add(doctorRequiredFile("mobile-host.external-signer-receipt", "Mobile external signer receipt contract",
        joinPath(framework, "src/host/mobile_external_signer_receipt.cj"),
        "Restore the bounded external signer receipt binding contract."))
    checks.add(doctorRequiredFile("mobile-host.external-signer-receipt-schema", "Mobile external signer receipt schema",
        joinPath(framework, "contracts/canghui-mobile-external-signer-receipt-v0.schema.json"),
        "Restore the public external signer receipt binding schema."))
    checks.add(doctorRequiredFile("mobile-host.signed-package-evidence", "Mobile signed package evidence contract",
        joinPath(framework, "src/host/mobile_signed_package_evidence.cj"),
        "Restore the platform-owner signed package evidence gate."))
    checks.add(doctorRequiredFile("mobile-host.signed-package-evidence-schema", "Mobile signed package evidence schema",
        joinPath(framework, "contracts/canghui-mobile-signed-package-evidence-v0.schema.json"),
        "Restore the public signed package evidence receipt schema."))
    checks.add(doctorRequiredFile("mobile-host.installation-attempt", "Mobile installation attempt contract",
        joinPath(framework, "src/host/mobile_installation_attempt.cj"),
        "Restore the platform-owner installation attempt receipt gate."))
    checks.add(doctorRequiredFile("mobile-host.installation-attempt-schema", "Mobile installation attempt schema",
        joinPath(framework, "contracts/canghui-mobile-installation-attempt-v0.schema.json"),
        "Restore the public installation attempt receipt schema."))
    checks.add(doctorRequiredFile("mobile-host.replay-contract", "Mobile host semantic replay contract",
        joinPath(framework, "src/host/mobile_host_replay.cj"),
        "Restore the platform-neutral mobile host semantic replay contract."))
    checks.add(doctorRequiredFile("mobile-host.replay-schema", "Mobile host semantic replay schema",
        joinPath(framework, "contracts/canghui-mobile-host-replay-v0.schema.json"),
        "Restore the public mobile host semantic replay schema."))
    checks.add(doctorRequiredFile("mobile-host.kmode-adapter", "Mobile host kMode replay adapter",
        joinPath(framework, "src/kmode/mobile_host_replay.cj"),
        "Restore the kMode adapter for consumer-owned mobile host receipts."))
    checks.add(doctorRequiredFile("mobile-host.consumer-fixture", "Mobile host replay consumer fixture",
        joinPath(framework, "examples/mobile-host-replay/src/main.cj"),
        "Restore the headless mobile host consumer fixture."))
    checks.add(doctorRequiredFile("mobile-host.docs", "Mobile application host guide",
        joinPath(framework, "manual/reference/mobile-application-host.md"),
        "Restore the public mobile application host guide."))

    let iosAdapter = joinPath(framework, "platform/ios/runtime/CangHuiMetalSurfaceView.m")
    let iosProvider = joinPath(framework, "src/host/ios_mobile_application_host.cj")
    checks.add(if (exists(iosAdapter) && exists(iosProvider)) {
        doctorReady("mobile-host.ios-provider", "iOS host provider boundary",
            "The provider-owned iOS input-tree, signed-package evidence and installation-attempt gates are present; launch and device replay remain separate gates.",
            iosProvider + " + " + iosAdapter)
    } else {
        doctorDegraded("mobile-host.ios-provider", "iOS host provider boundary",
            "The common contract is present but the provider-owned iOS input-tree binding or UIKit native-surface adapter is missing.",
            DoctorActionKind.Manual, "Restore the iOS provider and native-surface adapter before product-host integration.",
            iosProvider + " + " + iosAdapter)
    })

    let iosInputTree = [
        "platform/ios/probe/Info.plist",
        "platform/ios/probe/AppDelegate.m",
        "platform/ios/bootstrap/CangHuiRuntimeBootstrap.m",
        "platform/ios/runtime/CangHuiUIKitHostView.m",
        "platform/ios/runtime/CangHuiMetalSurfaceView.m",
        "platform/ios/runtime/CangHuiDisplayLinkDriver.m",
        "platform/ios/runtime/CangHuiNativeSceneSurfaceView.m",
        "platform/ios/include/CangHuiHost.h",
        "platform/ios/include/CangHuiNativeSurface.h",
        "platform/ios/include/CangHuiRuntimeBootstrap.h",
        "platform/ios/include/CangHuiUIKitHostView.h",
        "platform/ios/include/CangHuiMetalSurfaceView.h",
        "platform/ios/include/CangHuiNativeSceneSurfaceView.h",
        "platform/ios/include/CangjieGUIHost.h"
    ]
    var missingIOSInputFiles = 0
    if (!framework.isEmpty()) {
        for (relativePath in iosInputTree) {
            if (!exists(joinPath(framework, relativePath))) { missingIOSInputFiles += 1 }
        }
    }
    checks.add(if (framework.isEmpty()) {
        doctorDegraded("mobile-host.ios-input-tree", "iOS unsigned input tree",
            "The CangHui dependency is not resolved, so the provider input tree cannot be inspected.",
            DoctorActionKind.Automatic, "Run cuic build before inspecting the iOS provider input tree.", "")
    } else if (missingIOSInputFiles == 0) {
        doctorReady("mobile-host.ios-input-tree", "iOS unsigned input tree",
            "The provider-owned iOS UIKit input tree is complete for unsigned headless replay.",
            "14 checked-in iOS source and resource files")
    } else {
        doctorBlocked("mobile-host.ios-input-tree", "iOS unsigned input tree",
            "The provider input tree is missing " + missingIOSInputFiles.toString() + " checked-in file(s).",
            DoctorActionKind.Manual, "Restore the iOS probe, bootstrap, runtime and include files before replay.",
            framework)
    })

    let androidAdapter = joinPath(framework,
        "platform/android/src/main/java/dev/canghui/android/CangHuiNativeSurfaceHost.java")
    checks.add(if (exists(androidAdapter)) {
        doctorDegraded("mobile-host.android-provider", "Android host provider boundary",
            "The common contract and Java/JNI native-surface bootstrap are present; Cangjie runtime linkage, product APK and device proof remain open.",
            DoctorActionKind.Manual, "Complete the Android Cangjie host and advance receipts one evidence stage at a time.", androidAdapter)
    } else {
        doctorUnsupported("mobile-host.android-provider", "Android host provider boundary",
            "The common contract exists without an Android native-surface bootstrap.",
            "Add a bounded Android provider that consumes the public contract.", androidAdapter)
    })

    checks.add(doctorDegraded("mobile-host.harmony-provider", "HarmonyOS host provider boundary",
        "The common contract defines OHNativeWindow/XComponent-style lifecycle, permission and package receipts, but this repository does not ship an ArkTS/HAP host.",
        DoctorActionKind.Manual, "Implement or integrate a HarmonyOS provider without copying product policy into the framework.",
        "framework contract only"))
    DoctorGroup("mobile-application-host", "Mobile provider, lifecycle, signing and package proof boundaries", "all",
        checks.toArray())
}

func doctorProbeGroup(framework: String): DoctorGroup {
    let checks = ArrayList<DoctorCheck>()
    if (framework.isEmpty()) {
        checks.add(doctorDegraded("probe.framework", "Probe framework source",
            "Probe contracts cannot be inspected before the CangHui dependency is resolved.",
            DoctorActionKind.Automatic, "Run cuic build from the application project.", ""))
        return DoctorGroup("probe", "kMode and probe registry health", "all", checks.toArray())
    }
    checks.add(doctorRequiredFile("probe.schema", "cui.probe.v0 schema", joinPath(framework, "contracts/cui-probe-v0.schema.json"),
        "Restore the public probe protocol schema."))
    checks.add(doctorRequiredFile("probe.macro", "CuiProbe macro", joinPath(framework, "src/kmode/macros/link.cj"),
        "Restore the explicit probe annotation macro."))
    let gallery = joinPath(framework, "examples/component-gallery")
    let kmodeCode = runKModeDiff(gallery, quiet: true)
    checks.add(if (kmodeCode == 0) {
        doctorReady("probe.kmode-registry", "kMode registry", "No duplicate kMode names were found in the local package graph.", gallery)
    } else {
        doctorBlocked("probe.kmode-registry", "kMode registry", "Duplicate kMode names were detected.",
            DoctorActionKind.Manual, "Run cuic kmode diff component-gallery and rename duplicate endpoints.", gallery)
    })
    let probeCode = runProbeDiff(gallery, quiet: true)
    checks.add(if (probeCode == 0) {
        doctorReady("probe.registry", "Probe registry", "No duplicate probe names were found in the local package graph.", gallery)
    } else {
        doctorBlocked("probe.registry", "Probe registry", "Duplicate probe names were detected.",
            DoctorActionKind.Manual, "Run cuic probe diff component-gallery and rename duplicate probes.", gallery)
    })
    DoctorGroup("probe", "kMode and probe registry health", "all", checks.toArray())
}

func doctorProgramCheck(id: String, label: String, program: String, args: Array<String>, suggestion: String): DoctorCheck {
    let fact = doctorCommandFact(program, args)
    if (fact.ok) {
        doctorReady(id, label, "The command is available.", doctorProgramEvidence(program, fact.summary))
    } else {
        doctorBlocked(id, label, "The command is unavailable or returned an error.",
            DoctorActionKind.Manual, suggestion, doctorProgramEvidence(program, fact.summary))
    }
}

func doctorInvocationCheck(id: String, label: String, program: String, args: Array<String>, suggestion: String): DoctorCheck {
    let fact = doctorCommandFact(program, args)
    if (fact.ok) {
        doctorReady(id, label, "The readiness probe completed successfully.", fact.summary)
    } else {
        doctorBlocked(id, label, "The readiness probe failed.", DoctorActionKind.Manual, suggestion, fact.summary)
    }
}

func doctorRequiredFile(id: String, label: String, path: String, suggestion: String): DoctorCheck {
    if (exists(path)) {
        doctorReady(id, label, "The required file is present.", path)
    } else {
        doctorBlocked(id, label, "The required file is missing.", DoctorActionKind.Automatic, suggestion, path)
    }
}

func doctorFrameworkRequiredFile(framework: String, id: String, label: String,
    path: String, suggestion: String): DoctorCheck {
    if (framework.isEmpty()) {
        return doctorDegraded(id, label, "The CangHui dependency is not resolved yet.",
            DoctorActionKind.Automatic, "Run cuic build before this framework check. " + suggestion, "")
    }
    doctorRequiredFile(id, label, path, suggestion)
}

func doctorRequiredDirectory(id: String, label: String, path: String, suggestion: String): DoctorCheck {
    if (exists(path)) {
        doctorReady(id, label, "The required directory is present.", path)
    } else {
        doctorBlocked(id, label, "The required directory is missing.", DoctorActionKind.Manual, suggestion, path)
    }
}

func doctorHostCheck(target: String, host: String): DoctorCheck {
    if (target == host) {
        doctorReady(target + ".host", "Native host", "The current host matches the requested platform.", host)
    } else {
        doctorUnsupported(target + ".host", "Native host", "Native runtime validation requires a " + target + " host.",
            "Run cuic doctor " + target + " on a " + target + " host.", "host=" + host)
    }
}

func doctorIosSigningCheck(host: String, liveCheck: Bool): DoctorCheck {
    if (host != "macos") {
        return doctorUnsupported("ios.signing", "Code signing identity", "Code signing checks require macOS.",
            "Run cuic doctor ios on the signing host.", "host=" + host)
    }
    if (!liveCheck) {
        return doctorDegraded("ios.signing", "Code signing identity",
            "Signing identities are checked only for an explicitly requested iOS target.",
            DoctorActionKind.Manual, "Run cuic doctor ios --verbose on the signing host.", "not queried")
    }
    let fact = doctorCommandFact("security", ["find-identity", "-v", "-p", "codesigning"])
    if (fact.ok && !containsText(fact.summary, "0 valid identities found")) {
        doctorReady("ios.signing", "Code signing identity", "At least one code signing identity is available.",
            "one or more valid identities")
    } else {
        doctorBlocked("ios.signing", "Code signing identity", "No valid code signing identity is available.",
            DoctorActionKind.Manual, "Configure Apple Development signing in Xcode before physical-device packaging.",
            "no valid identity")
    }
}

func doctorIosDeviceCheck(host: String, liveCheck: Bool): DoctorCheck {
    if (host != "macos") {
        return doctorUnsupported("ios.device", "iOS device visibility", "CoreDevice checks require macOS.",
            "Run cuic doctor ios on the device host.", "host=" + host)
    }
    if (!liveCheck) {
        return doctorDegraded("ios.device", "iOS device visibility",
            "Device visibility is checked only for an explicitly requested iOS target.",
            DoctorActionKind.Manual, "Run cuic doctor ios --verbose with the device connected.", "not queried")
    }
    let fact = doctorCommandFact("xcrun", ["devicectl", "list", "devices", "--timeout", "5"])
    if (fact.ok && (containsText(fact.summary, "available (") || containsText(fact.summary, "connected"))) {
        doctorReady("ios.device", "iOS device visibility", "At least one paired iOS/iPadOS device is visible.",
            "one or more paired devices")
    } else if (fact.ok) {
        doctorDegraded("ios.device", "iOS device visibility", "The device query succeeded but no available device was detected.",
            DoctorActionKind.Manual, "Connect, trust, and pair an iPhone or iPad, then rerun the doctor.",
            "no available device")
    } else {
        doctorDegraded("ios.device", "iOS device visibility", "The CoreDevice query did not return a usable device list.",
            DoctorActionKind.Manual, "Open Xcode Devices and Simulators, then rerun cuic doctor ios.", "query failed")
    }
}

func doctorHarmonyDeviceCheck(hdc: String, liveCheck: Bool): DoctorCheck {
    if (!exists(hdc)) {
        return doctorBlocked("harmony.device", "HarmonyOS device visibility", "hdc is unavailable.",
            DoctorActionKind.Manual, "Install the OpenHarmony command-line toolchain.", hdc)
    }
    if (!liveCheck) {
        return doctorDegraded("harmony.device", "HarmonyOS device visibility",
            "Device visibility is checked only for an explicitly requested HarmonyOS target.",
            DoctorActionKind.Manual, "Run cuic doctor harmonyos --verbose with the device connected.", "not queried")
    }
    let fact = doctorCommandFact(hdc, ["list", "targets"])
    if (fact.ok && !doctorCommandOutputIsEmpty(fact.summary)) {
        doctorReady("harmony.device", "HarmonyOS device visibility", "At least one hdc target is visible.",
            "one or more hdc targets")
    } else {
        doctorDegraded("harmony.device", "HarmonyOS device visibility", "No hdc target is currently visible.",
            DoctorActionKind.Manual, "Connect or authorize a device and run hdc list targets.", "no visible target")
    }
}

func doctorCommandFact(program: String, args: Array<String>): DoctorCommandFact {
    try {
        let (code, stdoutBytes, stderrBytes) = executeWithOutput(program, args)
        let stdout = trimAscii(String.fromUtf8(stdoutBytes))
        let stderr = trimAscii(String.fromUtf8(stderrBytes))
        let summary = if (!stdout.isEmpty()) { stdout } else { stderr }
        DoctorCommandFact(code == 0, summary)
    } catch (error: Exception) {
        DoctorCommandFact(false, error.message)
    }
}

func doctorProgramEvidence(program: String, summary: String): String {
    let location = doctorProgramLocation(program)
    let version = doctorFirstLine(summary)
    if (location.isEmpty()) { return version }
    if (version.isEmpty()) { return location }
    location + " | " + version
}

func doctorProgramLocation(program: String): String {
    let locator = if (hostPlatform() == "windows") { "where" } else { "which" }
    let fact = doctorCommandFact(locator, [program])
    if (fact.ok) { doctorFirstLine(fact.summary) } else { "" }
}

func doctorFirstLine(value: String): String {
    let trimmed = trimAscii(value)
    if (trimmed.isEmpty()) { return "" }
    let lines = trimmed.split("\n")
    trimAscii(lines[0])
}

func doctorCommandOutputIsEmpty(value: String): Bool {
    let trimmed = trimAscii(value)
    trimmed.isEmpty() || trimmed == "[Empty]"
}

func doctorHostArchitecture(): String {
    if (hostPlatform() == "windows") {
        match (getVariable("PROCESSOR_ARCHITECTURE")) {
            case Some(value) => return trimAscii(value)
            case None => return ""
        }
    }
    let fact = doctorCommandFact("uname", ["-m"])
    if (fact.ok) { doctorFirstLine(fact.summary) } else { "" }
}

func doctorAndroidSdkRoot(): String {
    for (name in ["ANDROID_SDK_ROOT", "ANDROID_HOME"]) {
        match (getVariable(name)) {
            case Some(value) where !trimAscii(value).isEmpty() => return trimTrailingSlash(trimAscii(value))
            case _ => ()
        }
    }
    ""
}

func doctorAndroidNdkRoot(sdkRoot: String): String {
    match (getVariable("ANDROID_NDK_ROOT")) {
        case Some(value) where !trimAscii(value).isEmpty() => return trimTrailingSlash(trimAscii(value))
        case _ => ()
    }
    if (sdkRoot.isEmpty()) { return "" }
    let ndk = joinPath(sdkRoot, "ndk")
    if (!exists(ndk)) { return "" }
    try {
        for (entry in Directory.readFrom(ndk)) {
            if (entry.isDirectory()) { return entry.path.toString() }
        }
    } catch (_: Exception) {}
    ""
}

func doctorAndroidCangjieRoot(): String {
    match (getVariable("CANGJIE_HOME")) {
        case Some(value) => trimTrailingSlash(trimAscii(value))
        case None => ""
    }
}

func doctorAndroidCrossDirectory(parent: String): String {
    if (parent.isEmpty() || !exists(parent)) { return "" }
    try {
        for (entry in Directory.readFrom(parent)) {
            let name = basename(entry.path.toString())
            if (entry.isDirectory() && startsWithText(name, "linux_android") &&
                endsWithText(name, "_aarch64_cjnative")) {
                return entry.path.toString()
            }
        }
    } catch (_: Exception) {}
    ""
}

func doctorReady(id: String, label: String, reason: String, evidence: String): DoctorCheck {
    DoctorCheck(id, label, DoctorStatus.Ready, reason, DoctorActionKind.NoAction, "", evidence)
}

func doctorDegraded(id: String, label: String, reason: String, actionKind: DoctorActionKind,
    suggestion: String, evidence: String): DoctorCheck {
    DoctorCheck(id, label, DoctorStatus.Degraded, reason, actionKind, suggestion, evidence)
}

func doctorBlocked(id: String, label: String, reason: String, actionKind: DoctorActionKind,
    suggestion: String, evidence: String): DoctorCheck {
    DoctorCheck(id, label, DoctorStatus.Blocked, reason, actionKind, suggestion, evidence)
}

func doctorUnsupported(id: String, label: String, reason: String, suggestion: String, evidence: String): DoctorCheck {
    DoctorCheck(id, label, DoctorStatus.Unsupported, reason, DoctorActionKind.Unsupported, suggestion, evidence)
}

func doctorStatusName(status: DoctorStatus): String {
    match (status) {
        case DoctorStatus.Ready => "ready"
        case DoctorStatus.Degraded => "degraded"
        case DoctorStatus.Blocked => "blocked"
        case DoctorStatus.Unsupported => "unsupported"
    }
}

func doctorActionKindName(kind: DoctorActionKind): String {
    match (kind) {
        case DoctorActionKind.NoAction => "none"
        case DoctorActionKind.Automatic => "automatic"
        case DoctorActionKind.Manual => "manual"
        case DoctorActionKind.Unsupported => "unsupported"
    }
}

func doctorStatusRank(status: DoctorStatus): Int64 {
    match (status) {
        case DoctorStatus.Ready => 0
        case DoctorStatus.Degraded => 1
        case DoctorStatus.Blocked => 2
        case DoctorStatus.Unsupported => 3
    }
}

func doctorStatusBlocks(status: DoctorStatus): Bool {
    match (status) {
        case DoctorStatus.Blocked => true
        case DoctorStatus.Unsupported => true
        case _ => false
    }
}

func renderDoctorHuman(result: DoctorResult, verbose: Bool): Unit {
    println("CangHui doctor (${CANGHUI_DOCTOR_SCHEMA})")
    println("CLI: ${renderCuicVersion()}")
    println("Host: ${result.host} ${result.architecture}")
    println("Requested target: ${result.requestedTarget}")
    for (group in result.groups) {
        println("")
        println("[${doctorStatusName(group.status())}] ${group.title} [${group.target}]")
        for (check in group.checks) {
            println("  [${doctorStatusName(check.status)}] ${check.label}: ${check.reason}")
            if (!check.suggestion.isEmpty()) {
                println("    fix(${doctorActionKindName(check.actionKind)}): ${check.suggestion}")
            }
            if (verbose && !check.evidence.isEmpty()) {
                println("    evidence: ${doctorSafeEvidence(check.evidence)}")
            }
        }
    }
    println("")
    println("Requested target ${result.requestedTarget}: ${doctorStatusName(result.requestedStatus())}; " +
        "${result.requestedBlockers()} blocker(s)")
}

func renderDoctorJson(result: DoctorResult, verbose: Bool): String {
    let out = StringBuilder()
    out.append("{\"schema\":")
    out.append(cuicJsonQuote(CANGHUI_DOCTOR_SCHEMA))
    out.append(",\"cliVersion\":")
    out.append(cuicJsonQuote(VERSION))
    out.append(",\"cliProvenance\":{\"channel\":")
    out.append(cuicJsonQuote(CUIC_BUILD_CHANNEL))
    out.append(",\"revision\":")
    out.append(cuicJsonQuote(CUIC_BUILD_REVISION))
    out.append("}")
    out.append(",\"host\":{\"platform\":")
    out.append(cuicJsonQuote(result.host))
    out.append(",\"architecture\":")
    out.append(cuicJsonQuote(result.architecture))
    out.append("},\"requestedTarget\":")
    out.append(cuicJsonQuote(result.requestedTarget))
    out.append(",\"status\":")
    out.append(cuicJsonQuote(doctorStatusName(result.requestedStatus())))
    out.append(",\"requestedBlockers\":")
    out.append(result.requestedBlockers())
    out.append(",\"exitCode\":")
    out.append(result.exitCode())
    out.append(",\"groups\":[")
    var firstGroup = true
    for (group in result.groups) {
        if (!firstGroup) { out.append(",") }
        firstGroup = false
        out.append("{\"id\":")
        out.append(cuicJsonQuote(group.id))
        out.append(",\"title\":")
        out.append(cuicJsonQuote(group.title))
        out.append(",\"target\":")
        out.append(cuicJsonQuote(group.target))
        out.append(",\"status\":")
        out.append(cuicJsonQuote(doctorStatusName(group.status())))
        out.append(",\"checks\":[")
        var firstCheck = true
        for (check in group.checks) {
            if (!firstCheck) { out.append(",") }
            firstCheck = false
            out.append("{\"id\":")
            out.append(cuicJsonQuote(check.id))
            out.append(",\"label\":")
            out.append(cuicJsonQuote(check.label))
            out.append(",\"status\":")
            out.append(cuicJsonQuote(doctorStatusName(check.status)))
            out.append(",\"reason\":")
            out.append(cuicJsonQuote(check.reason))
            out.append(",\"action\":{\"kind\":")
            out.append(cuicJsonQuote(doctorActionKindName(check.actionKind)))
            out.append(",\"suggestion\":")
            out.append(cuicJsonQuote(check.suggestion))
            out.append("},\"evidence\":")
            out.append(cuicJsonQuote(if (verbose) { doctorSafeEvidence(check.evidence) } else { "" }))
            out.append("}")
        }
        out.append("]}")
    }
    out.append("]}")
    out.toString()
}

func doctorSafeEvidence(value: String): String {
    var safe = value
    for (name in [
        "TOKEN", "PASSWORD", "PASSWD", "SECRET", "CREDENTIAL",
        "AUTHORIZATION", "API_KEY", "ACCESS_KEY", "PRIVATE_KEY", "BEARER",
        "COOKIE"
    ]) {
        if (containsText(asciiUpperText(safe), name)) { return "redacted" }
    }
    if (containsText(safe, "://") && containsText(safe, "@")) {
        return "redacted"
    }
    if (doctorEvidenceContainsAbsolutePath(safe)) { return "redacted" }
    for (name in ["USER", "USERNAME", "LOGNAME", "HOME", "USERPROFILE"]) {
        match (getVariable(name)) {
            case Some(identity) where identity.size >= 3 && containsText(safe, identity) =>
                return "redacted"
            case _ => ()
        }
    }
    safe
}

func doctorEvidenceContainsAbsolutePath(value: String): Bool {
    for (part in value.split(" ")) {
        let candidate = trimAscii(part)
        if (startsWithText(candidate, "/") || isWindowsAbsolute(candidate) ||
            containsText(candidate, "=/") || containsText(candidate, "=\\")) {
            return true
        }
    }
    false
}

func asciiLowerText(value: String): String {
    let out = StringBuilder()
    for (r in value.toRuneArray()) { out.append(asciiLower(r).toString()) }
    out.toString()
}

func asciiUpperText(value: String): String {
    let lower = "abcdefghijklmnopqrstuvwxyz".toRuneArray()
    let upper = "ABCDEFGHIJKLMNOPQRSTUVWXYZ".toRuneArray()
    let out = StringBuilder()
    for (r in value.toRuneArray()) {
        var mapped = r
        var i: Int64 = 0
        while (i < lower.size) {
            if (lower[i] == r) { mapped = upper[i]; break }
            i += 1
        }
        out.append(mapped.toString())
    }
    out.toString()
}

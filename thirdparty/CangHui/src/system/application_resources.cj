package chui.system

import std.collection.{ArrayList, HashSet}
import std.fs.{FileInfo, Path, canonicalize, exists}
import sdl.Fonts

/** Semantic use of one declared application resource. */
public enum ApplicationResourceRole {
    | Data
    | TextFont
    | FallbackFont
    | SymbolFont
    | SymbolCatalog
    | License
    | Custom(String)
}

public func applicationResourceRoleName(value: ApplicationResourceRole): String {
    match (value) {
        case ApplicationResourceRole.Data => "data"
        case ApplicationResourceRole.TextFont => "text-font"
        case ApplicationResourceRole.FallbackFont => "fallback-font"
        case ApplicationResourceRole.SymbolFont => "symbol-font"
        case ApplicationResourceRole.SymbolCatalog => "symbol-catalog"
        case ApplicationResourceRole.License => "license"
        case ApplicationResourceRole.Custom(name) => name
    }
}

/** A logical name mapped to one package-relative file. */
public struct ApplicationResourceDeclaration {
    public let name: String
    public let relativePath: String
    public let role: ApplicationResourceRole
    /** Required by the font registration recipe; ignored for non-font roles. */
    public let family: String

    public init(name: String, relativePath: String, role!: ApplicationResourceRole = ApplicationResourceRole.Data,
        family!: String = "") {
        validateResourceName(name, "resource name")
        validateResourceRelativePath(relativePath)
        let roleName = applicationResourceRoleName(role)
        validateResourceName(roleName, "resource role")
        if (resourceRoleIsFont(role) && family.isEmpty()) {
            throw IllegalArgumentException("font resource '${name}' must declare a family")
        }
        this.name = name
        this.relativePath = relativePath
        this.role = role
        this.family = family
    }
}

/** Physical package/source shape supplying declared logical resources. */
public enum ApplicationResourceRootKind {
    | Source
    | MacBundle
    | WindowsPackage
    | LinuxPackage
    | MobileRawfile
}

public func applicationResourceRootKindName(value: ApplicationResourceRootKind): String {
    match (value) {
        case ApplicationResourceRootKind.Source => "source"
        case ApplicationResourceRootKind.MacBundle => "macos-bundle"
        case ApplicationResourceRootKind.WindowsPackage => "windows-package"
        case ApplicationResourceRootKind.LinuxPackage => "linux-package"
        case ApplicationResourceRootKind.MobileRawfile => "mobile-rawfile"
    }
}

/** Trusted root injected by the host or constructed through one of the package helpers below. */
public struct ApplicationResourceRoot {
    public let kind: ApplicationResourceRootKind
    public let path: String
    /** Mobile surface generation. Desktop/source roots leave this empty. */
    public let generation: ?Int64

    public init(kind: ApplicationResourceRootKind, path: String, generation!: ?Int64 = None) {
        if (path.isEmpty()) { throw IllegalArgumentException("application resource root must not be empty") }
        match (generation) {
            case Some(value) => if (value < 0) {
                throw IllegalArgumentException("application resource root generation must not be negative")
            }
            case None => ()
        }
        this.kind = kind
        this.path = Path(path).normalize().toString()
        this.generation = generation
    }

    public static func source(projectRoot: String): ApplicationResourceRoot {
        ApplicationResourceRoot(ApplicationResourceRootKind.Source, projectRoot)
    }

    public static func macBundle(bundleRoot: String): ApplicationResourceRoot {
        ApplicationResourceRoot(ApplicationResourceRootKind.MacBundle,
            resourceJoinPath(bundleRoot, "Contents/Resources/assets"))
    }

    public static func windowsPackage(packageRoot: String): ApplicationResourceRoot {
        ApplicationResourceRoot(ApplicationResourceRootKind.WindowsPackage,
            resourceJoinPath(packageRoot, "assets"))
    }

    public static func linuxPackage(packageRoot: String, applicationId: String): ApplicationResourceRoot {
        validateResourceName(applicationId, "application id")
        ApplicationResourceRoot(ApplicationResourceRootKind.LinuxPackage,
            resourceJoinPath(packageRoot, "share/${applicationId}/resources"))
    }

    public static func mobileRawfile(rawfileRoot: String, generation: Int64): ApplicationResourceRoot {
        ApplicationResourceRoot(ApplicationResourceRootKind.MobileRawfile, rawfileRoot,
            generation: Some(generation))
    }
}

/** Provenance returned for every successful logical resolution. */
public struct ApplicationResourceReceipt {
    public let name: String
    public let role: ApplicationResourceRole
    public let path: String
    public let rootKind: ApplicationResourceRootKind
    public let generation: ?Int64

    public init(name: String, role: ApplicationResourceRole, path: String,
        rootKind: ApplicationResourceRootKind, generation!: ?Int64 = None) {
        this.name = name
        this.role = role
        this.path = path
        this.rootKind = rootKind
        this.generation = generation
    }

    public func provenance(): String {
        applicationResourceRootKindName(rootKind) + ":" + name
    }
}

/**
 * Runtime half of the `canghui.toml` application asset graph.
 *
 * Callers request a declared logical name. Filesystem guessing, undeclared access, traversal,
 * symbolic-link inputs and stale mobile generations fail closed. Roots are tried in caller order,
 * which allows a host to put its active package before an optional source-development fallback.
 */
public class ApplicationResources {
    private let declarations: Array<ApplicationResourceDeclaration>
    private let roots: Array<ApplicationResourceRoot>
    private let activeMobileGeneration: ?Int64

    public init(
        declarations: Array<ApplicationResourceDeclaration>,
        roots: Array<ApplicationResourceRoot>,
        activeMobileGeneration!: ?Int64 = None
    ) {
        if (roots.isEmpty()) { throw IllegalArgumentException("application resources require at least one root") }
        let names = HashSet<String>()
        for (declaration in declarations) {
            if (names.contains(declaration.name)) {
                throw IllegalArgumentException("duplicate application resource name: " + declaration.name)
            }
            names.add(declaration.name)
        }
        match (activeMobileGeneration) {
            case Some(value) => if (value < 0) {
                throw IllegalArgumentException("active mobile resource generation must not be negative")
            }
            case None => ()
        }
        this.declarations = declarations.clone()
        this.roots = roots.clone()
        this.activeMobileGeneration = activeMobileGeneration
    }

    /** Resolves only a declared logical name and returns canonical path plus package provenance. */
    public func resolve(name: String): ApplicationResourceReceipt {
        let declaration = match (findResourceDeclaration(declarations, name)) {
            case Some(value) => value
            case None => throw IllegalArgumentException("undeclared application resource: " + name)
        }
        for (root in roots) {
            validateMobileResourceGeneration(root, activeMobileGeneration)
            let rootPath = canonicalResourcePath(root.path, "resource root")
            let candidate = resourceJoinPath(root.path, declaration.relativePath)
            if (!exists(candidate)) { continue }
            if (FileInfo(candidate).isSymbolicLink()) {
                throw IllegalArgumentException("application resource must not be a symbolic link: " + name)
            }
            let resolved = canonicalResourcePath(candidate, "application resource")
            if (resolved != rootPath && !resolved.startsWith(rootPath + "/")) {
                throw IllegalArgumentException("application resource escapes its declared root: " + name)
            }
            return ApplicationResourceReceipt(declaration.name, declaration.role, resolved,
                root.kind, generation: root.generation)
        }
        throw IllegalStateException("declared application resource is missing: " + name)
    }

    /** Deterministically resolves every declaration in declaration order. */
    public func replay(): Array<ApplicationResourceReceipt> {
        let receipts = ArrayList<ApplicationResourceReceipt>()
        for (declaration in declarations) { receipts.add(resolve(declaration.name)) }
        receipts.toArray()
    }

    /** Registers declared text/symbol/fallback fonts before the first frame. */
    public func registerFonts(): Array<ApplicationResourceReceipt> {
        let receipts = ArrayList<ApplicationResourceReceipt>()
        for (declaration in declarations) {
            if (!resourceRoleIsFont(declaration.role)) { continue }
            let receipt = resolve(declaration.name)
            Fonts.register(declaration.family, receipt.path)
            match (declaration.role) {
                case ApplicationResourceRole.FallbackFont => Fonts.registerBundledFallback(receipt.path)
                case _ => ()
            }
            receipts.add(receipt)
        }
        receipts.toArray()
    }

    public func declarationCount(): Int64 { declarations.size }
    public func rootCount(): Int64 { roots.size }
}

private func findResourceDeclaration(values: Array<ApplicationResourceDeclaration>,
    name: String): ?ApplicationResourceDeclaration {
    for (value in values) { if (value.name == name) { return Some(value) } }
    None
}

private func validateMobileResourceGeneration(root: ApplicationResourceRoot, active: ?Int64): Unit {
    if (applicationResourceRootKindName(root.kind) != "mobile-rawfile") { return }
    match ((root.generation, active)) {
        case (Some(expected), Some(actual)) => if (expected != actual) {
            throw IllegalStateException("mobile application resource root has a stale generation")
        }
        case _ => throw IllegalStateException("mobile application resource root requires an active generation")
    }
}

private func validateResourceRelativePath(value: String): Unit {
    if (value.isEmpty() || value.startsWith("/") || value.startsWith("./") || value.contains("../") ||
        value.contains("\\") || value.contains("\u{0000}")) {
        throw IllegalArgumentException("application resource path must be a safe package-relative path")
    }
}

private func validateResourceName(value: String, role: String): Unit {
    if (value.isEmpty() || value.toArray().size > 512 || value.contains("/") || value.contains("\\") ||
        value.contains("\n") || value.contains("\r") || value.contains("\u{0000}")) {
        throw IllegalArgumentException("${role} must be a bounded logical token")
    }
}

private func resourceRoleIsFont(value: ApplicationResourceRole): Bool {
    match (value) {
        case ApplicationResourceRole.TextFont => true
        case ApplicationResourceRole.FallbackFont => true
        case ApplicationResourceRole.SymbolFont => true
        case _ => false
    }
}

private func canonicalResourcePath(value: String, role: String): String {
    try {
        canonicalize(value).toString()
    } catch (_: Exception) {
        throw IllegalStateException("cannot resolve ${role}: " + value)
    }
}

private func resourceJoinPath(root: String, relative: String): String {
    let left = if (root.endsWith("/")) { root[..root.size - 1] } else { root }
    let right = if (relative.startsWith("/")) { relative[1..] } else { relative }
    Path(left + "/" + right).normalize().toString()
}

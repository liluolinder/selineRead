package cuic

import std.collection.ArrayList
import std.env.getVariable
import std.fs.{Directory, File, FSException, Path, exists, removeIfExists}
import std.process.executeWithOutput

/**
 * Bounded execution context for cuic build/test/run/prnt/kMode/probe routes.
 *
 * Carries the project, resolved framework, a unique target directory and a
 * keyed native-staging root so concurrent workers with different contexts do
 * not mutate the same project `target/` or the framework's shared `sdl/.sdl3`.
 */
public class ExecutionContext {
    public let project: String
    public let framework: String
    public let targetDir: String
    public let stagingRoot: String

    public init(
        project: String,
        framework: String,
        targetDir!: String = "",
        stagingRoot!: String = ""
    ) {
        this.project = project
        this.framework = framework
        this.targetDir = if (targetDir.size > 0) {
            targetDir
        } else {
            defaultTargetDir(project)
        }
        this.stagingRoot = if (stagingRoot.size > 0) {
            stagingRoot
        } else {
            keyedStagingRoot(framework, hostPlatform(), hostArch())
        }
    }

    public func sdlDirectory(): String {
        joinPath(stagingRoot, "sdl/.sdl3")
    }

    public func acquireLease(): String {
        let lease = targetDir + ".cuic-lease"
        try {
            Directory.create(lease, recursive: true)
        } catch (_: FSException) {
            throw CuicError("target directory is leased by another cuic process: ${targetDir}")
        } catch (_: Exception) {
            throw CuicError("cannot acquire lease for target directory: ${targetDir}")
        }
        try {
            File.writeTo(joinPath(lease, "owner.txt"), ("pid=" + currentPid()).toArray())
        } catch (_: Exception) {
            removeIfExists(joinPath(lease, "owner.txt"))
            removeIfExists(lease)
            throw CuicError("cannot write lease owner for target directory: ${targetDir}")
        }
        lease
    }

    public func releaseLease(lease: String): Unit {
        if (lease.size > 0) {
            removeIfExists(joinPath(lease, "owner.txt"))
            removeIfExists(lease)
        }
    }
}

func defaultTargetDir(project: String): String {
    match (getVariable("CUIC_TARGET_DIR")) {
        case Some(value) where value.size > 0 => value
        case _ => joinPath(project, "target")
    }
}

func keyedStagingRoot(framework: String, platform: String, arch: String): String {
    let home = match (getVariable("HOME")) {
        case Some(value) where value.size > 0 => value
        case _ => "/tmp"
    }
    let absoluteFramework = if (startsWithText(framework, "/") || isWindowsAbsolute(framework)) {
        framework
    } else {
        joinPath(currentDirectory(), framework)
    }
    let key = sanitizePathKey(Path(absoluteFramework).normalize().toString())
    joinPath(joinPath(joinPath(home, ".cache/canghui/cuic-sdl"), key), "${platform}-${arch}")
}

func sanitizePathKey(path: String): String {
    let out = StringBuilder()
    for (r in path.toRuneArray()) {
        let c = r.toString()
        if (c == "/" || c == "\\" || c == ":") {
            out.append("_")
        } else {
            out.append(c)
        }
    }
    out.toString()
}

func hostArch(): String {
    let (code, out, _) = executeWithOutput("uname", ["-m"])
    if (code == 0) {
        trimAscii(String.fromUtf8(out))
    } else {
        "unknown"
    }
}

func currentPid(): String {
    let (code, out, _) = executeWithOutput("sh", ["-c", "echo $$"])
    if (code == 0) {
        trimAscii(String.fromUtf8(out))
    } else {
        "unknown"
    }
}

package cuic

import std.collection.ArrayList
import std.convert.*
import std.env.getVariable
import std.fs.exists
import std.process.executeWithOutput

func hdcExecutable(): String {
    let candidates = ArrayList<String>()
    candidates.add("hdc")
    match (getVariable("CANGHUI_HDC")) {
        case Some(value) where value.size > 0 => candidates.add(value)
        case _ => ()
    }
    candidates.add("/Library/Huawei/ohos/toolchains/hdc")
    candidates.add("/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc")
    for (candidate in candidates) {
        if (hdcCandidateAvailable(candidate)) { return candidate }
    }
    throw CuicError("hdc is unavailable; install HarmonyOS toolchain or set CANGHUI_HDC")
}

func hdcCandidateAvailable(candidate: String): Bool {
    if (candidate == "hdc") {
        try {
            let (code, _, _) = executeWithOutput("hdc", ["version"])
            return code == 0
        } catch (_: Exception) { return false }
    }
    exists(candidate)
}

func listHdcTargets(): Array<String> {
    let hdc = hdcExecutable()
    try {
        let (code, out, _) = executeWithOutput(hdc, ["list", "targets"])
        if (code != 0) { return [] }
        parseHdcTargets(String.fromUtf8(out))
    } catch (_: Exception) {
        []
    }
}

func parseHdcTargets(output: String): Array<String> {
    let out = ArrayList<String>()
    for (line in output.split("\n")) {
        let trimmed = trimAscii(line)
        if (trimmed.size == 0) { continue }
        if (trimmed.startsWith("Empty")) { continue }
        let first = trimmed.split(" ")[0]
        if (first.size > 0) { out.add(first) }
    }
    out.toArray()
}

func hasHdcTarget(targets: Array<String>, alias: String): Bool {
    for (target in targets) {
        if (target == alias) { return true }
    }
    false
}

func hdcForward(alias: String, localPort: String, devicePort: String): Bool {
    let hdc = hdcExecutable()
    let rule = "tcp:${localPort} tcp:${devicePort}"
    try {
        let (code, _, _) = executeWithOutput(hdc, ["-t", alias, "fport", rule])
        code == 0
    } catch (_: Exception) {
        false
    }
}

func hdcRecvFile(alias: String, remotePath: String, localPath: String): Bool {
    let hdc = hdcExecutable()
    try {
        let (code, _, _) = executeWithOutput(hdc, ["-t", alias, "file", "recv", remotePath, localPath])
        code == 0
    } catch (_: Exception) {
        false
    }
}

func hdcBundleExists(alias: String, bundle: String): Bool {
    let hdc = hdcExecutable()
    try {
        let (code, out, _) = executeWithOutput(hdc, ["-t", alias, "shell", "bm", "dump", "-n", bundle])
        code == 0 && String.fromUtf8(out).contains(bundle)
    } catch (_: Exception) {
        false
    }
}

func hdcSnapshotDisplay(alias: String, remotePath: String): Bool {
    let hdc = hdcExecutable()
    try {
        let (code, out, _) = executeWithOutput(hdc, ["-t", alias, "shell", "snapshot_display", "-f", remotePath])
        code == 0 && String.fromUtf8(out).contains("success")
    } catch (_: Exception) {
        false
    }
}

func hdcRemoveFile(alias: String, remotePath: String): Bool {
    let hdc = hdcExecutable()
    try {
        let (code, _, _) = executeWithOutput(hdc, ["-t", alias, "shell", "rm", "-f", remotePath])
        code == 0
    } catch (_: Exception) {
        false
    }
}

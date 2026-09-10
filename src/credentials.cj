package SelineRead

import std.env.*
import std.fs.{Directory, File, Path, exists, remove}

// =====================================================================
// 账号凭据持久化
// 位置：%APPDATA%\SelineRead\credentials.json
// 格式：明文 JSON {"email": "...", "password": "..."}
// 说明：暂不加密；后续若要加密，只需替换本文件的读写实现。
// 字符串值转义 \" \\ \n \r \t，非 ASCII 直接按 UTF-8 写入。
// =====================================================================

/** 凭据目录：%APPDATA%\SelineRead（APPDATA 缺失时回退 %USERPROFILE%\AppData\Roaming）。 */
func credentialsDir(): String {
    let appData = match (getVariable("APPDATA")) {
        case Some(a) => a.trimAscii()
        case None => ""
    }
    let base = if (!appData.isEmpty()) {
        appData
    } else {
        match (getVariable("USERPROFILE")) {
            case Some(h) => "${h.trimAscii()}\\AppData\\Roaming"
            case None => "."
        }
    }
    "${base}\\SelineRead"
}

/** 凭据文件路径。 */
func credentialsFile(): String {
    "${credentialsDir()}\\credentials.json"
}

/** JSON 字符串转义。 */
func jsonEscape(s: String): String {
    let sb = StringBuilder()
    for (r in s.runes()) {
        if (r == r'"') {
            sb.append("\\\"")
        } else if (r == r'\\') {
            sb.append("\\\\")
        } else if (r == r'\n') {
            sb.append("\\n")
        } else if (r == r'\r') {
            sb.append("\\r")
        } else if (r == r'\t') {
            sb.append("\\t")
        } else {
            sb.append("${r}")
        }
    }
    sb.toString()
}

/**
 * 取 JSON 顶层字符串字段（只解析本文件写出的格式：对象内 "key": "value" 字符串键值）。
 * 用 Rune 逐个扫描，保证含中文/非 ASCII 的账号密码不会因按字节切分而损坏。
 */
func jsonReadString(text: String, key: String): Option<String> {
    var inString = false
    var escaped = false
    var isKey = false
    var nextIsKey = true
    var lastKey = ""
    var sb = StringBuilder()
    for (r in text.runes()) {
        if (inString) {
            if (escaped) {
                if (r == r'n') {
                    sb.append("\n")
                } else if (r == r'r') {
                    sb.append("\r")
                } else if (r == r't') {
                    sb.append("\t")
                } else {
                    sb.append("${r}")
                }
                escaped = false
            } else if (r == r'\\') {
                escaped = true
            } else if (r == r'"') {
                inString = false
                let value = sb.toString()
                if (isKey) {
                    lastKey = value
                } else if (lastKey == key) {
                    return Some(value)
                }
            } else {
                sb.append("${r}")
            }
        } else {
            if (r == r'"') {
                inString = true
                escaped = false
                isKey = nextIsKey
                sb = StringBuilder()
            } else if (r == r':') {
                nextIsKey = false
            } else if (r == r',') {
                nextIsKey = true
            }
        }
    }
    None
}

/** 保存账号密码（明文 JSON）；失败静默忽略，不影响登录本身。 */
func saveCredentials(email: String, password: String): Unit {
    try {
        let dir = credentialsDir()
        if (!exists(Path(dir))) {
            Directory.create(Path(dir), recursive: true)
        }
        let body = "{\n  \"email\": \"${jsonEscape(email)}\",\n  \"password\": \"${jsonEscape(password)}\"\n}\n"
        File.writeTo(Path(credentialsFile()), body.toArray())
    } catch (_: Exception) {
        ()
    }
}

/** 读取已保存的账号密码；文件不存在/损坏/字段缺失时返回 None。 */
func loadCredentials(): Option<(String, String)> {
    let path = credentialsFile()
    if (!exists(Path(path))) {
        return None
    }
    let bytes = try {
        File.readFrom(Path(path))
    } catch (_: Exception) {
        return None
    }
    if (bytes.size == 0) {
        return None
    }
    let text = try {
        String.fromUtf8(bytes)
    } catch (_: Exception) {
        return None
    }
    let emailOpt = jsonReadString(text, "email")
    let passwordOpt = jsonReadString(text, "password")
    if (emailOpt.isNone() || passwordOpt.isNone()) {
        return None
    }
    let email = emailOpt.getOrThrow()
    let password = passwordOpt.getOrThrow()
    if (email.isEmpty() || password.isEmpty()) {
        return None
    }
    Some((email, password))
}

/** 删除已保存的凭据（登出时调用）。 */
func clearCredentials(): Unit {
    try {
        let path = credentialsFile()
        if (exists(Path(path))) {
            remove(Path(path))
        }
    } catch (_: Exception) {
        ()
    }
}

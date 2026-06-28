package ignite.governance

import std.unicode.*

func containsSensitiveToken(raw: String): Bool {
    let lower = raw.toLower()
    lower.contains("authorization") || lower.contains("cookie") || lower.contains("token") || lower.contains("password")
}

public func redactSensitive(raw: String): String {
    if (containsSensitiveToken(raw)) {
        return "[REDACTED-SENSITIVE]"
    }
    raw
}

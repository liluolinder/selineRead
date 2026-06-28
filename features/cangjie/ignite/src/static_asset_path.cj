package ignite

import std.collection.ArrayList

public func resolveStaticAssetPath(root: String, rawPath: String): ?String {
    let rootPath = root.trimAscii()
    if (rootPath.size == 0) {
        return None
    }
    if (let Some(relativePath) <- normalizeStaticAssetRequestPath(rawPath)) {
        return Some(joinStaticAssetPath(rootPath, relativePath))
    }
    None
}

public func normalizeStaticAssetRequestPath(rawPath: String): ?String {
    let path = rawPath.trimAscii()
    if (path.size == 0 || path == "/") {
        return Some("")
    }

    let segments = ArrayList<String>()
    let chars = path.toRuneArray()
    var current = ""
    var i: Int64 = 0
    while (i < chars.size) {
        let ch = chars[i]
        if (ch == r'/' || ch == r'\\') {
            if (!appendStaticAssetSegment(segments, current)) {
                return None
            }
            current = ""
        } else {
            current += ch.toString()
        }
        i += 1
    }

    if (!appendStaticAssetSegment(segments, current)) {
        return None
    }
    Some(joinStaticAssetSegments(segments))
}

func appendStaticAssetSegment(segments: ArrayList<String>, segment: String): Bool {
    if (segment.size == 0 || segment == ".") {
        return true
    }
    if (segment == "..") {
        return false
    }
    segments.add(segment)
    true
}

func joinStaticAssetSegments(segments: ArrayList<String>): String {
    if (segments.size == 0) {
        return ""
    }
    var out = ""
    var i: Int64 = 0
    while (i < segments.size) {
        if (i > 0) {
            out += "/"
        }
        out += segments[i]
        i += 1
    }
    out
}

func joinStaticAssetPath(root: String, relativePath: String): String {
    if (relativePath.size == 0) {
        return root
    }
    let chars = root.toRuneArray()
    if (chars.size > 0) {
        let tail = chars[chars.size - 1]
        if (tail == r'/' || tail == r'\\') {
            return root + relativePath
        }
    }
    root + "/" + relativePath
}

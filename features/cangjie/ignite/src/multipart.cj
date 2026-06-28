package ignite

import std.collection.{ArrayList, HashMap}
import std.fs.{File, OpenMode}
import std.unicode.*

public class FormFile {
    public let fieldName: String
    public let filename: String
    public let contentType: String
    public let data: Array<UInt8>

    public init(fieldName!: String, filename!: String, contentType!: String, data!: Array<UInt8>) {
        this.fieldName = fieldName
        this.filename = filename
        this.contentType = contentType
        this.data = data
    }

    public func size(): Int64 {
        data.size
    }
}

public class MultipartForm {
    var _fields: HashMap<String, ArrayList<String>> = HashMap<String, ArrayList<String>>()
    var _files: HashMap<String, ArrayList<FormFile>> = HashMap<String, ArrayList<FormFile>>()

    public func value(name: String): ?String {
        match (_fields.get(name)) {
            case Some(list) =>
                if (list.size > 0) { list[0] } else { None }
            case None => None
        }
    }

    public func values(name: String): ArrayList<String> {
        _fields.get(name) ?? ArrayList<String>()
    }

    public func file(name: String): ?FormFile {
        match (_files.get(name)) {
            case Some(list) =>
                if (list.size > 0) { list[0] } else { None }
            case None => None
        }
    }

    public func files(name: String): ArrayList<FormFile> {
        _files.get(name) ?? ArrayList<FormFile>()
    }

    public func fieldNames(): ArrayList<String> {
        let names = ArrayList<String>()
        for ((k, _) in _fields) {
            names.add(k)
        }
        names
    }

    public func fileNames(): ArrayList<String> {
        let names = ArrayList<String>()
        for ((k, _) in _files) {
            names.add(k)
        }
        names
    }

    func addField(name: String, value: String): Unit {
        if (!_fields.contains(name)) {
            _fields.add(name, ArrayList<String>())
        }
        if (let Some(list) <- _fields.get(name)) {
            list.add(value)
        }
    }

    func addFile(name: String, file: FormFile): Unit {
        if (!_files.contains(name)) {
            _files.add(name, ArrayList<FormFile>())
        }
        if (let Some(list) <- _files.get(name)) {
            list.add(file)
        }
    }
}

// ── Multipart Parser ──

public func parseMultipartForm(body: Array<UInt8>, contentType: String): MultipartForm {
    let form = MultipartForm()
    let boundary = extractBoundary(contentType)
    if (boundary.size == 0) {
        return form
    }

    let delimiter = ("--" + boundary).toArray()

    var pos = findBytePattern(body, delimiter, 0)
    if (pos < 0) { return form }

    pos += delimiter.size
    if (pos + 2 <= body.size && body[pos] == 13 && body[pos + 1] == 10) {
        pos += 2
    }

    while (pos < body.size) {
        let nextPos = findBytePattern(body, delimiter, pos)
        if (nextPos < 0) { break }

        var partEnd = nextPos
        if (partEnd >= 2 && body[partEnd - 1] == 10 && body[partEnd - 2] == 13) {
            partEnd -= 2
        }

        if (partEnd > pos) {
            parsePart(body, pos, partEnd, form)
        }

        pos = nextPos + delimiter.size

        if (pos + 2 <= body.size && body[pos] == 45 && body[pos + 1] == 45) {
            break
        }
        if (pos + 2 <= body.size && body[pos] == 13 && body[pos + 1] == 10) {
            pos += 2
        }
    }

    form
}

func parsePart(body: Array<UInt8>, from: Int64, to: Int64, form: MultipartForm): Unit {
    let headerSep = findHeaderBodySeparator(body, from, to)
    if (headerSep < 0) { return }

    let headerBytes = sliceArray(body, from, headerSep)
    let bodyBytes = sliceArray(body, headerSep + 4, to)

    let headerStr = String.fromUtf8(headerBytes)
    let lines = headerStr.split("\r\n")

    var name = ""
    var filename = ""
    var partContentType = ""

    for (line in lines) {
        let lower = line.toLower()
        if (startsWithStr(lower, "content-disposition")) {
            let colonIdx = findRuneIndex(line, r':')
            if (colonIdx >= 0) {
                let dispValue = substringFrom(line, colonIdx + 1).trimAscii()
                name = extractParam(dispValue, "name")
                filename = extractParam(dispValue, "filename")
            }
        } else if (startsWithStr(lower, "content-type")) {
            let colonIdx = findRuneIndex(line, r':')
            if (colonIdx >= 0) {
                partContentType = substringFrom(line, colonIdx + 1).trimAscii()
            }
        }
    }

    if (name.size == 0) { return }

    if (filename.size > 0) {
        let ct = if (partContentType.size > 0) { partContentType } else { "application/octet-stream" }
        let file = FormFile(fieldName: name, filename: filename, contentType: ct, data: bodyBytes)
        form.addFile(name, file)
    } else {
        form.addField(name, String.fromUtf8(bodyBytes))
    }
}

public func saveFormFile(file: FormFile, destPath: String): Unit {
    let f = File(destPath, OpenMode.Write)
    f.write(file.data)
    f.close()
}

// ── Boundary extraction ──

func extractBoundary(contentType: String): String {
    let parts = contentType.split(";")
    for (part in parts) {
        let trimmed = part.trimAscii().toLower()
        if (startsWithStr(trimmed, "boundary")) {
            let original = part.trimAscii()
            let eqIdx = findRuneIndex(original, r'=')
            if (eqIdx >= 0) {
                let val = substringFrom(original, eqIdx + 1).trimAscii()
                return unquoteStr(val)
            }
        }
    }
    ""
}

// ── Byte-level utilities ──

func findBytePattern(data: Array<UInt8>, pattern: Array<UInt8>, start: Int64): Int64 {
    if (pattern.size == 0) { return start }
    if (start + pattern.size > data.size) { return -1 }
    var i = start
    while (i <= data.size - pattern.size) {
        var matched = true
        for (j in 0..pattern.size) {
            if (data[i + j] != pattern[j]) {
                matched = false
                break
            }
        }
        if (matched) { return i }
        i += 1
    }
    -1
}

func findHeaderBodySeparator(data: Array<UInt8>, from: Int64, to: Int64): Int64 {
    var i = from
    while (i + 3 < to) {
        if (data[i] == 13 && data[i + 1] == 10 && data[i + 2] == 13 && data[i + 3] == 10) {
            return i
        }
        i += 1
    }
    -1
}

func sliceArray(data: Array<UInt8>, from: Int64, to: Int64): Array<UInt8> {
    let len = to - from
    if (len <= 0) { return Array<UInt8>(0, repeat: 0) }
    let result = Array<UInt8>(len, repeat: 0)
    for (i in 0..len) {
        result[i] = data[from + i]
    }
    result
}

// ── String utilities ──

func extractParam(header: String, paramName: String): String {
    let parts = header.split(";")
    for (part in parts) {
        let trimmed = part.trimAscii()
        let lower = trimmed.toLower()
        let target = paramName + "="
        if (startsWithStr(lower, target)) {
            let val = substringFrom(trimmed, target.size).trimAscii()
            return unquoteStr(val)
        }
    }
    ""
}

func startsWithStr(s: String, prefix: String): Bool {
    let sRunes = s.toRuneArray()
    let pRunes = prefix.toRuneArray()
    if (pRunes.size > sRunes.size) { return false }
    for (i in 0..pRunes.size) {
        if (sRunes[i] != pRunes[i]) { return false }
    }
    true
}

func containsStr(s: String, sub: String): Bool {
    let sRunes = s.toRuneArray()
    let subRunes = sub.toRuneArray()
    if (subRunes.size == 0) { return true }
    if (subRunes.size > sRunes.size) { return false }
    var i: Int64 = 0
    while (i <= sRunes.size - subRunes.size) {
        var found = true
        for (j in 0..subRunes.size) {
            if (sRunes[i + j] != subRunes[j]) {
                found = false
                break
            }
        }
        if (found) { return true }
        i += 1
    }
    false
}

func findRuneIndex(s: String, target: Rune): Int64 {
    let runes = s.toRuneArray()
    for (i in 0..runes.size) {
        if (runes[i] == target) { return i }
    }
    -1
}

func substringFrom(s: String, idx: Int64): String {
    let runes = s.toRuneArray()
    if (idx >= runes.size) { return "" }
    var result = ""
    for (i in idx..runes.size) {
        result += runes[i].toString()
    }
    result
}

func unquoteStr(s: String): String {
    let runes = s.toRuneArray()
    if (runes.size >= 2 && runes[0] == r'"' && runes[runes.size - 1] == r'"') {
        var result = ""
        for (i in 1..(runes.size - 1)) {
            result += runes[i].toString()
        }
        return result
    }
    s
}

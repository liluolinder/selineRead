package gjson.json_format

import std.collection.ArrayList


public func pretty(json: String): String {
    if (json.isEmpty()) {
        return json
    }
    
    let bytes = ArrayList<Byte>()
    var indentLevel = 0
    let indent: Array<Byte> = [b' ', b' ']
    var inString = false
    var escaped = false
    
    for (i in 0..json.size) {
        let char = json[i]
        
        if (escaped) {
            bytes.add(char)
            escaped = false
            continue
        }
        
        if (char == b'\\' && inString) {
            bytes.add(char)
            escaped = true
            continue
        }
        
        if (char == b'"') {
            bytes.add(char)
            inString = !inString
            continue
        }
        
        if (inString) {
            bytes.add(char)
            continue
        }
        
        match (char) {
            case b'{' | b'[' =>
                bytes.add(char)
                indentLevel++
                bytes.add(b'\n')
                for (j in 0..indentLevel) {
                    for (c in indent) {
                        bytes.add(c)
                    }
                }
            case b'}' | b']' =>
                bytes.add(b'\n')
                indentLevel--
                for (j in 0..indentLevel) {
                    for (c in indent) {
                        bytes.add(c)
                    }
                }
                bytes.add(char)
            case b',' =>
                bytes.add(char)
                bytes.add(b'\n')
                for (j in 0..indentLevel) {
                    for (c in indent) {
                        bytes.add(c)
                    }
                }
            case b':' =>
                bytes.add(char)
                bytes.add(b' ')
            case b' ' | b'\t' | b'\n' | b'\r' =>
                ()
            case _ =>
                bytes.add(char)
        }
    }
    
    unsafe { String.withRawData(bytes.toArray()) }
}

public func ugly(json: String): String {
    if (json.isEmpty()) {
        return json
    }
    
    let bytes = ArrayList<Byte>()
    var inString = false
    var escaped = false
    
    for (i in 0..json.size) {
        let char = json[i]
        
        if (escaped) {
            bytes.add(char)
            escaped = false
            continue
        }
        
        if (char == b'\\' && inString) {
            bytes.add(char)
            escaped = true
            continue
        }
        
        if (char == b'"') {
            bytes.add(char)
            inString = !inString
            continue
        }
        
        if (inString) {
            bytes.add(char)
            continue
        }
        
        match (char) {
            case b' ' | b'\t' | b'\n' | b'\r' =>
                ()
            case _ =>
                bytes.add(char)
        }
    }
    
    unsafe { String.withRawData(bytes.toArray()) }
}
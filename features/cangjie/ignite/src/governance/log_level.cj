package ignite.governance

public class LoggerLevelPolicy {
    public var normalMin: Int64 = 0
    public var normalMax: Int64 = 6
    public var kmodeMin: Int64 = 0
    public var kmodeMax: Int64 = 9

    public init(
        normalMin!: Int64 = 0,
        normalMax!: Int64 = 6,
        kmodeMin!: Int64 = 0,
        kmodeMax!: Int64 = 9
    ) {
        this.normalMin = clampLevel(normalMin)
        this.normalMax = clampLevel(normalMax)
        this.kmodeMin = clampLevel(kmodeMin)
        this.kmodeMax = clampLevel(kmodeMax)
    }

    public func shouldLog(level: Int64, kmode: Bool): Bool {
        let lv = clampLevel(level)
        if (kmode) {
            return lv >= kmodeMin && lv <= kmodeMax
        }
        lv >= normalMin && lv <= normalMax
    }
}

public func clampLevel(level: Int64): Int64 {
    if (level < 0) { return 0 }
    if (level > 9) { return 9 }
    level
}

public func levelName(level: Int64): String {
    match (clampLevel(level)) {
        case 0 => "EMERG"
        case 1 => "ALERT"
        case 2 => "CRIT"
        case 3 => "ERROR"
        case 4 => "WARN"
        case 5 => "NOTICE"
        case 6 => "INFO"
        case 7 => "DEBUG"
        case 8 => "TRACE"
        case _ => "VERBOSE"
    }
}

public func levelColor(level: Int64): String {
    let esc = "\u{1B}"
    match (clampLevel(level)) {
        case 0 | 1 => esc + "[1;97;41m"
        case 2 => esc + "[1;31m"
        case 3 => esc + "[31m"
        case 4 => esc + "[33m"
        case 5 => esc + "[36m"
        case 6 => esc + "[32m"
        case 7 => esc + "[35m"
        case 8 => esc + "[34m"
        case _ => esc + "[90m"
    }
}

public func resetColor(): String {
    "\u{1B}[0m"
}

public func linuxLogLine(
    ts: String,
    level: Int64,
    requestId: String,
    message: String,
    kmode: Bool
): String {
    let tag = levelName(level)
    let color = levelColor(level)
    let reset = resetColor()
    let mode = if (kmode) { "kmode" } else { "normal" }
    "${ts} ${color}[${tag}]${reset} (${mode}) [rid=${requestId}] ${message}"
}

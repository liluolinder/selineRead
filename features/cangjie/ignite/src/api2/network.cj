package ignite.api2

import std.collection.ArrayList
import std.process.executeWithOutput
import std.fs.{File, exists}
import std.regex.Regex
import std.net.{UdpSocket, IPSocketAddress}

public enum StartupNetworkMode <: Equatable<StartupNetworkMode> & ToString {
    | AutoSingle
    | Multi
    | Named

    public operator func ==(right: StartupNetworkMode): Bool {
        ordinalValue() == right.ordinalValue()
    }

    public operator func !=(right: StartupNetworkMode): Bool {
        !(this == right)
    }

    public func ordinalValue(): Int64 {
        match (this) {
            case AutoSingle => 0
            case Multi => 1
            case Named => 2
        }
    }

    public func toString(): String {
        match (this) {
            case AutoSingle => "auto_single"
            case Multi => "multi"
            case Named => "named"
        }
    }
}

public class NetworkInterfaceInfo {
    public let name: String
    public let ips: Array<String>

    public init(name: String, ips: Array<String>) {
        this.name = name
        this.ips = ips
    }
}

public class StartupNetworkSelection {
    public let mode: String
    public let requestedInterface: String
    public let matchedInterface: String
    public let primaryIP: String
    public let displayIPs: Array<String>
    public let displayInterfacePairs: Array<String>
    public let fingerprint: String
    public let warning: String

    public init(
        mode: String,
        requestedInterface: String,
        matchedInterface: String,
        primaryIP: String,
        displayIPs: Array<String>,
        displayInterfacePairs: Array<String>,
        fingerprint: String,
        warning!: String = ""
    ) {
        this.mode = mode
        this.requestedInterface = requestedInterface
        this.matchedInterface = matchedInterface
        this.primaryIP = primaryIP
        this.displayIPs = displayIPs
        this.displayInterfacePairs = displayInterfacePairs
        this.fingerprint = fingerprint
        this.warning = warning
    }
}

/// Device network info: local IP list, default gateway, DNS server list.
public struct NetworkInfo {
    public let ips: Array<String>
    public let gateway: ?String
    public let dns: Array<String>
    public let interfaces: Array<NetworkInterfaceInfo>
    public let preferredIp: ?String

    public init(
        ips: Array<String>,
        gateway: ?String,
        dns: Array<String>,
        interfaces!: Array<NetworkInterfaceInfo> = [],
        preferredIp!: ?String = None
    ) {
        this.ips = ips
        this.gateway = gateway
        this.dns = dns
        this.interfaces = interfaces
        this.preferredIp = preferredIp
    }
}

// ── 获取本机出口 IP：UDP connect + localAddress，无外部命令（仅非 Windows 使用）──

/// Get "local IP for accessing the internet" via UDP socket connect, no external commands.
/// On Windows this is not used (see getNetworkInfo): Windows UDP connect/bind 可能影响进程内后续 bind，导致误报「端口占用」。
public func getPreferredLocalIP(): ?String {
    try {
        let sock = UdpSocket(bindAt: 0)
        sock.bind()
        sock.connect(IPSocketAddress.parse("10.255.255.255:53"))
        let local = sock.localAddress
        sock.close()
        match (local) {
            case sa: IPSocketAddress =>
                let addr = sa.address
                if (addr.isLoopback()) { None } else { Some(addr.toString()) }
            case _ => None
        }
    } catch (_: Exception) {
        None
    }
}

public func selectStartupNetwork(
    info: NetworkInfo,
    mode!: StartupNetworkMode = StartupNetworkMode.AutoSingle,
    interfaceName!: String = ""
): StartupNetworkSelection {
    let trimmedInterface = interfaceName.trimAscii()
    let orderedInterfaces = orderInterfacesForDisplay(info.interfaces, info.preferredIp)

    match (mode) {
        case StartupNetworkMode.Multi =>
            if (orderedInterfaces.size > 0) {
                let displayIPs = collectInterfaceIPs(orderedInterfaces)
                let pairs = buildInterfaceDisplayPairs(orderedInterfaces)
                let primaryIP = if (displayIPs.size > 0) { displayIPs[0] } else { "127.0.0.1" }
                let names = joinInterfaceNames(orderedInterfaces)
                return StartupNetworkSelection(
                    mode.toString(),
                    trimmedInterface,
                    names,
                    primaryIP,
                    displayIPs,
                    pairs,
                    "wildcard:" + mode.toString() + ":" + joinStrings(pairs, ";")
                )
            }
            return fallbackStartupNetworkSelection(info, mode, trimmedInterface, "")
        case StartupNetworkMode.Named =>
            if (trimmedInterface.size == 0) {
                let fallback = selectStartupNetwork(info, mode: StartupNetworkMode.AutoSingle)
                return StartupNetworkSelection(
                    mode.toString(),
                    trimmedInterface,
                    fallback.matchedInterface,
                    fallback.primaryIP,
                    fallback.displayIPs,
                    fallback.displayInterfacePairs,
                    "wildcard:" + mode.toString() + ":" + fallback.fingerprint,
                    warning: buildFallbackWarning(
                        fallback.warning,
                        "startupNetworkMode=named requires startupNetworkInterface; falling back to auto_single."
                    )
                )
            }
            if (let Some(matched) <- findInterfaceByName(orderedInterfaces, trimmedInterface)) {
                let displayIPs = orderIPsForDisplay(matched.ips, preferredIp: info.preferredIp)
                let pairs = buildInterfaceDisplayPairs([matched])
                let primaryIP = if (displayIPs.size > 0) { displayIPs[0] } else { "127.0.0.1" }
                return StartupNetworkSelection(
                    mode.toString(),
                    trimmedInterface,
                    matched.name,
                    primaryIP,
                    displayIPs,
                    pairs,
                    "wildcard:" + mode.toString() + ":" + joinStrings(pairs, ";")
                )
            }
            let fallback = selectStartupNetwork(info, mode: StartupNetworkMode.AutoSingle)
            return StartupNetworkSelection(
                mode.toString(),
                trimmedInterface,
                fallback.matchedInterface,
                fallback.primaryIP,
                fallback.displayIPs,
                fallback.displayInterfacePairs,
                "wildcard:" + mode.toString() + ":" + fallback.fingerprint,
                warning: buildFallbackWarning(
                    fallback.warning,
                    "requested interface '" + trimmedInterface + "' not found; falling back to auto_single."
                )
            )
        case _ =>
            if (orderedInterfaces.size > 0) {
                let selected = choosePrimaryInterface(orderedInterfaces, info.preferredIp)
                let displayIPs = orderIPsForDisplay(selected.ips, preferredIp: info.preferredIp)
                let pairs = buildInterfaceDisplayPairs([selected])
                let primaryIP = if (displayIPs.size > 0) { displayIPs[0] } else { "127.0.0.1" }
                return StartupNetworkSelection(
                    mode.toString(),
                    trimmedInterface,
                    selected.name,
                    primaryIP,
                    displayIPs,
                    pairs,
                    "wildcard:" + mode.toString() + ":" + joinStrings(pairs, ";")
                )
            }
            fallbackStartupNetworkSelection(info, mode, trimmedInterface, "")
    }
}

public func resolveBoundNetworkSelection(
    bindAddr: String,
    mode!: StartupNetworkMode = StartupNetworkMode.AutoSingle,
    interfaceName!: String = "",
    info!: ?NetworkInfo = None
): StartupNetworkSelection {
    let snapshot = if (let Some(existing) <- info) {
        existing
    } else {
        getNetworkInfo()
    }
    if (isWildcardBindAddress(bindAddr)) {
        return selectStartupNetwork(snapshot, mode: mode, interfaceName: interfaceName)
    }

    let trimmedAddr = bindAddr.trimAscii()
    let matchedName = findInterfaceNameByIp(snapshot.interfaces, trimmedAddr) ?? ""
    let hasCurrentIp = containsIP(snapshot.ips, trimmedAddr)
    let pairs = if (matchedName.size > 0) {
        ["${matchedName}=${trimmedAddr}"]
    } else if (trimmedAddr != "127.0.0.1" && trimmedAddr != "::1") {
        ["direct=${trimmedAddr}"]
    } else {
        Array<String>(0, repeat: "")
    }
    let warning = if (
        trimmedAddr != "127.0.0.1" &&
        trimmedAddr != "::1" &&
        !hasCurrentIp
    ) {
        "bound address " + trimmedAddr + " is no longer present in the current local network snapshot."
    } else {
        ""
    }
    let presence = if (hasCurrentIp) { "present" } else { "missing" }
    StartupNetworkSelection(
        "direct",
        interfaceName.trimAscii(),
        matchedName,
        trimmedAddr,
        [trimmedAddr],
        pairs,
        "direct:" + presence + ":" + trimmedAddr + ":" + matchedName,
        warning: warning
    )
}

public func formatStartupNetworkChangeNotice(
    previous: StartupNetworkSelection,
    current: StartupNetworkSelection
): String {
    let previousText = describeStartupNetworkSelection(previous)
    let currentText = describeStartupNetworkSelection(current)
    "startup network selection changed: " + previousText + " -> " + currentText
}

public func describeStartupNetworkSelection(selection: StartupNetworkSelection): String {
    let pairsText = if (selection.displayInterfacePairs.size > 0) {
        joinStrings(selection.displayInterfacePairs, " | ")
    } else {
        joinStrings(selection.displayIPs, " | ")
    }
    if (pairsText.size > 0) {
        return selection.mode + ":" + pairsText
    }
    selection.mode + ":" + selection.primaryIP
}

// ── 多平台：ips 主用 UDP（Linux/macOS），Windows 仅用 ipconfig 避免 UDP 引发误报端口占用 ──

/// Windows：不调用 getPreferredLocalIP()，仅通过 ipconfig 取 IP，避免 UDP 影响后续 HTTP 绑定。
/// ipconfig 输出多为系统代码页（如 GBK），非 UTF-8，String.fromUtf8 会抛 "Invalid unicode scalar value"；解码失败时返回空结果，Banner 显示 0.0.0.0。
@When[os == "Windows"]
public func getNetworkInfo(): NetworkInfo {
    try {
        let (_, stdout, _) = executeWithOutput("cmd", ["/C", "ipconfig", "/all"])
        let text = tryDecodeUtf8OrLossy(stdout)
        let interfaces = orderInterfacesForDisplay(parseWindowsInterfaces(text), None)
        let ips = buildOrderedNetworkInfoIPs(interfaces, parseIPv4s(text), None)
        let gateway = parseWindowsGateway(text)
        let dnsList = parseWindowsDns(text)
        NetworkInfo(
            ips,
            gateway,
            dnsList,
            interfaces: interfaces,
            preferredIp: None
        )
    } catch (_: Exception) {
        NetworkInfo([], None, [])
    }
}

@When[os == "Linux"]
public func getNetworkInfo(): NetworkInfo {
    let preferredIp = getPreferredLocalIP()
    var interfaces: Array<NetworkInterfaceInfo> = []
    if (let Some(text) <- tryReadCommandText("ip", ["-4", "-o", "addr", "show"])) {
        interfaces = parseLinuxInterfaces(text)
    }
    if (interfaces.size == 0) {
        if (let Some(text) <- tryReadCommandText("ifconfig", [])) {
            interfaces = parseIfconfigInterfaces(text)
        }
    }

    var fallbackIps = ArrayList<String>()
    if (let Some(ip) <- preferredIp) {
        appendUnique(fallbackIps, ip)
    }
    if (fallbackIps.size == 0) {
        if (let Some(text) <- tryReadCommandText("hostname", ["-I"])) {
            appendParsedIPv4s(fallbackIps, text)
        }
    }
    if (fallbackIps.size == 0) {
        if (let Some(text) <- tryReadCommandText("ifconfig", [])) {
            appendParsedIPv4s(fallbackIps, text)
        }
    }

    interfaces = orderInterfacesForDisplay(interfaces, preferredIp)
    let ips = buildOrderedNetworkInfoIPs(interfaces, fallbackIps.toArray(), preferredIp)

    var gateway: ?String = None
    if (let Some(text) <- tryReadCommandText("ip", ["route", "show", "default"])) {
        gateway = parseLinuxGateway(text)
    }
    if (let None <- gateway) {
        if (let Some(text) <- tryReadCommandText("route", ["-n"])) {
            gateway = parseLinuxGatewayRouteTable(text)
        }
    }
    let dnsList = readResolvConf("/etc/resolv.conf")
    NetworkInfo(
        ips,
        gateway,
        dnsList,
        interfaces: interfaces,
        preferredIp: preferredIp
    )
}

@When[os == "macOS"]
public func getNetworkInfo(): NetworkInfo {
    let preferredIp = getPreferredLocalIP()
    var interfaces: Array<NetworkInterfaceInfo> = []
    if (let Some(text) <- tryReadCommandText("ifconfig", [])) {
        interfaces = parseIfconfigInterfaces(text)
    }

    var fallbackIps = ArrayList<String>()
    if (let Some(ip) <- preferredIp) {
        appendUnique(fallbackIps, ip)
    }
    if (fallbackIps.size == 0) {
        if (let Some(text) <- tryReadCommandText("ifconfig", [])) {
            appendParsedIPv4s(fallbackIps, text)
        }
    }

    interfaces = orderInterfacesForDisplay(interfaces, preferredIp)
    let ips = buildOrderedNetworkInfoIPs(interfaces, fallbackIps.toArray(), preferredIp)

    var gateway: ?String = None
    if (let Some(text) <- tryReadCommandText("route", ["-n", "get", "default"])) {
        gateway = parseMacOsGateway(text)
    }
    let dnsList = readResolvConf("/etc/resolv.conf")
    NetworkInfo(
        ips,
        gateway,
        dnsList,
        interfaces: interfaces,
        preferredIp: preferredIp
    )
}

// ── Generic parsing: IPv4, resolv.conf ──

func tryReadCommandText(command: String, args: Array<String>): ?String {
    try {
        let (code, stdout, _) = executeWithOutput(command, args)
        if (code != 0) {
            return None
        }
        Some(tryDecodeUtf8OrLossy(stdout))
    } catch (_: Exception) {
        None
    }
}

func appendParsedIPv4s(list: ArrayList<String>, text: String): Unit {
    for (ip in parseIPv4s(text)) {
        appendUnique(list, ip)
    }
}

func appendUnique(list: ArrayList<String>, value: String): Unit {
    for (item in list) {
        if (item == value) {
            return
        }
    }
    list.add(value)
}

func parseIPv4s(text: String): Array<String> {
    let re = Regex(#"\b(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})\b"#)
    let matches = re.findAll(text)
    var list = ArrayList<String>()
    var seen = ArrayList<String>()
    for (md in matches) {
        let s = md.matchString()
        if (s == "127.0.0.1") { continue }
        var found = false
        for (x in seen) {
            if (x == s) { found = true; break }
        }
        if (!found) {
            seen.add(s)
            list.add(s)
        }
    }
    list.toArray()
}

// ── 多网卡自适应：IP 显示优先级，避免 169.254（链路本地）排在前面 ──

/// 0=回环 1=链路本地(169.254) 2=其他/公网 3=私有(10/172.16-31/192.168)，数值越大越优先显示。
func ipDisplayPriority(ip: String): Int64 {
    let parts = ip.split(".")
    if (parts.size != 4) { return 2 }
    let a = parseOctet(parts[0])
    let b = parseOctet(parts[1])
    if (a < 0 || b < 0) { return 2 }
    if (a == 127) { return 0 }
    if (a == 169 && b == 254) { return 1 }
    if (a == 10) { return 3 }
    if (a == 172 && b >= 16 && b <= 31) { return 3 }
    if (a == 192 && b == 168) { return 3 }
    2
}

func parseOctet(s: String): Int64 {
    let runes = s.toRuneArray()
    if (runes.size == 0) { return -1 }
    var n: Int64 = 0
    for (c in runes) {
        if (c < r'0' || c > r'9') { return -1 }
        let d = Int64(UInt32(c)) - Int64(UInt32(r'0'))
        n = n * 10 + d
    }
    if (n > 255) { return -1 }
    n
}

/// 将 IP 列表按「适合展示」排序：私有 > 其他/公网 > 链路本地(169.254) > 回环，并尽量保留 preferredIp 在首位。
func orderIPsForDisplay(ips: Array<String>, preferredIp!: ?String = None): Array<String> {
    var priv = ArrayList<String>()
    var other = ArrayList<String>()
    var linkLocal = ArrayList<String>()
    var loopback = ArrayList<String>()
    for (ip in ips) {
        let p = ipDisplayPriority(ip)
        if (p == 3) { appendUnique(priv, ip) }
        else if (p == 2) { appendUnique(other, ip) }
        else if (p == 1) { appendUnique(linkLocal, ip) }
        else { appendUnique(loopback, ip) }
    }
    var out = ArrayList<String>()
    for (ip in priv) { out.add(ip) }
    for (ip in other) { out.add(ip) }
    for (ip in linkLocal) { out.add(ip) }
    for (ip in loopback) { out.add(ip) }
    if (let Some(preferred) <- preferredIp) {
        let moved = movePreferredIpToFront(out.toArray(), preferred)
        return moved
    }
    out.toArray()
}

func movePreferredIpToFront(ips: Array<String>, preferred: String): Array<String> {
    var out = ArrayList<String>()
    if (containsIP(ips, preferred)) {
        out.add(preferred)
    }
    for (ip in ips) {
        if (ip != preferred) {
            out.add(ip)
        }
    }
    out.toArray()
}

func containsIP(ips: Array<String>, target: String): Bool {
    for (ip in ips) {
        if (ip == target) {
            return true
        }
    }
    false
}

func interfaceDisplayPriority(info: NetworkInterfaceInfo): Int64 {
    var best: Int64 = 0
    for (ip in info.ips) {
        let score = ipDisplayPriority(ip)
        if (score > best) {
            best = score
        }
    }
    best
}

func interfaceContainsIp(info: NetworkInterfaceInfo, target: String): Bool {
    for (ip in info.ips) {
        if (ip == target) {
            return true
        }
    }
    false
}

func orderInterfacesForDisplay(
    interfaces: Array<NetworkInterfaceInfo>,
    preferredIp: ?String
): Array<NetworkInterfaceInfo> {
    var preferred = ArrayList<NetworkInterfaceInfo>()
    var priv = ArrayList<NetworkInterfaceInfo>()
    var other = ArrayList<NetworkInterfaceInfo>()
    var linkLocal = ArrayList<NetworkInterfaceInfo>()
    var loopback = ArrayList<NetworkInterfaceInfo>()
    for (info in interfaces) {
        if (info.ips.size == 0) {
            continue
        }
        if (let Some(ip) <- preferredIp) {
            if (interfaceContainsIp(info, ip)) {
                preferred.add(info)
                continue
            }
        }
        let score = interfaceDisplayPriority(info)
        if (score == 3) { priv.add(info) }
        else if (score == 2) { other.add(info) }
        else if (score == 1) { linkLocal.add(info) }
        else { loopback.add(info) }
    }
    var out = ArrayList<NetworkInterfaceInfo>()
    for (info in preferred) { out.add(info) }
    for (info in priv) { out.add(info) }
    for (info in other) { out.add(info) }
    for (info in linkLocal) { out.add(info) }
    for (info in loopback) { out.add(info) }
    out.toArray()
}

func choosePrimaryInterface(
    interfaces: Array<NetworkInterfaceInfo>,
    preferredIp: ?String
): NetworkInterfaceInfo {
    if (let Some(ip) <- preferredIp) {
        if (let Some(info) <- findInterfaceByIp(interfaces, ip)) {
            return info
        }
    }
    interfaces[0]
}

func collectInterfaceIPs(interfaces: Array<NetworkInterfaceInfo>): Array<String> {
    var list = ArrayList<String>()
    for (info in interfaces) {
        for (ip in orderIPsForDisplay(info.ips, preferredIp: None)) {
            appendUnique(list, ip)
        }
    }
    list.toArray()
}

func buildOrderedNetworkInfoIPs(
    interfaces: Array<NetworkInterfaceInfo>,
    fallbackIps: Array<String>,
    preferredIp: ?String
): Array<String> {
    var list = ArrayList<String>()
    for (ip in collectInterfaceIPs(interfaces)) {
        appendUnique(list, ip)
    }
    for (ip in fallbackIps) {
        appendUnique(list, ip)
    }
    orderIPsForDisplay(list.toArray(), preferredIp: preferredIp)
}

func buildInterfaceDisplayPairs(interfaces: Array<NetworkInterfaceInfo>): Array<String> {
    var pairs = ArrayList<String>()
    for (info in interfaces) {
        if (info.ips.size == 0) {
            continue
        }
        let orderedIps = orderIPsForDisplay(info.ips, preferredIp: None)
        pairs.add(info.name + "=" + joinStrings(orderedIps, "|"))
    }
    pairs.toArray()
}

func joinInterfaceNames(interfaces: Array<NetworkInterfaceInfo>): String {
    var names = ArrayList<String>()
    for (info in interfaces) {
        if (info.name.size > 0) {
            names.add(info.name)
        }
    }
    joinStrings(names.toArray(), ",")
}

func joinStrings(values: Array<String>, sep: String): String {
    if (values.size == 0) {
        return ""
    }
    var out = ""
    var first = true
    for (value in values) {
        if (!first) {
            out += sep
        }
        first = false
        out += value
    }
    out
}

func fallbackStartupNetworkSelection(
    info: NetworkInfo,
    mode: StartupNetworkMode,
    requestedInterface: String,
    reason: String
): StartupNetworkSelection {
    let displayIPs = if (info.ips.size > 0) {
        info.ips
    } else {
        ["127.0.0.1"]
    }
    let primaryIP = if (displayIPs.size > 0) { displayIPs[0] } else { "127.0.0.1" }
    let warning = if (reason.size > 0) {
        reason
    } else if (info.ips.size == 0) {
        "local network inspection returned no non-loopback IPv4 address; using 127.0.0.1."
    } else {
        ""
    }
    StartupNetworkSelection(
        mode.toString(),
        requestedInterface,
        "",
        primaryIP,
        displayIPs,
        Array<String>(0, repeat: ""),
        "wildcard:" + mode.toString() + ":" + joinStrings(displayIPs, "|"),
        warning: warning
    )
}

func buildFallbackWarning(current: String, fallbackMessage: String): String {
    if (current.size > 0) {
        return fallbackMessage + " " + current
    }
    fallbackMessage
}

func isWildcardBindAddress(bindAddr: String): Bool {
    let trimmed = bindAddr.trimAscii()
    trimmed == "0.0.0.0" || trimmed == "::" || trimmed == "[::]"
}

func findInterfaceByName(
    interfaces: Array<NetworkInterfaceInfo>,
    name: String
): ?NetworkInterfaceInfo {
    let normalized = normalizeInterfaceName(name)
    for (info in interfaces) {
        if (normalizeInterfaceName(info.name) == normalized) {
            return Some(info)
        }
    }
    None
}

func findInterfaceByIp(
    interfaces: Array<NetworkInterfaceInfo>,
    ip: String
): ?NetworkInterfaceInfo {
    for (info in interfaces) {
        if (interfaceContainsIp(info, ip)) {
            return Some(info)
        }
    }
    None
}

func findInterfaceNameByIp(
    interfaces: Array<NetworkInterfaceInfo>,
    ip: String
): ?String {
    if (let Some(info) <- findInterfaceByIp(interfaces, ip)) {
        return Some(info.name)
    }
    None
}

func normalizeInterfaceName(raw: String): String {
    raw.trimAscii().toAsciiLower()
}

func readResolvConf(path: String): Array<String> {
    if (!exists(path)) { return [] }
    try {
        let bytes = File.readFrom(path)
        let text = String.fromUtf8(bytes)
        var list = ArrayList<String>()
        let re = Regex(#"nameserver\s+(\S+)"#)
        let matches = re.findAll(text, group: true)
        for (md in matches) {
            if (md.groupCount() >= 1) {
                let s = md.matchString(1)
                if (s.size > 0) { list.add(s) }
            }
        }
        list.toArray()
    } catch (_: Exception) {
        []
    }
}

// ── Windows: ipconfig 输出多为系统代码页，UTF-8 解码失败时做仅保留 ASCII 的兜底（IPv4 为 ASCII）──

func tryDecodeUtf8OrLossy(bytes: Array<UInt8>): String {
    try {
        return String.fromUtf8(bytes)
    } catch (_: Exception) {
        var asciiOnly = ArrayList<UInt8>()
        for (b in bytes) {
            if (b <= 127) { asciiOnly.add(b) }
        }
        try {
            return String.fromUtf8(asciiOnly.toArray())
        } catch (_: Exception) {
            return ""
        }
    }
}

func parseLinuxInterfaces(text: String): Array<NetworkInterfaceInfo> {
    let re = Regex(#"(?m)^\d+:\s+([^\s:@]+)(?:@[^ ]+)?\s+inet\s+(\d{1,3}(?:\.\d{1,3}){3})/"#)
    let matches = re.findAll(text, group: true)
    let builders = ArrayList<NetworkInterfaceBuilder>()
    for (md in matches) {
        if (md.groupCount() < 2) {
            continue
        }
        let name = md.matchString(1).trimAscii()
        let ip = md.matchString(2).trimAscii()
        if (name == "lo" || ip == "127.0.0.1") {
            continue
        }
        appendInterfaceBuilderIp(builders, name, ip)
    }
    finalizeInterfaceBuilders(builders)
}

func parseIfconfigInterfaces(text: String): Array<NetworkInterfaceInfo> {
    let builders = ArrayList<NetworkInterfaceBuilder>()
    var currentName = ""
    let lines = text.split("\n")
    let inetRe = Regex(#"\binet\s+(\d{1,3}(?:\.\d{1,3}){3})\b"#)
    for (line in lines) {
        let trimmedRight = trimLineBreak(line)
        if (trimmedRight.size == 0) {
            continue
        }
        let firstRune = trimmedRight.toRuneArray()[0]
        if (firstRune != r' ' && firstRune != r'\t') {
            currentName = extractIfconfigInterfaceName(trimmedRight)
            continue
        }
        if (currentName.size == 0) {
            continue
        }
        let matches = inetRe.findAll(trimmedRight, group: true)
        if (matches.size == 0) {
            continue
        }
        let ip = matches[0].matchString(1).trimAscii()
        if (ip == "127.0.0.1") {
            continue
        }
        appendInterfaceBuilderIp(builders, currentName, ip)
    }
    finalizeInterfaceBuilders(builders)
}

func extractIfconfigInterfaceName(line: String): String {
    let trimmed = line.trimAscii()
    if (let Some(colon) <- trimmed.indexOf(":")) {
        return sliceText(trimmed, 0, colon)
    }
    let parts = trimmed.split(" ")
    if (parts.size > 0) {
        return parts[0].trimAscii()
    }
    ""
}

func parseWindowsInterfaces(text: String): Array<NetworkInterfaceInfo> {
    let builders = ArrayList<NetworkInterfaceBuilder>()
    let lines = text.split("\n")
    var currentName = ""
    let ipv4Re = Regex(#"(\d{1,3}(?:\.\d{1,3}){3})"#)
    for (line in lines) {
        let trimmed = trimLineBreak(line)
        let compact = trimmed.trimAscii()
        if (compact.size == 0) {
            continue
        }
        if (isWindowsInterfaceHeading(trimmed)) {
            currentName = normalizeWindowsInterfaceHeading(compact)
            continue
        }
        if (currentName.size == 0) {
            continue
        }
        let lower = compact.toAsciiLower()
        if (!lower.contains("ipv4")) {
            continue
        }
        let matches = ipv4Re.findAll(compact, group: true)
        if (matches.size == 0) {
            continue
        }
        let ip = matches[0].matchString(1).trimAscii()
        if (ip == "127.0.0.1") {
            continue
        }
        appendInterfaceBuilderIp(builders, currentName, ip)
    }
    finalizeInterfaceBuilders(builders)
}

func isWindowsInterfaceHeading(line: String): Bool {
    let compact = line.trimAscii()
    if (!compact.endsWith(":")) {
        return false
    }
    let firstRune = line.toRuneArray()[0]
    if (firstRune == r' ' || firstRune == r'\t') {
        return false
    }
    let lower = compact.toAsciiLower()
    lower.contains("adapter") || compact.contains("适配器")
}

func normalizeWindowsInterfaceHeading(raw: String): String {
    var compact = raw
    if (compact.endsWith(":")) {
        compact = sliceText(compact, 0, compact.size - 1)
    }
    let lower = compact.toAsciiLower()
    if (let Some(adapterIndex) <- lower.indexOf("adapter")) {
        let start = adapterIndex + 7
        return sliceText(compact, start, compact.size).trimAscii()
    }
    if (let Some(chineseIndex) <- compact.indexOf("适配器")) {
        let start = chineseIndex + 3
        return sliceText(compact, start, compact.size).trimAscii()
    }
    compact.trimAscii()
}

func trimLineBreak(line: String): String {
    if (line.endsWith("\r")) {
        return sliceText(line, 0, line.size - 1)
    }
    line
}

func sliceText(value: String, start: Int64, end: Int64): String {
    if (start < 0 || end < start) {
        return ""
    }
    let runes = value.toRuneArray()
    if (start >= runes.size) {
        return ""
    }
    let limit = if (end > runes.size) { runes.size } else { end }
    var out = ""
    var i = start
    while (i < limit) {
        out += runes[i].toString()
        i += 1
    }
    out
}

// ── Windows: ipconfig /all 输出解析 ──

func parseWindowsGateway(text: String): ?String {
    // "默认网关" 或 "Default Gateway" 行后跟 IP
    let re = Regex(#"(?i)(?:Default Gateway|默认网关)[\s.:]+(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})"#)
    let arr = re.findAll(text, group: true)
    if (arr.size > 0 && arr[0].groupCount() >= 1) {
        let s = arr[0].matchString(1)
        if (s.size > 0) { return Some(s) }
    }
    None
}

func parseWindowsDns(text: String): Array<String> {
    let re = Regex(#"(?i)(?:DNS Servers|DNS 服务器)[\s.:]+(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})"#)
    let arr = re.findAll(text, group: true)
    var list = ArrayList<String>()
    for (md in arr) {
        if (md.groupCount() >= 1) {
            let s = md.matchString(1)
            if (s.size > 0) { list.add(s) }
        }
    }
    list.toArray()
}

// ── Linux: ip route show default → "default via 192.168.1.1 ..." ──

func parseLinuxGateway(text: String): ?String {
    let re = Regex(#"default\s+via\s+(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})"#)
    let arr = re.findAll(text, group: true)
    if (arr.size > 0 && arr[0].groupCount() >= 1) {
        let s = arr[0].matchString(1)
        if (s.size > 0) { return Some(s) }
    }
    None
}

func parseLinuxGatewayRouteTable(text: String): ?String {
    let re = Regex(#"(?m)^(?:0\.0\.0\.0|default)\s+(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})\b"#)
    let arr = re.findAll(text, group: true)
    if (arr.size > 0 && arr[0].groupCount() >= 1) {
        let s = arr[0].matchString(1)
        if (s.size > 0) { return Some(s) }
    }
    None
}

// ── macOS: route -n get default → "gateway: 192.168.1.1" ──

func parseMacOsGateway(text: String): ?String {
    let re = Regex(#"gateway:\s*(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})"#)
    let arr = re.findAll(text, group: true)
    if (arr.size > 0 && arr[0].groupCount() >= 1) {
        let s = arr[0].matchString(1)
        if (s.size > 0) { return Some(s) }
    }
    None
}

class NetworkInterfaceBuilder {
    let name: String
    let ips = ArrayList<String>()

    init(name: String) {
        this.name = name
    }
}

func appendInterfaceBuilderIp(
    builders: ArrayList<NetworkInterfaceBuilder>,
    name: String,
    ip: String
): Unit {
    let trimmedName = name.trimAscii()
    let trimmedIp = ip.trimAscii()
    if (trimmedName.size == 0 || trimmedIp.size == 0) {
        return
    }
    for (builder in builders) {
        if (normalizeInterfaceName(builder.name) == normalizeInterfaceName(trimmedName)) {
            appendUnique(builder.ips, trimmedIp)
            return
        }
    }
    let builder = NetworkInterfaceBuilder(trimmedName)
    builder.ips.add(trimmedIp)
    builders.add(builder)
}

func finalizeInterfaceBuilders(builders: ArrayList<NetworkInterfaceBuilder>): Array<NetworkInterfaceInfo> {
    var out = ArrayList<NetworkInterfaceInfo>()
    for (builder in builders) {
        if (builder.ips.size == 0) {
            continue
        }
        out.add(NetworkInterfaceInfo(
            builder.name,
            orderIPsForDisplay(builder.ips.toArray(), preferredIp: None)
        ))
    }
    out.toArray()
}

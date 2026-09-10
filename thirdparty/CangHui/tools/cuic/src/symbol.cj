package cuic

import std.collection.{ArrayList, HashSet}
import std.fs.{Directory, File, exists}

let CANGHUI_SYMBOL_CATALOG_PROTOCOL = "canghui.symbol.provider.v0"
let CANGHUI_SYMBOL_GENERATION_PROTOCOL = "canghui.symbol.generation.v0"

class SymbolCatalogEntry {
    let name: String
    let aliases: Array<String>
    let variants: Array<String>
    let directional: Bool
    let sourcePath: String

    init(name: String, aliases: Array<String>, variants: Array<String>, directional: Bool, sourcePath: String) {
        this.name = name
        this.aliases = aliases
        this.variants = variants
        this.directional = directional
        this.sourcePath = sourcePath
    }
}

class SymbolCatalog {
    let provider: String
    let namespace: String
    let providerType: String
    let adapterType: String
    let repository: String
    let revision: String
    let version: String
    let license: String
    let symbols: Array<SymbolCatalogEntry>

    init(provider: String, namespace: String, providerType: String, adapterType: String,
        repository: String, revision: String, version: String, license: String,
        symbols: Array<SymbolCatalogEntry>) {
        this.provider = provider
        this.namespace = namespace
        this.providerType = providerType
        this.adapterType = adapterType
        this.repository = repository
        this.revision = revision
        this.version = version
        this.license = license
        this.symbols = symbols
    }

    func canonicalName(name: String): ?String {
        for (symbol in symbols) {
            if (symbol.name == name) { return Some(symbol.name) }
            for (alias in symbol.aliases) {
                if (alias == name) { return Some(symbol.name) }
            }
        }
        None
    }
}

class SymbolSelection {
    let catalog: SymbolCatalog
    let canonicalName: String
    let exportName: String

    init(catalog: SymbolCatalog, canonicalName: String, exportName: String) {
        this.catalog = catalog
        this.canonicalName = canonicalName
        this.exportName = exportName
    }

    func key(): String { catalog.provider + ":" + canonicalName }
}

class SymbolGenerateOptions {
    let selections: Array<SymbolSelection>
    let output: String
    let packageName: String

    init(selections: Array<SymbolSelection>, output: String, packageName: String) {
        this.selections = selections
        this.output = output
        this.packageName = packageName
    }
}

func symbolCommand(args: Array<String>, start: Int64, framework: String): Int64 {
    let action = if (start < args.size) { args[start] } else { "list" }
    if (action == "list" || action == "discover") {
        return symbolListCommand(args, start + 1, framework)
    }
    if (action == "generate") {
        let options = parseSymbolGenerateOptions(args, start + 1, framework)
        let source = renderGeneratedSymbolRegistry(options)
        let parent = parentPath(options.output)
        if (!parent.isEmpty() && !exists(parent)) { Directory.create(parent, recursive: true) }
        File.writeTo(options.output, source.toArray())
        println(renderSymbolGenerationReceipt(options))
        return 0
    }
    throw CuicError("symbol action must be 'list', 'discover', or 'generate'")
}

func symbolListCommand(args: Array<String>, start: Int64, framework: String): Int64 {
    var provider = ""
    var json = false
    var i = start
    while (i < args.size) {
        let value = args[i]
        if (value == "--json") { json = true; i += 1; continue }
        if (startsWithText(value, "-")) { throw CuicError("unknown symbol list option '${value}'") }
        if (!provider.isEmpty()) { throw CuicError("symbol list accepts one provider") }
        provider = normalizeSymbolProvider(value)
        i += 1
    }
    let catalogs = if (provider.isEmpty()) {
        loadSymbolCatalogs(framework)
    } else {
        [loadSymbolCatalog(framework, provider)]
    }
    if (json) {
        println(renderSymbolCatalogJson(catalogs))
        return 0
    }
    for (catalog in catalogs) {
        println("${catalog.provider} (${catalog.symbols.size}) ${catalog.license} ${catalog.revision}")
        if (!provider.isEmpty()) {
            for (symbol in catalog.symbols) {
                let aliases = if (symbol.aliases.isEmpty()) { "" } else { " aliases=" + joinSymbolValues(symbol.aliases) }
                println("  ${symbol.name} variants=${joinSymbolValues(symbol.variants)}${aliases}")
            }
        }
    }
    0
}

func parseSymbolGenerateOptions(args: Array<String>, start: Int64, framework: String): SymbolGenerateOptions {
    let rawSelections = ArrayList<String>()
    var output = ""
    var packageName = "generated"
    var i = start
    while (i < args.size) {
        let value = args[i]
        if (value == "--output" || value == "--package") {
            if (i + 1 >= args.size) { throw CuicError("${value} requires a value") }
            if (value == "--output") { output = args[i + 1] } else { packageName = args[i + 1] }
            i += 2
            continue
        }
        if (startsWithText(value, "-")) { throw CuicError("unknown symbol generate option '${value}'") }
        rawSelections.add(value)
        i += 1
    }
    if (rawSelections.isEmpty()) {
        throw CuicError("symbol generate requires at least one provider:name selection")
    }
    if (output.isEmpty()) { throw CuicError("symbol generate requires --output <file.cj>") }
    if (sanitizePackageName(packageName) != packageName) {
        throw CuicError("generated symbol package must use a lowercase Cangjie package name")
    }
    let catalogs = loadSymbolCatalogs(framework)
    let selections = ArrayList<SymbolSelection>()
    let canonicalKeys = HashSet<String>()
    let exports = ArrayList<SymbolSelection>()
    for (raw in rawSelections) {
        let parsed = parseSymbolSelection(raw, catalogs)
        if (canonicalKeys.contains(parsed.key())) {
            throw CuicError("duplicate canonical symbol selection: " + parsed.key())
        }
        for (existing in exports) {
            if (existing.exportName == parsed.exportName) {
                let kind = if (existing.catalog.provider == parsed.catalog.provider) {
                    "duplicate generated symbol alias"
                } else {
                    "cross-provider generated symbol alias collision"
                }
                throw CuicError(kind + ": " + parsed.exportName)
            }
        }
        canonicalKeys.add(parsed.key())
        exports.add(parsed)
        selections.add(parsed)
    }
    SymbolGenerateOptions(sortSymbolSelections(selections.toArray()), output, packageName)
}

func parseSymbolSelection(raw: String, catalogs: Array<SymbolCatalog>): SymbolSelection {
    let aliasParts = raw.split("@")
    if (aliasParts.size > 2 || aliasParts[0].isEmpty()) {
        throw CuicError("invalid symbol selection '${raw}'; use provider:name[@export]")
    }
    let identity = aliasParts[0]
    let separator = indexOfText(identity, ":")
    if (separator <= 0 || separator >= identity.toRuneArray().size - 1) {
        throw CuicError("invalid symbol selection '${raw}'; use provider:name[@export]")
    }
    let provider = normalizeSymbolProvider(substringTo(identity, separator))
    let requested = substringFrom(identity, separator + 1)
    let catalog = findSymbolCatalog(catalogs, provider)
    let canonical = match (catalog.canonicalName(requested)) {
        case Some(value) => value
        case None => throw CuicError("unknown ${provider} symbol '${requested}'")
    }
    let exportName = if (aliasParts.size == 2) { aliasParts[1] } else {
        sanitizePackageName(provider + "_" + replaceSymbolHyphens(canonical))
    }
    if (exportName.isEmpty() || sanitizePackageName(exportName) != exportName) {
        throw CuicError("generated symbol export must use lowercase letters, digits, and underscores: " + exportName)
    }
    SymbolSelection(catalog, canonical, exportName)
}

func loadSymbolCatalogs(framework: String): Array<SymbolCatalog> {
    [
        loadSymbolCatalog(framework, "material"),
        loadSymbolCatalog(framework, "ant"),
        loadSymbolCatalog(framework, "arco")
    ]
}

func loadSymbolCatalog(framework: String, providerValue: String): SymbolCatalog {
    let provider = normalizeSymbolProvider(providerValue)
    let path = joinPath(framework, "packages/symbol-${provider}/symbols.catalog")
    requireFile(path, "symbol provider catalog is missing: ${provider}")
    let catalog = parseSymbolCatalog(String.fromUtf8(File.readFrom(path)), path)
    if (catalog.provider != provider) {
        throw CuicError("symbol catalog provider mismatch in ${path}: ${catalog.provider} != ${provider}")
    }
    catalog
}

func parseSymbolCatalog(text: String, location: String): SymbolCatalog {
    var protocolSeen = false
    var provider = ""
    var namespace = ""
    var providerType = ""
    var adapterType = ""
    var repository = ""
    var revision = ""
    var version = ""
    var license = ""
    let symbols = ArrayList<SymbolCatalogEntry>()
    for (raw in text.split("\n")) {
        let line = trimAscii(raw)
        if (line.isEmpty() || startsWithText(line, "#")) { continue }
        if (!protocolSeen) {
            if (line != CANGHUI_SYMBOL_CATALOG_PROTOCOL) {
                throw CuicError("invalid symbol catalog protocol in ${location}")
            }
            protocolSeen = true
            continue
        }
        let separator = indexOfText(line, "=")
        if (separator <= 0) { throw CuicError("invalid symbol catalog line in ${location}: ${line}") }
        let key = substringTo(line, separator)
        let value = substringFrom(line, separator + 1)
        if (key == "provider") { provider = value }
        else if (key == "namespace") { namespace = value }
        else if (key == "providerType") { providerType = value }
        else if (key == "adapterType") { adapterType = value }
        else if (key == "repository") { repository = value }
        else if (key == "revision") { revision = value }
        else if (key == "version") { version = value }
        else if (key == "license") { license = value }
        else if (key == "symbol") { symbols.add(parseSymbolCatalogEntry(value, location)) }
        else { throw CuicError("unknown symbol catalog field '${key}' in ${location}") }
    }
    if (!protocolSeen || provider.isEmpty() || namespace.isEmpty() || providerType.isEmpty() ||
        adapterType.isEmpty() || repository.isEmpty() || revision.isEmpty() || version.isEmpty() ||
        license.isEmpty() || symbols.isEmpty()) {
        throw CuicError("incomplete symbol catalog: ${location}")
    }
    validateSymbolCatalogMetadata(provider, namespace, providerType, adapterType, location)
    validateSymbolCatalogNames(provider, symbols.toArray(), location)
    SymbolCatalog(provider, namespace, providerType, adapterType, repository, revision, version, license,
        sortSymbolCatalogEntries(symbols.toArray()))
}

func parseSymbolCatalogEntry(value: String, location: String): SymbolCatalogEntry {
    let parts = value.split("|")
    if (parts.isEmpty() || parts[0].isEmpty()) { throw CuicError("empty symbol entry in ${location}") }
    let name = parts[0]
    var aliases: Array<String> = []
    var variants: Array<String> = []
    var directional = false
    var sourcePath = ""
    var i: Int64 = 1
    while (i < parts.size) {
        let separator = indexOfText(parts[i], "=")
        if (separator <= 0) { throw CuicError("invalid symbol entry field in ${location}: ${parts[i]}") }
        let key = substringTo(parts[i], separator)
        let field = substringFrom(parts[i], separator + 1)
        if (key == "aliases") { aliases = splitSymbolValues(field) }
        else if (key == "variants") { variants = splitSymbolValues(field) }
        else if (key == "directional") {
            if (field != "true" && field != "false") { throw CuicError("invalid directional value in ${location}") }
            directional = field == "true"
        } else if (key == "source") { sourcePath = field }
        else { throw CuicError("unknown symbol entry field '${key}' in ${location}") }
        i += 1
    }
    if (variants.isEmpty() || sourcePath.isEmpty()) {
        throw CuicError("symbol entry requires variants and source in ${location}: ${name}")
    }
    SymbolCatalogEntry(name, aliases, variants, directional, sourcePath)
}

func renderGeneratedSymbolRegistry(options: SymbolGenerateOptions): String {
    let out = StringBuilder()
    out.append("// Generated by cuic symbol generate. Declared subset only.\n")
    out.append("package ")
    out.append(options.packageName)
    out.append("\n\nimport chui.{SymbolName, Symbols}\n")
    for (catalog in selectedCatalogs(options.selections)) {
        out.append("import ")
        out.append(catalog.namespace)
        out.append(".{")
        out.append(catalog.adapterType)
        out.append(", ")
        out.append(catalog.providerType)
        out.append("}\n")
    }
    out.append("\n")
    for (selection in options.selections) {
        out.append("public let ")
        out.append(selection.exportName)
        out.append(" = SymbolName(\"")
        out.append(selection.canonicalName)
        out.append("\", provider: \"")
        out.append(selection.catalog.provider)
        out.append("\")\n")
    }
    out.append("\nprivate var canghuiSymbolsRegistered = false\n\n")
    out.append("public func registerCangHuiSymbols(): Unit {\n")
    out.append("    if (canghuiSymbolsRegistered) { return }\n")
    for (catalog in selectedCatalogs(options.selections)) {
        out.append("    Symbols.register(")
        out.append(catalog.providerType)
        out.append("(included: [")
        let names = selectedNames(options.selections, catalog.provider)
        var first = true
        for (name in names) {
            if (!first) { out.append(", ") }
            first = false
            out.append("\"")
            out.append(name)
            out.append("\"")
        }
        out.append("]), ")
        out.append(catalog.adapterType)
        out.append("())\n")
    }
    out.append("    canghuiSymbolsRegistered = true\n")
    out.append("}\n")
    out.toString()
}

func renderSymbolGenerationReceipt(options: SymbolGenerateOptions): String {
    let out = StringBuilder()
    out.append("{\"schema\":")
    out.append(cuicJsonQuote(CANGHUI_SYMBOL_GENERATION_PROTOCOL))
    out.append(",\"output\":")
    out.append(cuicJsonQuote(options.output))
    out.append(",\"package\":")
    out.append(cuicJsonQuote(options.packageName))
    out.append(",\"symbols\":[")
    var first = true
    for (selection in options.selections) {
        if (!first) { out.append(",") }
        first = false
        out.append("{\"provider\":")
        out.append(cuicJsonQuote(selection.catalog.provider))
        out.append(",\"name\":")
        out.append(cuicJsonQuote(selection.canonicalName))
        out.append(",\"export\":")
        out.append(cuicJsonQuote(selection.exportName))
        out.append("}")
    }
    out.append("]}")
    out.toString()
}

func renderSymbolCatalogJson(catalogs: Array<SymbolCatalog>): String {
    let out = StringBuilder()
    out.append("{\"schema\":\"canghui.symbol.catalog.v0\",\"providers\":[")
    var firstCatalog = true
    for (catalog in catalogs) {
        if (!firstCatalog) { out.append(",") }
        firstCatalog = false
        out.append("{\"id\":")
        out.append(cuicJsonQuote(catalog.provider))
        out.append(",\"repository\":")
        out.append(cuicJsonQuote(catalog.repository))
        out.append(",\"revision\":")
        out.append(cuicJsonQuote(catalog.revision))
        out.append(",\"version\":")
        out.append(cuicJsonQuote(catalog.version))
        out.append(",\"license\":")
        out.append(cuicJsonQuote(catalog.license))
        out.append(",\"symbols\":[")
        var firstSymbol = true
        for (symbol in catalog.symbols) {
            if (!firstSymbol) { out.append(",") }
            firstSymbol = false
            out.append("{\"name\":")
            out.append(cuicJsonQuote(symbol.name))
            out.append(",\"aliases\":[")
            appendJsonStringArray(out, symbol.aliases)
            out.append("],\"variants\":[")
            appendJsonStringArray(out, symbol.variants)
            out.append("],\"directional\":")
            out.append(symbol.directional.toString())
            out.append(",\"sourcePath\":")
            out.append(cuicJsonQuote(symbol.sourcePath))
            out.append("}")
        }
        out.append("]}")
    }
    out.append("]}")
    out.toString()
}

func normalizeSymbolProvider(value: String): String {
    let lower = asciiLowerText(value)
    if (lower == "material" || lower == "material-design" || lower == "md") { return "material" }
    if (lower == "ant" || lower == "antd" || lower == "ant-design") { return "ant" }
    if (lower == "arco" || lower == "acro" || lower == "arco-design") { return "arco" }
    throw CuicError("unknown symbol provider '${value}'")
}

private func findSymbolCatalog(catalogs: Array<SymbolCatalog>, provider: String): SymbolCatalog {
    for (catalog in catalogs) {
        if (catalog.provider == provider) { return catalog }
    }
    throw CuicError("symbol provider catalog is not loaded: " + provider)
}

private func selectedCatalogs(selections: Array<SymbolSelection>): Array<SymbolCatalog> {
    let out = ArrayList<SymbolCatalog>()
    for (selection in selections) {
        var found = false
        for (catalog in out) {
            if (catalog.provider == selection.catalog.provider) { found = true; break }
        }
        if (!found) { out.add(selection.catalog) }
    }
    let values = out.toArray()
    var i: Int64 = 0
    while (i < values.size) {
        var j = i + 1
        while (j < values.size) {
            if (values[j].provider < values[i].provider) {
                let current = values[i]
                values[i] = values[j]
                values[j] = current
            }
            j += 1
        }
        i += 1
    }
    values
}

private func selectedNames(selections: Array<SymbolSelection>, provider: String): Array<String> {
    let out = ArrayList<String>()
    for (selection in selections) {
        if (selection.catalog.provider == provider) { out.add(selection.canonicalName) }
    }
    let values = out.toArray()
    var i: Int64 = 0
    while (i < values.size) {
        var j = i + 1
        while (j < values.size) {
            if (values[j] < values[i]) {
                let current = values[i]
                values[i] = values[j]
                values[j] = current
            }
            j += 1
        }
        i += 1
    }
    values
}

private func validateSymbolCatalogNames(provider: String, symbols: Array<SymbolCatalogEntry>, location: String): Unit {
    let names = HashSet<String>()
    let aliases = HashSet<String>()
    for (symbol in symbols) {
        validateSymbolCatalogToken(symbol.name, "canonical symbol name", location)
        validateSymbolSourcePath(symbol.sourcePath, location)
        for (variant in symbol.variants) { validateSymbolVariant(variant, location) }
        if (names.contains(symbol.name)) {
            throw CuicError("duplicate canonical symbol name '${provider}:${symbol.name}' in ${location}")
        }
        names.add(symbol.name)
    }
    for (symbol in symbols) {
        for (alias in symbol.aliases) {
            validateSymbolCatalogToken(alias, "symbol alias", location)
            if (names.contains(alias) || aliases.contains(alias)) {
                throw CuicError("duplicate symbol alias '${provider}:${alias}' in ${location}")
            }
            aliases.add(alias)
        }
    }
}

private func validateSymbolCatalogMetadata(provider: String, namespace: String,
    providerType: String, adapterType: String, location: String): Unit {
    validateSymbolCatalogToken(provider, "provider id", location)
    if (!isCangjiePackageIdentifier(namespace)) {
        throw CuicError("invalid symbol provider namespace '${namespace}' in ${location}")
    }
    if (!isCangjieTypeIdentifier(providerType)) {
        throw CuicError("invalid symbol provider type '${providerType}' in ${location}")
    }
    if (!isCangjieTypeIdentifier(adapterType)) {
        throw CuicError("invalid symbol adapter type '${adapterType}' in ${location}")
    }
}

private func validateSymbolCatalogToken(value: String, label: String, location: String): Unit {
    let runes = value.toRuneArray()
    if (runes.isEmpty()) { throw CuicError("empty ${label} in ${location}") }
    var segmentStart = true
    for (r in runes) {
        let lower = r >= r'a' && r <= r'z'
        let digit = r >= r'0' && r <= r'9'
        if (r == r'-') {
            if (segmentStart) { throw CuicError("invalid ${label} '${value}' in ${location}") }
            segmentStart = true
        } else {
            if ((!lower && !digit) || (segmentStart && digit)) {
                throw CuicError("invalid ${label} '${value}' in ${location}")
            }
            segmentStart = false
        }
    }
    if (segmentStart) { throw CuicError("invalid ${label} '${value}' in ${location}") }
}

private func isCangjiePackageIdentifier(value: String): Bool {
    let runes = value.toRuneArray()
    if (runes.isEmpty()) { return false }
    var segmentStart = true
    for (r in runes) {
        if (r == r'.') {
            if (segmentStart) { return false }
            segmentStart = true
            continue
        }
        let lower = r >= r'a' && r <= r'z'
        let digit = r >= r'0' && r <= r'9'
        if (!lower && !digit && r != r'_') { return false }
        if (segmentStart && digit) { return false }
        segmentStart = false
    }
    !segmentStart
}

private func isCangjieTypeIdentifier(value: String): Bool {
    let runes = value.toRuneArray()
    if (runes.isEmpty()) { return false }
    var i: Int64 = 0
    while (i < runes.size) {
        let r = runes[i]
        let letter = (r >= r'a' && r <= r'z') || (r >= r'A' && r <= r'Z')
        let digit = r >= r'0' && r <= r'9'
        if (!letter && !digit && r != r'_') { return false }
        if (i == 0 && digit) { return false }
        i += 1
    }
    true
}

private func validateSymbolVariant(value: String, location: String): Unit {
    if (value != "outlined" && value != "filled" && value != "rounded" && value != "sharp") {
        throw CuicError("unsupported symbol variant '${value}' in ${location}")
    }
}

private func validateSymbolSourcePath(value: String, location: String): Unit {
    if (value.isEmpty() || startsWithText(value, "/") || startsWithText(value, "\\") ||
        isWindowsAbsolute(value) || containsText(value, "\\")) {
        throw CuicError("symbol source path must be relative and use forward slashes in ${location}: ${value}")
    }
    for (segment in value.split("/")) {
        if (segment.isEmpty() || segment == "." || segment == "..") {
            throw CuicError("symbol source path has an unsafe segment in ${location}: ${value}")
        }
    }
}

private func sortSymbolSelections(values: Array<SymbolSelection>): Array<SymbolSelection> {
    var i: Int64 = 0
    while (i < values.size) {
        var j = i + 1
        while (j < values.size) {
            if (values[j].key() < values[i].key()) {
                let current = values[i]
                values[i] = values[j]
                values[j] = current
            }
            j += 1
        }
        i += 1
    }
    values
}

private func sortSymbolCatalogEntries(values: Array<SymbolCatalogEntry>): Array<SymbolCatalogEntry> {
    var i: Int64 = 0
    while (i < values.size) {
        var j = i + 1
        while (j < values.size) {
            if (values[j].name < values[i].name) {
                let current = values[i]
                values[i] = values[j]
                values[j] = current
            }
            j += 1
        }
        i += 1
    }
    values
}

private func splitSymbolValues(value: String): Array<String> {
    if (value.isEmpty()) { return [] }
    let out = ArrayList<String>()
    for (part in value.split(",")) {
        let trimmed = trimAscii(part)
        if (!trimmed.isEmpty()) { out.add(trimmed) }
    }
    out.toArray()
}

private func joinSymbolValues(values: Array<String>): String {
    let out = StringBuilder()
    var first = true
    for (value in values) {
        if (!first) { out.append(",") }
        first = false
        out.append(value)
    }
    out.toString()
}

private func appendJsonStringArray(out: StringBuilder, values: Array<String>): Unit {
    var first = true
    for (value in values) {
        if (!first) { out.append(",") }
        first = false
        out.append(cuicJsonQuote(value))
    }
}

private func replaceSymbolHyphens(value: String): String {
    let out = StringBuilder()
    for (r in value.toRuneArray()) {
        out.append(if (r == r'-') { "_" } else { r.toString() })
    }
    out.toString()
}

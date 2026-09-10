macro package chui.kmode.macros

import std.ast.*
public import chui.kmode.{KModeCapability, KModeRegistration}
public import chui.probe.ProbeRegistration

/**
 * Links one top-level (String) -> String function into the kMode registry.
 * The generated symbol is derived from the endpoint name, so duplicates in
 * one package fail during compilation before runtime registration.
 */
public macro KModeLink(attr: Tokens, input: Tokens): Tokens {
    let funcDecl = FuncDecl(input)
    let endpointName = parseEndpointName(attr)
    validateSignature(funcDecl)
    let symbol = Token(
        TokenKind.IDENTIFIER,
        "__canghui_kmode_link_" + endpointSymbol(endpointName)
    )
    let description = "linked function " + funcDecl.identifier.value
    return quote(
        $(input)
        public let $(symbol) = KModeRegistration(
            $(attr),
            $(description),
            KModeCapability.Invoke,
            { value: String => $(funcDecl.identifier)(value) }
        )
    )
}

/**
 * Registers one bounded string-in/string-out debug or test probe. The generated symbol
 * makes duplicate names in one package a compile-time error; the registry remains the
 * cross-package runtime backstop.
 */
public macro CuiProbe(attr: Tokens, input: Tokens): Tokens {
    let funcDecl = FuncDecl(input)
    let probeName = parseProbeName(attr)
    validateProbeSignature(funcDecl)
    let symbol = Token(
        TokenKind.IDENTIFIER,
        "__canghui_probe_" + endpointSymbol(probeName)
    )
    let description = "probe function " + funcDecl.identifier.value
    return quote(
        $(input)
        public let $(symbol) = ProbeRegistration(
            $(attr),
            $(description),
            { value: String => $(funcDecl.identifier)(value) }
        )
    )
}

func parseEndpointName(attr: Tokens): String {
    let raw = attr.toString()
    if (!raw.startsWith("\"") || !raw.endsWith("\"") || raw.size < 3) {
        throw Exception("KModeLink requires one string endpoint name")
    }
    let value = raw[1..raw.size - 1]
    validateEndpointName(value)
    value
}

func parseProbeName(attr: Tokens): String {
    let raw = attr.toString()
    if (!raw.startsWith("\"") || !raw.endsWith("\"") || raw.size < 3) {
        throw Exception("CuiProbe requires one string probe name")
    }
    let value = raw[1..raw.size - 1]
    validateProbeMacroName(value)
    value
}

func validateSignature(funcDecl: FuncDecl): Unit {
    if (funcDecl.funcParams.size != 1) {
        throw Exception("KModeLink requires exactly one String parameter")
    }
    let parameterType = funcDecl.funcParams[0].paramType.toTokens().toString()
    let returnType = funcDecl.declType.toTokens().toString()
    if (parameterType != "String" || returnType != "String") {
        throw Exception("KModeLink function signature must be (String) -> String")
    }
}

func validateProbeSignature(funcDecl: FuncDecl): Unit {
    if (funcDecl.funcParams.size != 1) {
        throw Exception("CuiProbe requires exactly one String parameter")
    }
    let parameterType = funcDecl.funcParams[0].paramType.toTokens().toString()
    let returnType = funcDecl.declType.toTokens().toString()
    if (parameterType != "String" || returnType != "String") {
        throw Exception("CuiProbe function signature must be (String) -> String")
    }
}

func validateEndpointName(value: String): Unit {
    var segmentStart = true
    for (r in value.toRuneArray()) {
        if (r == r'.') {
            if (segmentStart) {
                throw Exception("KModeLink endpoint has an empty segment")
            }
            segmentStart = true
        } else {
            let letter = (r >= r'a' && r <= r'z') || (r >= r'A' && r <= r'Z')
            let digit = r >= r'0' && r <= r'9'
            if ((!letter && !digit) || (segmentStart && digit)) {
                throw Exception(
                    "KModeLink endpoint segments accept letters/digits and start with a letter"
                )
            }
            segmentStart = false
        }
    }
    if (segmentStart) {
        throw Exception("KModeLink endpoint must not be empty or end with a dot")
    }
}

func validateProbeMacroName(value: String): Unit {
    var segmentStart = true
    for (r in value.toRuneArray()) {
        if (r == r'.') {
            if (segmentStart) { throw Exception("CuiProbe name has an empty segment") }
            segmentStart = true
        } else {
            let letter = (r >= r'a' && r <= r'z') || (r >= r'A' && r <= r'Z')
            let digit = r >= r'0' && r <= r'9'
            let allowed = letter || digit || r == r'-' || r == r'_'
            if (!allowed || (segmentStart && !letter)) {
                throw Exception("CuiProbe segments must start with a letter and use letters, digits, '-' or '_'")
            }
            segmentStart = false
        }
    }
    if (segmentStart) { throw Exception("CuiProbe name must not be empty or end with a dot") }
}

func endpointSymbol(value: String): String {
    var out = "p"
    for (r in value.toRuneArray()) {
        out += "_" + UInt32(r).toString()
    }
    out
}

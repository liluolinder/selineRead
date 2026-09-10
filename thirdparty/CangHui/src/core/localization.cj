package chui.core

import std.collection.HashMap

/** A BCP47-style application locale with one explicit fallback locale. */
public class LocaleTag {
    public let tag: String
    public let fallbackTag: String

    public init(tag: String, fallbackTag!: String = "") {
        if (tag.isEmpty()) {
            throw IllegalArgumentException("Locale tag must not be empty")
        }
        this.tag = tag
        this.fallbackTag = fallbackTag
    }

    public static func english(): LocaleTag {
        LocaleTag("en")
    }

    public static func traditionalChinese(): LocaleTag {
        LocaleTag("zh-Hant", fallbackTag: "zh")
    }
}

/**
 * Small deterministic localization catalog for application-owned strings.
 *
 * Resolution order is exact locale, explicit locale fallback, catalog default,
 * default-locale fallback, caller fallback, then the key itself. The catalog
 * intentionally does not prescribe JSON, TOML, code generation, or host resource
 * packaging; platform adapters can populate it from any source.
 */
public class LocalizationCatalog {
    public let defaultLocale: LocaleTag
    private let entries = HashMap<String, String>()

    public init(defaultLocale!: LocaleTag = LocaleTag.english()) {
        this.defaultLocale = defaultLocale
    }

    public func put(locale: LocaleTag, key: String, value: String): Unit {
        validateKey(key)
        entries[entryKey(locale.tag, key)] = value
    }

    public func put(localeTag: String, key: String, value: String): Unit {
        put(LocaleTag(localeTag), key, value)
    }

    public func contains(locale: LocaleTag, key: String): Bool {
        entries.contains(entryKey(locale.tag, key))
    }

    public func resolve(key: String, locale: LocaleTag, fallback!: String = ""): String {
        validateKey(key)
        match (lookup(locale.tag, key)) {
            case Some(value) => return value
            case None => ()
        }
        if (!locale.fallbackTag.isEmpty() && locale.fallbackTag != locale.tag) {
            match (lookup(locale.fallbackTag, key)) {
                case Some(value) => return value
                case None => ()
            }
        }
        if (defaultLocale.tag != locale.tag) {
            match (lookup(defaultLocale.tag, key)) {
                case Some(value) => return value
                case None => ()
            }
        }
        if (!defaultLocale.fallbackTag.isEmpty() && defaultLocale.fallbackTag != defaultLocale.tag &&
            defaultLocale.fallbackTag != locale.tag && defaultLocale.fallbackTag != locale.fallbackTag) {
            match (lookup(defaultLocale.fallbackTag, key)) {
                case Some(value) => return value
                case None => ()
            }
        }
        if (!fallback.isEmpty()) { fallback } else { key }
    }

    private func lookup(localeTag: String, key: String): ?String {
        entries.get(entryKey(localeTag, key))
    }

    private func validateKey(key: String): Unit {
        if (key.isEmpty()) {
            throw IllegalArgumentException("Localization key must not be empty")
        }
    }
}

private func entryKey(localeTag: String, key: String): String {
    "${localeTag}::${key}"
}

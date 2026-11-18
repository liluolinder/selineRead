package mirrors

import java.lang.*

@JavaMirror["java.util.Locale"]
public class Locale <: Cloneable & Serializable {
    public static let CANADA: Locale

    public static let CANADA_FRENCH: Locale

    public static let CHINA: Locale

    public static let CHINESE: Locale

    public static let ENGLISH: Locale

    public static let FRANCE: Locale

    public static let FRENCH: Locale

    public static let GERMAN: Locale

    public static let GERMANY: Locale

    public static let ITALIAN: Locale

    public static let ITALY: Locale

    public static let JAPAN: Locale

    public static let JAPANESE: Locale

    public static let KOREA: Locale

    public static let KOREAN: Locale

    public static let PRC: Locale

    public static let PRIVATE_USE_EXTENSION: UInt16

    public static let ROOT: Locale

    public static let SIMPLIFIED_CHINESE: Locale

    public static let TAIWAN: Locale

    public static let TRADITIONAL_CHINESE: Locale

    public static let UK: Locale

    public static let UNICODE_LOCALE_EXTENSION: UInt16

    public static let US: Locale

    public init(language: ?JString, country: ?JString, variant: ?JString)

    public init(language: ?JString, country: ?JString)

    public init(language: ?JString)

    public static func getDefault(): ?Locale

    public static func setDefault(newLocale: ?Locale): Unit

    public static func getAvailableLocales(): ?JArray<?Locale>

    public static func getISOCountries(): ?JArray<?JString>

    public static func getISOLanguages(): ?JArray<?JString>

    public func getLanguage(): ?JString

    public func getScript(): ?JString

    public func getCountry(): ?JString

    public func getVariant(): ?JString

    public func hasExtensions(): Bool

    public func stripExtensions(): ?Locale

    public func getExtension(key: UInt16): ?JString

    public func getUnicodeLocaleType(key: ?JString): ?JString

    public func toJString(): JString

    public func toLanguageTag(): ?JString

    public static func forLanguageTag(languageTag: ?JString): ?Locale

    public func getISO3Language(): ?JString

    public func getISO3Country(): ?JString

    public func getDisplayLanguage(): ?JString

    public func getDisplayLanguage(locale: ?Locale): ?JString

    public func getDisplayScript(): ?JString

    public func getDisplayScript(inLocale: ?Locale): ?JString

    public func getDisplayCountry(): ?JString

    public func getDisplayCountry(locale: ?Locale): ?JString

    public func getDisplayVariant(): ?JString

    public func getDisplayVariant(inLocale: ?Locale): ?JString

    public func getDisplayName(): ?JString

    public func getDisplayName(locale: ?Locale): ?JString

    public func clone(): ?JObject

    public func hashCode32(): Int32

    public func equals(obj: ?JObject): Bool
}
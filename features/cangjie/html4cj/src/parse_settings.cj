/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2023-2024. All rights reserved.
 */
package html4cj

/*
 * Controls parser case settings, to optionally preserve tag and/or attribute name case.
 */
public class ParseSettings {
    /*
     * HTML default settings: both tag and attribute names are lower-cased during parsing.
     */
    public static let htmlDefault: ParseSettings = ParseSettings(false, false)

    /*
     * Preserve both tag and attribute case.
     */
    public static let preserveCase: ParseSettings = ParseSettings(true, true)

    private let preserveTagCaseValue: Bool

    private let preserveAttributeCaseValue: Bool

    /*
     * Returns true if preserving tag name case.
     */
    public func preserveTagCase(): Bool {
        return preserveTagCaseValue
    }

    /*
     * Returns true if preserving attribute case.
     */
    public func preserveAttributeCase(): Bool {
        return preserveAttributeCaseValue
    }

    /*
     * Define parse settings.
     *
     * @param tag preserve tag case?
     * @param attribute preserve attribute name case?
     */
    public init(tag: Bool, attribute: Bool) {
        preserveTagCaseValue = tag
        preserveAttributeCaseValue = attribute
    }

    init(copy: ParseSettings) {
        this(copy.preserveTagCaseValue, copy.preserveAttributeCaseValue)
    }

    /*
     * Normalizes a tag name according to the case preservation setting.
     */
    public func normalizeTag(name: String): String {
        var nameNor = name.strip()
        if (!preserveTagCaseValue) {
            nameNor = nameNor.toLower()
        }
        return nameNor
    }

    /*
     * Normalizes an attribute according to the case preservation setting.
     */
    public func normalizeAttribute(name: String): String {
        var nameNor = name.strip()
        if (!preserveAttributeCaseValue) {
            nameNor = nameNor.toLower()
        }
        return nameNor
    }

    func normalizeAttributes(attributes: ?Attributes): ?Attributes {
        if (attributes != None && !preserveAttributeCaseValue) {
            attributes().normalize()
        }
        return attributes
    }

    /*
     * Returns the normal name that a Tag will have (trimmed and lower-cased)
     */
    static func normalName(name: String): String {
        return name.strip().toLower()
    }
}

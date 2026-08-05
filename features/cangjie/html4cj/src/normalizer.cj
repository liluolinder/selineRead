/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2023-2024. All rights reserved.
 */
package html4cj

/*
 * Util methods for normalizing strings. Html4cj internal use only, please don't depend on this API.
 */
class Normalizer {
    /*
     * Drops the input string to lower case.
     */
    public static func lowerCase(input: String): String {
        return input.toLower()
    }

    /*
     * Lower-cases and trims the input string.
     */
    public static func normalize(input: String): String {
        return lowerCase(input).strip()
    }

    /*
     * If a string literal, just lower case the string; otherwise lower-case and trim.
     */
    public static func normalize(input: String, isStringLiteral: Bool): String {
        if (isStringLiteral) {
            return lowerCase(input)
        } else {
            return normalize(input)
        }
    }
}

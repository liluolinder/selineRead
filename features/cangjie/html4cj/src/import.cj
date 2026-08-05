/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2023-2024. All rights reserved.
 */
package html4cj

internal import stdx.encoding.url.URL
internal import stdx.encoding.url.UrlSyntaxException
internal import std.collection.ArrayList
internal import std.collection.collectArray
internal import std.collection.collectArrayList
internal import std.collection.collectString
internal import std.collection.contains
internal import std.collection.filter
internal import std.collection.first
internal import std.collection.HashMap
internal import std.collection.HashSet
internal import std.collection.isEmpty
internal import std.collection.map
internal import std.collection.Set
internal import std.convert.Parsable
internal import std.convert.Formattable
internal import std.io.InputStream
internal import std.io.IOException
internal import std.math.abs
internal import std.regex.MatchData
internal import std.regex.Matcher
internal import std.regex.Regex
internal import std.regex.RegexOption
internal import std.sync.AtomicBool
internal import std.sync.ReentrantMutex
internal import std.unicode.UnicodeRuneExtension
internal import std.unicode.UnicodeStringExtension

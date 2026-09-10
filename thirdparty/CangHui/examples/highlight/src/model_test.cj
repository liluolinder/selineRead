package chui_highlight

import chui.Color

private let TEST_MARK = Color.rgb(255, 224, 130)
private let TEST_TEXT = Color.rgb(60, 44, 12)

@Test
func matchCountCountsNonOverlappingCaseInsensitive(): Unit {
    @Expect(matchCount("log a log", "log"), 2)
    // ASCII case-insensitive: mixed case still matches.
    @Expect(matchCount("Log a LOG log", "log"), 3)
    // Non-overlapping: "aa" in "aaa" matches once (0..2), leaving a lone trailing 'a'.
    @Expect(matchCount("aaa", "aa"), 1)
    // No match and empty query both count zero.
    @Expect(matchCount("hello", "zzz"), 0)
    @Expect(matchCount("hello", ""), 0)
}

@Test
func matchCountHandlesCjkByRune(): Unit {
    // CJK matches by whole characters (no case folding needed); two non-overlapping hits.
    @Expect(matchCount("高亮与高亮", "高亮"), 2)
    @Expect(matchCount("圆角柔化边界", "圆角"), 1)
}

@Test
func highlightSpansSplitsAroundMatches(): Unit {
    // "log a log" → ["log"(mark), " a ", "log"(mark)] = 3 spans.
    @Expect(highlightSpans("log a log", "log", TEST_MARK, TEST_TEXT).size, 3)
    // Matches at both edges with a gap: "aXa" with "a" → ["a", "X", "a"] = 3.
    @Expect(highlightSpans("aXa", "a", TEST_MARK, TEST_TEXT).size, 3)
    // Adjacent matches become two separate mark spans: "aa" with "a" → 2.
    @Expect(highlightSpans("aa", "a", TEST_MARK, TEST_TEXT).size, 2)
}

@Test
func highlightSpansUnmatchedYieldsSinglePlainSpan(): Unit {
    // No match → the whole text as one plain span, so the body renders unchanged.
    @Expect(highlightSpans("hello world", "zzz", TEST_MARK, TEST_TEXT).size, 1)
    // Empty query → one plain span too (nothing to mark).
    @Expect(highlightSpans("hello world", "", TEST_MARK, TEST_TEXT).size, 1)
    // Empty text → a single (empty) span, never zero.
    @Expect(highlightSpans("", "x", TEST_MARK, TEST_TEXT).size, 1)
}

@Test
func totalMatchesSumsTitleAndBodyAcrossEntries(): Unit {
    let corpus = [
        Entry("高亮标题", "正文也提到高亮"), // 高亮 x2 (标题 1 + 正文 1)
        Entry("普通", "无关内容") // 高亮 x0
    ]
    @Expect(totalMatches(corpus, "高亮"), 2)
    @Expect(totalMatches(corpus, "缺失"), 0)
    // The shipped corpus highlights the default query in several places.
    @Expect(totalMatches(ENTRIES, "高亮") >= 3)
}

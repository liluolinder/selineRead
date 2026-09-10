/*
 * 高亮示例的类型化数据与纯匹配逻辑。
 *
 * 语料是一组关于界面设计的知识卡片；纯函数 highlightSpans 把一段文本按查询词（大小写不敏感、不重叠）
 * 切成若干 RichSpan——命中片段套 `.highlight(...)` 的 <mark> 背景，其余保持常规。matchCount / totalMatches
 * 统计命中数。切分与统计都在 rune 上进行，故中文按字整齐切分，拉丁按 ASCII 大小写不敏感匹配（中文无大小写）。
 */
package chui_highlight

import chui.{Color, RichSpan}
import std.collection.ArrayList

// 一张知识卡片：标题 + 正文。
struct Entry {
    let title: String
    let body: String

    init(title: String, body: String) {
        this.title = title
        this.body = body
    }
}

let ENTRIES: Array<Entry> = [
    Entry("焦点与键盘", "键盘导航时，聚焦的控件绘制焦点环；Tab 遍历、Enter 与空格激活，这是无障碍界面的基线。"),
    Entry("圆角 · 阴影 · 边框", "圆角柔化边界，阴影表达高度层级，边框界定区域，共同构成现代界面的样式语言。"),
    Entry("高亮关键词", "在长文本里高亮匹配的关键词，是搜索体验的核心；本页正用 RichSpan 的高亮能力实现。"),
    Entry("动画与过渡", "物理弹簧与缓动补间驱动流畅动画，让界面的每一次变化都有节奏、可预期。"),
    Entry("富文本排版", "RichText 支持逐段颜色、字号、字体、链接与高亮，像标记笔一样点亮文中的重点。")
]

// 快速填入搜索框的预设词（均在语料中至少命中一次）。
let PRESET_QUERIES: Array<String> = ["高亮", "界面", "动画", "圆角", "RichText"]

// 把 text 按 query 的（大小写不敏感、不重叠）命中切成 RichSpan：命中片段用 mark 背景 + matchColor 文字，
// 其余为常规文字。空查询或零命中返回单个常规片段，正文原样呈现。
func highlightSpans(text: String, query: String, mark: Color, matchColor: Color): Array<RichSpan> {
    let hay = text.toRuneArray()
    let needle = query.toRuneArray()
    if (needle.size == 0) {
        return [RichSpan.text(text)]
    }
    let spans = ArrayList<RichSpan>()
    var plainStart = 0 // 当前未命中片段的起点（rune 下标）
    var i = 0
    while (i < hay.size) {
        if (matchesAt(hay, i, needle)) {
            if (i > plainStart) {
                spans.add(RichSpan.text(runeSlice(hay, plainStart, i)))
            }
            spans.add(RichSpan.text(runeSlice(hay, i, i + needle.size), color: matchColor).highlight(mark))
            i += needle.size
            plainStart = i
        } else {
            i += 1
        }
    }
    if (hay.size > plainStart) {
        spans.add(RichSpan.text(runeSlice(hay, plainStart, hay.size)))
    }
    if (spans.isEmpty()) {
        return [RichSpan.text(text)]
    }
    spans.toArray()
}

// text 中 query 的不重叠命中次数（大小写不敏感）。空查询计 0。
func matchCount(text: String, query: String): Int64 {
    let hay = text.toRuneArray()
    let needle = query.toRuneArray()
    if (needle.size == 0) {
        return 0
    }
    var count: Int64 = 0
    var i = 0
    while (i < hay.size) {
        if (matchesAt(hay, i, needle)) {
            count += 1
            i += needle.size
        } else {
            i += 1
        }
    }
    count
}

// 所有卡片（标题 + 正文）里 query 的命中总数。
func totalMatches(entries: Array<Entry>, query: String): Int64 {
    var total: Int64 = 0
    for (entry in entries) {
        total += matchCount(entry.title, query) + matchCount(entry.body, query)
    }
    total
}

// hay 从 start 起是否逐 rune 匹配 needle（ASCII 大小写折叠比较）。
private func matchesAt(hay: Array<Rune>, start: Int64, needle: Array<Rune>): Bool {
    if (needle.size == 0 || start + needle.size > hay.size) {
        return false
    }
    for (k in 0..needle.size) {
        if (asciiLowerCode(hay[start + k]) != asciiLowerCode(needle[k])) {
            return false
        }
    }
    true
}

// rune 的码点，A-Z 折叠到 a-z（其它字符，含中文，原样）。
private func asciiLowerCode(r: Rune): UInt32 {
    let c = UInt32(r)
    if (c >= 65 && c <= 90) {
        c + 32
    } else {
        c
    }
}

private func runeSlice(runes: Array<Rune>, start: Int64, end: Int64): String {
    let builder = StringBuilder()
    var i = start
    while (i < end) {
        builder.append(runes[i])
        i += 1
    }
    builder.toString()
}

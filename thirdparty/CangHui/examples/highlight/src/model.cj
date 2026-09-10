/*
 * 高亮示例状态：当前搜索词。
 *
 * query 由 TextField 双向绑定、也可由预设标签填入；spansFor 依据当前 query 把一段文本切成带高亮的 RichSpan，
 * statusText 汇报命中总数。默认预填“高亮”，一进来就能看到跨卡片的高亮效果。
 */
package chui_highlight

import chui.{RichSpan, State}

class SearchModel {
    let entries: Array<Entry> = ENTRIES
    let query = State<String>("高亮")

    // 预设标签点击：把搜索词填入（TextField 绑定同一 State，随之同步）。
    func fill(term: String): Unit {
        query.value = term
    }

    // 当前搜索词下的命中总数。
    func matchTotal(): Int64 {
        totalMatches(entries, query.value)
    }

    // 一段文本按当前 query 高亮后的片段。
    func spansFor(text: String): Array<RichSpan> {
        highlightSpans(text, query.value, MARK_COLOR, MATCH_TEXT_COLOR)
    }

    // 底部状态条文案。
    func statusText(): String {
        let q = query.value
        if (q.size == 0) {
            return "输入关键词，或点下方标签，命中处将以 <mark> 高亮"
        }
        let n = matchTotal()
        if (n == 0) {
            return "未找到“${q}”"
        }
        "“${q}”：${n} 处高亮"
    }
}

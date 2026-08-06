package seline_booksource_parse

import std.collection.ArrayList

/**
 * 聚合搜索器：持有多个书源解析器，对同一关键字搜索并合并结果
 * - 含 {{page}} 占位符的书源自动搜索第 1、2 页
 * - 相同书名 + 作者的书合并去重（sources 记录来自哪些书源，可切换源）
 * - 结果按与关键字相关度排序（完全匹配 > 前缀匹配 > 包含匹配 > 其他）
 */
public class BookAggregator <: Searchable {
    private var sources: ArrayList<BookSourceParser>

    public init(sources: ArrayList<BookSourceParser>) {
        this.sources = sources
    }

    /** 运行时添加一个书源解析器（链式） */
    public func add(parser: BookSourceParser): BookAggregator {
        sources.add(parser)
        this
    }

      /** 运行时添加一个书源解析器（链式） */
    public func add(parser: Array<BookSourceParser>): BookAggregator {
        sources.add(all: parser)
        this
    }

    public func set(parser: Array<BookSourceParser>): BookAggregator {
        sources.clear()
        sources.add(all: parser)
        this
    }

    /** 当前书源数量 */
    public prop size: Int64 {
        get() {
            sources.size
        }
    }

    public func search(keyword: String, page!: Option<Int64> = None, offsetNum!: Option<Int64> = None): ArrayList<Book> {
        let merged = ArrayList<Book>()
        let kw = keyword.trim()
        for (parser in sources) {
            // 含 {{page}} 的书源搜索第 1、2 页；否则搜索一次（不指定页码）
            if (parser.supportsPage) {
                for (p in 1..=2) {
                    let books = parser.search(kw, page: Some(p), offsetNum: offsetNum)
                    mergeInto(merged, books, parser)
                }
            } else {
                let books = parser.search(kw, offsetNum: offsetNum)
                mergeInto(merged, books, parser)
            }
        }
        sortByRelevance(merged, kw)
        merged
    }

    /** 合并搜索结果去重：相同书名+作者的书合并，记录多源（解析器 + 该书在该源中的地址） */
    private func mergeInto(merged: ArrayList<Book>, books: ArrayList<Book>, parser: BookSourceParser): Unit {
        for (book in books) {
            let key = book.name.trim() + "|" + book.author.trim()
            var found = false
            for (b in merged) {
                if ((b.name.trim() + "|" + b.author.trim()) == key) {
                    // 已存在：记录该书也来自当前源（含该书在该源的地址）
                    b.addSource(parser, book.bookUrl)
                    found = true
                    break
                }
            }
            if (!found) {
                // 新书：记录首个来源
                book.addSource(parser, book.bookUrl)
                merged.add(book)
            }
        }
    }

    /** 相关度排序（插入排序，稳定）：书名与关键字匹配度高的在前 */
    private func sortByRelevance(books: ArrayList<Book>, kw: String): Unit {
        for (i in 1..books.size) {
            let key = books[i]
            var j = i
            while (j > 0 && relevance(books[j - 1], kw) > relevance(key, kw)) {
                books[j] = books[j - 1]
                j--
            }
            books[j] = key
        }
    }

    /** 书名与关键字的相关度：完全匹配 0 > 前缀匹配 1 > 包含匹配 2 > 其他 3 */
    private func relevance(book: Book, kw: String): Int64 {
        let name = book.name.trim()
        if (name == kw) {
            return 0
        }
        if (name.startsWith(kw)) {
            return 1
        }
        if (name.contains(kw)) {
            return 2
        }
        3
    }
}

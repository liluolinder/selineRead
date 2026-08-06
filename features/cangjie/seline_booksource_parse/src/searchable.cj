package seline_booksource_parse

import std.collection.ArrayList

/**
 * 书源搜索接口：单书源解析器与聚合搜索器统一实现
 * - BookSourceParser：单个书源搜索
 * - BookAggregator：多书源聚合搜索（去重 + 多分页 + 相关度排序）
 */
public interface Searchable {
    /**
     * 搜索书籍；page 为 None 表示不指定页码（默认第 1 页）；
     * offsetNum 为偏移量，None 时采用 ruleSearch.offset 配置（支持 {{offset}} 占位符的书源，实际请求 offset = (page-1) × offsetNum）
     */
    func search(keyword: String, page!: Option<Int64>, offsetNum!: Option<Int64>): ArrayList<Book>
}

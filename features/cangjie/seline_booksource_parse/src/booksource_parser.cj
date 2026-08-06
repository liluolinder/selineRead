package seline_booksource_parse

import std.collection.{ArrayList, HashMap}
import std.convert.Parsable
import std.regex.{Regex, RegexFlag}
import html4cj.Html4cj
import gjson.get
import gjson.parse
import gjson.Result

/**
 * 在线书源解析器主入口
 *
 * 完整流程（联网）：search → getBookInfo → getToc → getContent
 * 离线流程（测试/复用）：parseSearch / parseBookInfo / parseToc / parseContent
 * 直接接收原始响应内容，便于单元测试与数据复用。
 */
public class BookSourceParser <: Searchable {
    public let bookSource: BookSource

    public init(bookSource: BookSource) {
        this.bookSource = bookSource
    }

    /** 便捷入口：从书源 JSON 字符串构建解析器（CJson 反序列化） */
    public static func fromJson(json: String): BookSourceParser {
        BookSourceParser(BookSource.fromJson(json))
    }

    private func headers(): HashMap<String, String> {
        HttpUtil.parseHeaders(bookSource.header)
    }

    private func fetch(url: String): String {
        let body = HttpUtil.get(url, headers())
        if (body.isEmpty()) {
            throw Exception("HTTP 请求返回空响应: " + url)
        }
        body
    }

    /** 截取内容预览（诊断异常用） */
    private static func preview(s: String, n: Int64): String {
        if (s.size > n) {
            s[0..n]
        } else {
            s
        }
    }

    // ==================== 搜索 ====================

    /** 是否支持分页搜索（searchUrl 模板含 {{page}}） */
    public prop supportsPage: Bool {
        get() {
            if (bookSource.ruleSearch.isNone()) {
                return false
            }
            bookSource.ruleSearch.getOrThrow().searchUrl.contains("{{page}}")
        }
    }

    /** 是否支持 offset 分页（searchUrl 模板含 {{offset}}） */
    public prop supportsOffset: Bool {
        get() {
            if (bookSource.ruleSearch.isNone()) {
                return false
            }
            bookSource.ruleSearch.getOrThrow().searchUrl.contains("{{offset}}")
        }
    }

    /** 联网搜索：按 ruleSearch.searchUrl 模板发起请求并解析结果 */
    public func search(keyword: String, page!: Option<Int64> = None, offsetNum!: Option<Int64> = None): ArrayList<Book> {
        if (bookSource.ruleSearch.isNone()) {
            return ArrayList<Book>()
        }
        let rules = bookSource.ruleSearch.getOrThrow()
        if (rules.searchUrl.isEmpty()) {
            return ArrayList<Book>()
        }
        // 分页支持检测：searchUrl 含 {{page}} 才支持分页；
        // 不含且请求了非默认页（page > 1）时，该书源无更多结果，返回空数组；
        // page=1（默认页）不受影响（否则 supportsOffset 的书源传 page=1 会被误拦截）
        let supportsPage = rules.searchUrl.contains("{{page}}")
        if (!supportsPage && page.isSome() && page.getOrThrow() > 1) {
            return ArrayList<Book>()
        }
        let pageNum = if (page.isSome()) { page.getOrThrow() } else { 1 }
        let pageVal = pageNum.toString()
        // offsetNum 未传时采用 ruleSearch.offset（固定数字）；再未配置则为 0
        let baseOffset = if (offsetNum.isSome()) {
            offsetNum.getOrThrow()
        } else if (!rules.offset.isEmpty()) {
            try {
                Int64.parse(rules.offset)
            } catch (e: Exception) {
                0
            }
        } else {
            0
        }
        // offset = (page-1) × baseOffset（支持 {{offset}} 占位符的书源用）
        let offsetVal = ((pageNum - 1) * baseOffset).toString()
        let url = HttpUtil.resolveUrl(bookSource.bookSourceUrl, HttpUtil.fillTemplate(rules.searchUrl, HttpUtil.urlEncode(keyword), pageVal, offset: offsetVal))
        let content = if (rules.method == "POST") {
            // POST 表单搜索：关键字放 postBody（如 searchkey={{key}}）
            let body = HttpUtil.fillTemplate(rules.postBody, HttpUtil.urlEncode(keyword), pageVal, offset: offsetVal)
            HttpUtil.post(url, body, headers())
        } else {
            fetch(url)
        }
        if (content.isEmpty()) {
            return ArrayList<Book>()
        }
        parseSearch(content, keyword)
    }

    /** 解析搜索结果内容（自动识别 HTML / JSON） */
    public func parseSearch(content: String, keyword: String): ArrayList<Book> {
        let result = ArrayList<Book>()
        if (bookSource.ruleSearch.isNone()) {
            return result
        }
        let rules = bookSource.ruleSearch.getOrThrow()
        // 字段规则已统一为绝对路径/选择器（无 bookList）：按响应内容类型分发解析
        if (RuleEngine.isJsonContent(content)) {
            parseSearchJson(content, rules, result)
        } else {
            parseSearchHtml(content, rules, result)
        }
        result
    }

    /**
     * 解析 HTML 搜索结果（不依赖 bookList 字段）：
     * 每个字段规则用绝对选择器从整个文档提取数组（如 "div.bookbox .bookname a@text"），
     * 书名数组决定书籍数量，其余字段按下标对齐取值。
     */
    private func parseSearchHtml(content: String, rules: RuleSearch, result: ArrayList<Book>): Unit {
        let names = RuleEngine.extractAllHtml(content, rules.name)
        if (names.size == 0) {
            throw Exception("搜索响应异常：规则 '" + rules.name + "' 未提取到内容（可能被反爬拦截或规则错误），响应前 100 字: " + preview(content, 100))
        }
        let authors = RuleEngine.extractAllHtml(content, rules.author)
        let intros = RuleEngine.extractAllHtml(content, rules.intro)
        let kinds = RuleEngine.extractAllHtml(content, rules.kind)
        let wordCounts = RuleEngine.extractAllHtml(content, rules.wordCount)
        let latestChapters = RuleEngine.extractAllHtml(content, rules.latestChapter)
        let bookUrls = RuleEngine.extractAllHtml(content, rules.bookUrl)
        let coverUrls = RuleEngine.extractAllHtml(content, rules.coverUrl)
        for (i in 0..names.size) {
            let book = Book()
            book.name = names[i]
            book.author = jsonAt(authors, i)
            book.coverUrl = HttpUtil.resolveUrl(bookSource.bookSourceUrl, jsonAt(coverUrls, i))
            book.intro = jsonAt(intros, i)
            book.kind = jsonAt(kinds, i)
            book.wordCount = jsonAt(wordCounts, i)
            book.latestChapter = jsonAt(latestChapters, i)
            let rawUrl = jsonAt(bookUrls, i)
            book.bookUrl = if (rules.bookUrlTemplate.isEmpty()) {
                HttpUtil.resolveUrl(bookSource.bookSourceUrl, rawUrl)
            } else {
                let filled = HttpUtil.replacePlaceholder(rules.bookUrlTemplate, "bookId", rawUrl)
                HttpUtil.resolveUrl(bookSource.bookSourceUrl, filled)
            }
            book.sourceUrl = bookSource.bookSourceUrl
            book.bind(this)
            if (!book.name.isEmpty()) {
                result.add(book)
            }
        }
    }

    /**
     * 解析 JSON 搜索结果（不再依赖 bookList 字段）：
     * 每个字段规则用 gjson 路径从整个响应提取数组（如 "data.#.title"），
     * 书名数组决定书籍数量，其余字段按下标对齐取值。
     */
    private func parseSearchJson(content: String, rules: RuleSearch, result: ArrayList<Book>): Unit {
        // 书名规则提取数组 → 决定书籍数量
        let names = RuleEngine.extractJsonAll(content, rules.name)
        if (names.size == 0) {
            throw Exception("搜索响应异常：规则 '" + rules.name + "' 未提取到数组（JSON 书源需用 # 通配路径，如 data.#.title），响应前 100 字: " + preview(content, 100))
        }
        let authors = RuleEngine.extractJsonAll(content, rules.author)
        let intros = RuleEngine.extractJsonAll(content, rules.intro)
        let kinds = RuleEngine.extractJsonAll(content, rules.kind)
        let wordCounts = RuleEngine.extractJsonAll(content, rules.wordCount)
        let latestChapters = RuleEngine.extractJsonAll(content, rules.latestChapter)
        let bookUrls = RuleEngine.extractJsonAll(content, rules.bookUrl)
        let coverUrls = RuleEngine.extractJsonAll(content, rules.coverUrl)
        for (i in 0..names.size) {
            let book = Book()
            book.name = names[i]
            book.author = jsonAt(authors, i)
            book.coverUrl = HttpUtil.resolveUrl(bookSource.bookSourceUrl, jsonAt(coverUrls, i))
            book.intro = jsonAt(intros, i)
            book.kind = jsonAt(kinds, i)
            book.wordCount = jsonAt(wordCounts, i)
            book.latestChapter = jsonAt(latestChapters, i)
            let rawUrl = jsonAt(bookUrls, i)
            book.bookUrl = if (rules.bookUrlTemplate.isEmpty()) {
                HttpUtil.resolveUrl(bookSource.bookSourceUrl, rawUrl)
            } else {
                let filled = HttpUtil.replacePlaceholder(rules.bookUrlTemplate, "bookId", rawUrl)
                HttpUtil.resolveUrl(bookSource.bookSourceUrl, filled)
            }
            book.sourceUrl = bookSource.bookSourceUrl
            book.bind(this)
            if (!book.name.isEmpty()) {
                result.add(book)
            }
        }
    }

    /** 取数组下标处的值；越界返回空串 */
    private static func jsonAt(arr: ArrayList<String>, index: Int64): String {
        if (index >= 0 && index < arr.size) {
            arr[index]
        } else {
            ""
        }
    }

    // ==================== 书籍详情 ====================

    /**
     * 规则 URL 模板：模板为空时回退到调用方传入的地址；
     * 模板含 {{bookId}} 时，从 fallback（如搜索结果 bookUrl）中提取数字书籍 id 填充
     */
    private func ruleUrl(template: String, fallback: String): String {
        if (template.isEmpty()) {
            fallback
        } else {
            let bookId = extractBookId(fallback)
            let filled = HttpUtil.replacePlaceholder(template, "bookId", bookId)
            HttpUtil.resolveUrl(bookSource.bookSourceUrl, filled)
        }
    }

    /** 从 URL 中提取尾部连续数字作为书籍 id（如 /book/49905/ → 49905） */
    private static func extractBookId(url: String): String {
        var end: Int64 = url.size
        while (end > 0 && !(url[end - 1] >= b'0' && url[end - 1] <= b'9')) {
            end--
        }
        var start: Int64 = end
        while (start > 0 && url[start - 1] >= b'0' && url[start - 1] <= b'9') {
            start--
        }
        url[start..end]
    }

    /**
     * 按 ruleContent 的 token 配置生成章节正文 URL
     * 流程：提取 bookId（从 bookUrl 尾部数字）→ 填充明文模板（{{bookId}}/{{chapterId}}）→
     *       单引号转双引号 → 按 algo 加密生成 token → 填入 URL 模板（{{chapterToken}}）
     * @param bookUrl 书籍地址（供 bookId 提取）
     * @param chapterId 章节 id（目录第 N 章即 N）
     */
    private func buildChapterUrl(bookUrl: String, chapterId: String): String {
        let rc = bookSource.ruleContent.getOrThrow()
        let cfg = rc.token.getOrThrow()
        let bookId = extractBookId(bookUrl)
        // 填充明文模板占位符，单引号转为双引号（CJson 不支持 \" 转义，约定单引号表达 JSON 引号）
        let input = HttpUtil.replacePlaceholder(HttpUtil.replacePlaceholder(cfg.input, "bookId", bookId), "chapterId", chapterId)
        let plain = input.replace('\'', '"')
        let token = CryptoUtil.genToken(plain, cfg.key, cfg.iv, cfg.algo)
        let tpl = HttpUtil.replacePlaceholder(HttpUtil.replacePlaceholder(rc.url, "bookId", bookId), "chapterToken", HttpUtil.urlEncode(token))
        HttpUtil.resolveUrl(bookSource.bookSourceUrl, tpl)
    }

    /** 联网获取书籍详情 */
    public func getBookInfo(url: String): Book {
        let rules = bookSource.ruleBookInfo
        let requestUrl = if (rules.isNone()) { url } else { ruleUrl(rules.getOrThrow().url, url) }
        let content = fetch(requestUrl)
        parseBookInfo(content)
    }

    /** 解析书籍详情内容（自动识别 HTML / JSON） */
    public func parseBookInfo(content: String): Book {
        let book = Book()
        book.sourceUrl = bookSource.bookSourceUrl
        if (bookSource.ruleBookInfo.isNone()) {
            return book
        }
        let rules = bookSource.ruleBookInfo.getOrThrow()
        if (RuleEngine.isJsonContent(content)) {
            book.name = RuleEngine.extractJson(content, rules.name)
            book.author = RuleEngine.extractJson(content, rules.author)
            book.coverUrl = HttpUtil.resolveUrl(bookSource.bookSourceUrl, RuleEngine.extractJson(content, rules.coverUrl))
            book.intro = RuleEngine.extractJson(content, rules.intro)
            book.kind = RuleEngine.extractJson(content, rules.kind)
            book.wordCount = RuleEngine.extractJson(content, rules.wordCount)
            book.latestChapter = RuleEngine.extractJson(content, rules.latestChapter)
        } else {
            book.name = RuleEngine.extractFirst(content, rules.name)
            book.author = RuleEngine.extractFirst(content, rules.author)
            book.coverUrl = HttpUtil.resolveUrl(bookSource.bookSourceUrl, RuleEngine.extractFirst(content, rules.coverUrl))
            book.intro = RuleEngine.extractFirst(content, rules.intro)
            book.kind = RuleEngine.extractFirst(content, rules.kind)
            book.wordCount = RuleEngine.extractFirst(content, rules.wordCount)
            book.latestChapter = RuleEngine.extractFirst(content, rules.latestChapter)
        }
        book
    }

    // ==================== 目录 ====================

    /** 联网获取章节目录（传入书籍地址；若配置 {{chapterToken}} 模板会为每章生成正文 URL） */
    public func getToc(url: String): ArrayList<Chapter> {
        let rules = bookSource.ruleToc
        let requestUrl = if (rules.isNone()) { url } else { ruleUrl(rules.getOrThrow().url, url) }
        let content = fetch(requestUrl)
        let toc = parseToc(content)
        // 若 ruleContent 配置了 {{chapterToken}} 模板，为每章生成完整正文 URL
        if (bookSource.ruleContent.isSome()) {
            let rc = bookSource.ruleContent.getOrThrow()
            if (rc.token.isSome() && rc.url.contains("{{chapterToken}}")) {
                for (c in toc) {
                    c.url = buildChapterUrl(url, c.index.toString())
                }
            }
        }
        toc
    }

    /** 解析目录内容（自动识别 HTML / JSON） */
    public func parseToc(content: String): ArrayList<Chapter> {
        let result = ArrayList<Chapter>()
        if (bookSource.ruleToc.isNone()) {
            return result
        }
        let rules = bookSource.ruleToc.getOrThrow()
        if (RuleEngine.isJsonContent(content)) {
            // chapterName 用绝对通配路径提取数组（如 "data.data.chapterListWithVolume.0.#.title" / "list.#.name"）；
            // chapterName 为空时整个响应即数组（顶层数组模式）
            let names = if (rules.chapterName.isEmpty()) {
                let r = parse(content)
                let arr = ArrayList<String>()
                if (r.isArray()) {
                    for (item in r.array()) {
                        arr.add(item.toString().trim())
                    }
                }
                arr
            } else {
                RuleEngine.extractJsonAll(content, rules.chapterName)
            }
            let urls = RuleEngine.extractJsonAll(content, rules.chapterUrl)
            for (i in 0..names.size) {
                let chapter = Chapter()
                chapter.index = i + 1
                chapter.name = names[i]
                chapter.url = HttpUtil.resolveUrl(bookSource.bookSourceUrl, jsonAt(urls, i))
                chapter.sourceUrl = bookSource.bookSourceUrl
                chapter.bind(this)
                if (!chapter.name.isEmpty()) {
                    result.add(chapter)
                }
            }
        } else {
            let doc = Html4cj.parse(content)
            // 绝对选择器模式：chapterName/chapterUrl 为完整选择器（如 "div.ml_list a@text"），
            // 从整个文档提取全部匹配数组，按下标对齐；不依赖 chapterList
            let nameIsAbs = !rules.chapterName.isEmpty() && !rules.chapterName.startsWith("@")
            let urlIsAbs = !rules.chapterUrl.isEmpty() && !rules.chapterUrl.startsWith("@")
            if (nameIsAbs || urlIsAbs) {
                let names = RuleEngine.extractAllHtml(content, rules.chapterName)
                let urls = RuleEngine.extractAllHtml(content, rules.chapterUrl)
                for (i in 0..names.size) {
                    let chapter = Chapter()
                    chapter.index = i + 1
                    chapter.name = names[i]
                    chapter.url = HttpUtil.resolveUrl(bookSource.bookSourceUrl, jsonAt(urls, i))
                    chapter.sourceUrl = bookSource.bookSourceUrl
                    chapter.bind(this)
                    // 跳过无效章节：名称为空、URL 为空、或为锚点/JavaScript 链接
                    if (!chapter.name.isEmpty() && !chapter.url.isEmpty()
                        && !chapter.url.endsWith("#") && !chapter.url.startsWith("javascript:")) {
                        result.add(chapter)
                    }
                }
            }
        }
        result
    }

    // ==================== 正文 ====================

    /** 联网获取正文内容 */
    public func getContent(url: String): String {
        let rules = bookSource.ruleContent
        if (rules.isNone()) {
            return parseContent(fetch(url))
        }
        let template = rules.getOrThrow().url
        // 正文 URL 决策（适配不同书源）：
        // - 固定地址（非空、无占位符）：书源配置者的明确意图（如固定 token 的 API），直接使用
        // - {{chapterId}} 模板：从传入章节 URL 尾部提取数字填充（如 https://fanqienovel.com/7625647272331575870 → 7625647272331575870）
        // - 其他模板（如 {{chapterToken}}）或空：使用传入的章节 URL（目录解析生成，每章独立）
        let requestUrl = if (template.isEmpty()) {
            url
        } else if (template.contains("{{chapterId}}")) {
            let chapterId = extractBookId(url)
            HttpUtil.replacePlaceholder(template, "chapterId", chapterId)
        } else if (template.contains("{{")) {
            url
        } else {
            ruleUrl(template, url)
        }
        if (requestUrl.isEmpty()) {
            return ""
        }
        fetchContentMerged(requestUrl, rules.getOrThrow())
    }

    /**
     * 抓取正文并合并多页：章节分页时（如 "下一页" 链接）循环跟随后续页，
     * 直到下一页链接提取为空或不是 /read/ 链接（如最后一页的 javascript:void(0)）为止
     */
    private func fetchContentMerged(url: String, rules: RuleContent): String {
        let parts = ArrayList<String>()
        var current = url
        // 当前章节基础 id（如 53182236；分页 _2.html 仍属同一章节）
        let baseId = chapterBaseId(current)
        var guardCount: Int64 = 0
        while (guardCount < 20) {
            guardCount++
            let content = fetch(current)
            let pageText = parseContent(content)
            if (!pageText.isEmpty()) {
                parts.add(pageText)
            }
            // 提取下一页链接；仅同章节的分页链接才继续
            let nextRaw = RuleEngine.extractFirst(content, rules.nextUrl)
            if (nextRaw.isEmpty()) {
                break
            }
            let nextAbs = HttpUtil.resolveUrl(bookSource.bookSourceUrl, nextRaw)
            // 下一章链接的章节 id 与当前不同 → 停止（否则会把后续所有章节并入当前章）
            if (chapterBaseId(nextAbs) != baseId) {
                break
            }
            current = nextAbs
        }
        // 合并各页（页间以空行分隔）
        let sb = StringBuilder()
        var first = true
        for (p in parts) {
            if (!first) {
                sb.append("\n")
            }
            sb.append(p)
            first = false
        }
        sb.toString()
    }

    /**
     * 从章节 URL 提取章节基础 id：
     * - "/read/112712/53182236.html"   → 53182236
     * - "/read/112712/53182236_2.html" → 53182236（去掉 _N 分页后缀）
     * - 不含数字段时返回空串
     */
    private static func chapterBaseId(url: String): String {
        // 取最后一个 '/' 之后的文件名
        var lastSlash: Int64 = -1
        for (i in 0..url.size) {
            if (url[i] == b'/') {
                lastSlash = i
            }
        }
        let name = if (lastSlash >= 0) { url[(lastSlash + 1)..] } else { url }
        // 去掉扩展名（.html 等）
        var dot: Int64 = -1
        for (i in 0..name.size) {
            if (name[i] == b'.') {
                dot = i
                break
            }
        }
        var base = if (dot >= 0) { name[0..dot] } else { name }
        // 去掉 _N 分页后缀（下划线后全为数字）
        for (i in 0..base.size) {
            if (base[i] == b'_') {
                var allDigit = true
                for (j in (i + 1)..base.size) {
                    if (!(base[j] >= b'0' && base[j] <= b'9')) {
                        allDigit = false
                        break
                    }
                }
                if (allDigit) {
                    base = base[0..i]
                }
                break
            }
        }
        base
    }

    /** 解析正文内容（自动识别 HTML / JSON），并做空白清理 */
    public func parseContent(content: String): String {
        if (bookSource.ruleContent.isNone()) {
            return ""
        }
        let rules = bookSource.ruleContent.getOrThrow()
        let raw = if (RuleEngine.isJsonContent(content)) {
            RuleEngine.extractJson(content, rules.content)
        } else {
            // HTML：用 extractAllHtml 提取全部匹配段落（如 "#articlecontent > p" 多个段落），
            // 兼容容器规则（如 "#articlecontent@text" 单值），多值用换行拼接
            let all = RuleEngine.extractAllHtml(content, rules.content)
            if (all.size <= 1) {
                if (all.size == 1) { all[0] } else { "" }
            } else {
                let sb = StringBuilder()
                var first = true
                for (v in all) {
                    if (!first) {
                        sb.append("\n")
                    }
                    sb.append(v)
                    first = false
                }
                sb.toString()
            }
        }
        cleanContent(applyFilters(raw, rules.filters))
    }

    /**
     * 应用正文过滤：逐条匹配并替换为空（清理广告等干扰文本）
     * - 普通字符串：直接全文匹配替换
     * - "/正则/"：以 / 开头和结尾视为正则表达式，正则替换
     */
    public static func applyFilters(text: String, filters: ArrayList<String>): String {
        if (filters.size == 0) {
            return text
        }
        var result = text
        for (f in filters) {
            let item = f.trim()
            if (item.isEmpty()) {
                continue
            }
            if (item.size >= 2 && item[0] == b'/' && item[item.size - 1] == b'/') {
                // 正则形式：去掉首尾 / 后编译，replaceAll 替换为空
                // 使用 MultiLine 模式，使 ^ / $ 匹配每行首尾（正文按行过滤）
                let pattern = item[1..(item.size - 1)]
                try {
                    let re = Regex(pattern, [RegexFlag.MultiLine])
                    result = re.replaceAll(result, "")
                } catch (_: Exception) {
                    // 正则编译失败退化为普通字符串替换
                    result = result.replace(item, "")
                }
            } else {
                result = result.replace(item, "")
            }
        }
        result
    }

    /** 清理正文：逐行去首尾空白、删除空行 */
    public static func cleanContent(text: String): String {
        if (text.isEmpty()) {
            return ""
        }
        let sb = StringBuilder()
        let lines = text.split("\n")
        var first = true
        for (line in lines) {
            let t = line.trim()
            if (t.isEmpty()) {
                continue
            }
            if (!first) {
                sb.append("\n")
            }
            sb.append(t)
            first = false
        }
        sb.toString()
    }
}

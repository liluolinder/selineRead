package seline_booksource_parse

// CJson 宏要求：被 @JsonSerializable 装饰的类所在包必须可见以下依赖
    internal import stdx.encoding.json.*
import CJson.*
import CJson.jsonmacro.*

/** 搜索结果 / 书籍信息条目 */
@JsonSerializable
public class Book {
    public var bookUrl: String = ""
    public var name: String = ""
    public var author: String = ""
    public var coverUrl: String = ""
    public var intro: String = ""
    public var kind: String = ""
    public var wordCount: String = ""
    public var latestChapter: String = ""
    public var sourceUrl: String = ""

    /** 解析器数组（聚合搜索时每个源一个解析器；不参与 JSON 序列化） */
    @JsonIgnore
    public var parsers: ArrayList<BookSourceParser> = ArrayList<BookSourceParser>()

    /** 每源对应的书籍地址（与 parsers 按下标一一对应；不同源地址不同；不参与 JSON 序列化） */
    @JsonIgnore
    public var sourceUrls: ArrayList<String> = ArrayList<String>()

    public init() {}

    public init(bookUrl: String, name: String, author: String, coverUrl: String, intro: String) {
        this.bookUrl = bookUrl
        this.name = name
        this.author = author
        this.coverUrl = coverUrl
        this.intro = intro
    }

    /** 绑定解析器（链式）：单源场景绑定默认解析器 */
    public func bind(parser: BookSourceParser): This {
        if (parsers.size == 0) {
            parsers.add(parser)
            sourceUrls.add(bookUrl)
        } else {
            parsers[0] = parser
            sourceUrls[0] = bookUrl
        }
        this
    }

    /** 添加一个来源（聚合搜索合并去重时调用）：解析器 + 该书在该源中的地址；同名源存在则更新地址 */
    public func addSource(parser: BookSourceParser, url: String): This {
        let sourceName = parser.bookSource.bookSourceName
        for (i in 0..parsers.size) {
            if (parsers[i].bookSource.bookSourceName == sourceName) {
                sourceUrls[i] = url
                return this
            }
        }
        parsers.add(parser)
        sourceUrls.add(url)
        this
    }

    /** 本书来自哪些书源（展示用，遍历解析器获取源名） */
    public func sourceNames(): ArrayList<String> {
        let names = ArrayList<String>()
        for (p in parsers) {
            names.add(p.bookSource.bookSourceName)
        }
        names
    }

    /** 获取本书详情（默认源，parsers[0] + 对应地址） */
    public func getBookInfo(): Book {
        if (parsers.size == 0) {
            throw Exception("Book 未绑定解析器，请通过书源解析器搜索获取")
        }
        parsers[0].getBookInfo(sourceUrls[0])
    }

    /** 获取本书目录（默认源，parsers[0] + 对应地址）；返回的章节已绑定解析器，可直接 getContent() */
    public func getToc(): ArrayList<Chapter> {
        if (parsers.size == 0) {
            throw Exception("Book 未绑定解析器，请通过书源解析器搜索获取")
        }
        parsers[0].getToc(sourceUrls[0])
    }

    /** 按指定书源获取详情（聚合搜索中切换源） */
    public func getBookInfoBySource(sourceName: String): Book {
        for (i in 0..parsers.size) {
            if (parsers[i].bookSource.bookSourceName == sourceName) {
                return parsers[i].getBookInfo(sourceUrls[i])
            }
        }
        throw Exception("未找到书源: " + sourceName)
    }

    /** 按指定书源获取目录（聚合搜索中切换源） */
    public func getTocBySource(sourceName: String): ArrayList<Chapter> {
        for (i in 0..parsers.size) {
            if (parsers[i].bookSource.bookSourceName == sourceName) {
                return parsers[i].getToc(sourceUrls[i])
            }
        }
        throw Exception("未找到书源: " + sourceName)
    }

    /** 按索引获取详情（聚合搜索中切换源，对应 parsers[index] + sourceUrls[index]） */
    public func getBookInfoByIndex(index: Int64): Book {
        if (index < 0 || index >= parsers.size) {
            throw Exception("书源索引越界: " + index.toString() + "（共 " + parsers.size.toString() + " 个源）")
        }
        parsers[index].getBookInfo(sourceUrls[index])
    }

    /** 按索引获取目录（聚合搜索中切换源，对应 parsers[index] + sourceUrls[index]） */
    public func getTocByIndex(index: Int64): ArrayList<Chapter> {
        if (index < 0 || index >= parsers.size) {
            throw Exception("书源索引越界: " + index.toString() + "（共 " + parsers.size.toString() + " 个源）")
        }
        parsers[index].getToc(sourceUrls[index])
    }
}

/** 章节条目 */
@JsonSerializable
public class Chapter {
    public var index: Int64 = 0
    public var name: String = ""
    public var url: String = ""
    public var sourceUrl: String = ""

    /** 绑定解析器（不参与 JSON 序列化），由解析流程自动调用 */
    @JsonIgnore
    public var parser: Option<BookSourceParser> = None

    public init() {}

    public init(index: Int64, name: String, url: String) {
        this.index = index
        this.name = name
        this.url = url
    }

    /** 绑定解析器（链式） */
    public func bind(parser: BookSourceParser): Chapter {
        this.parser = Some(parser)
        this
    }

    /** 获取本章正文（需已绑定解析器） */
    public func getContent(): String {
        if (parser.isNone()) {
            throw Exception("Chapter 未绑定解析器，请通过书源解析器获取目录")
        }
        parser.getOrThrow().getContent(url)
    }
}

/** 正文内容 */
@JsonSerializable
public class BookContent {
    public var title: String = ""
    public var content: String = ""
    public var nextUrl: String = ""

    public init() {}

    public init(title: String, content: String, nextUrl: String) {
        this.title = title
        this.content = content
        this.nextUrl = nextUrl
    }
}

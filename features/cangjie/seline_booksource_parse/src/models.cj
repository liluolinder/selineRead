package seline_booksource_parse

// CJson 宏要求：被 @JsonSerializable 装饰的类所在包必须可见以下依赖
internal import std.collection.{ArrayList, HashMap}
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

    /** 绑定解析器（不参与 JSON 序列化），由解析流程自动调用 */
    @JsonIgnore
    public var parser: Option<BookSourceParser> = None

    public init() {}

    public init(bookUrl: String, name: String, author: String, coverUrl: String, intro: String) {
        this.bookUrl = bookUrl
        this.name = name
        this.author = author
        this.coverUrl = coverUrl
        this.intro = intro
    }

    /** 绑定解析器（链式） */
    public func bind(parser: BookSourceParser): Book {
        this.parser = Some(parser)
        this
    }

    /** 获取本书详情（需已绑定解析器） */
    public func getBookInfo(): Book {
        if (parser.isNone()) {
            throw Exception("Book 未绑定解析器，请通过书源解析器搜索获取")
        }
        parser.getOrThrow().getBookInfo(bookUrl)
    }

    /** 获取本书目录（需已绑定解析器）；返回的章节已绑定解析器，可直接 getContent() */
    public func getToc(): ArrayList<Chapter> {
        if (parser.isNone()) {
            throw Exception("Book 未绑定解析器，请通过书源解析器搜索获取")
        }
        parser.getOrThrow().getToc(this)
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

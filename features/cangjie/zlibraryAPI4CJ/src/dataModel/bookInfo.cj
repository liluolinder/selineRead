package zlibraryAPI4CJ.dataModel

public struct GetBookInfoRes <: Serializable<GetBookInfoRes> {
    public var success: UInt8 = 0
    public var book: ?BookInfo = BookInfo()
    public var errorInfo: ?String = ''

    public func serialize(): DataModel {
        return DataModelStruct().add(field<UInt8>("success", success)).add(field<Option<BookInfo>>("book", book))
    }
    public static func deserialize(dm: DataModel): GetBookInfoRes {
        var dms = match (dm) {
            case data: DataModelStruct => data
            case _ => throw Exception("this data is not DataModelStruct")
        }
        var result = GetBookInfoRes()
        result.success = UInt8.deserialize(dms.get("success"))
        result.book = Option<BookInfo>.deserialize(dms.get("book"))
        result.errorInfo = Option<String>.deserialize(dms.get("error"))

        return result
    }
}

public class BookInfo <: Serializable<BookInfo> {
    public var id: UInt64 = 0
    public var contentType: String = ''
    public var title: String = ''
    public var author: ?String = None
    public var volume: String = ''
    public var year: UInt64 = 0
    public var edition: ?String = None
    public var publisher: ?String = None
    public var identifier: ?String = None
    public var language: String = ''
    public var pages: UInt64 = 0
    public var series: String = ''
    public var cover: String = ''
    public var termsHash: String = ''
    public var active: UInt64 = 0
    public var deleted: UInt64 = 0
    public var filesize: UInt64 = 0
    public var filesizeString: String = ''
    public var extension: String = ''
    public var md5: String = ''
    public var sha256: String = ''
    public var href: String = ''
    public var hash: String = ''
    public var kindleAvailable: Bool = false
    public var sendToEmailAvailable: Bool = false
    public var interestScore: String = ''
    public var qualityScore: String = ''
    public var description: String = ''
    public var dl: String = ''
    public var readOnlineUrl: ?String = ''
    public var isUserSavedBook: ?Bool = None
    public var dataSaved: ?String = None
    public var readOnlineAvailable: Bool = false

    public func saveBook(cookie!: String): Bool {
        var httpClient = LinderHttp.client()
        let response = httpClient
            .request(Method.Get, "${zlibEAPI}/user/book/${id}/save")
            .headers(Headers().set("cookie", cookie))
            .timeout(Timeouts(read: Duration.minute, write: Duration.minute))
            .send()

        if (response.jsonObject().get('success').getOrThrow().asInt().getValue() == 1) {
            true
        } else {
            false
        }
    }

    public func unSaveBook(cookie!: String): Bool {
        var httpClient = LinderHttp.client()
        let response = httpClient
            .request(Method.Get, "${zlibEAPI}/user/book/${id}/unsave")
            .headers(Headers().set("cookie", cookie))
            .timeout(Timeouts(read: Duration.minute, write: Duration.minute))
            .send()

        if (response.jsonObject().get('success').getOrThrow().asInt().getValue() == 1) {
            true
        } else {
            false
        }
    }

    public func getSimilarBook(): GetBookRes {
        var httpClient = LinderHttp.client()
        let response = httpClient
            .request(Method.Get, "${zlibEAPI}/book/${id}/${hash}/similar")
            .timeout(Timeouts(read: Duration.minute, write: Duration.minute))
            .send()

        let res = GetBookRes.deserialize(response.dataModel())
        res
    }

    public func getDownloadInfo(cookie!: String): GetDownloadInfoRes {
        var httpClient = LinderHttp.client()
        let response = httpClient
            .request(Method.Get, "${zlibEAPI}/book/${id}/${hash}/file")
            .headers(Headers())
            .headers(Headers().set("cookie", cookie))
            .timeout(Timeouts(read: Duration.minute, write: Duration.minute))
            .send()

        let res = GetDownloadInfoRes.deserialize(response.dataModel())
        res
    }

    public func serialize(): DataModel {
        return DataModelStruct()
            .add(field<UInt64>("id", id))
            .add(field<String>("content_type", contentType))
            .add(field<String>("title", title))
            .add(field<?String>("author", author))
            .add(field<String>("volume", volume))
            .add(field<UInt64>("year", year))
            .add(field<?String>("edition", edition))
            .add(field<?String>("publisher", publisher))
            .add(field<?String>("identifier", identifier))
            .add(field<String>("language", language))
            .add(field<UInt64>("pages", pages))
            .add(field<String>("series", series))
            .add(field<String>("cover", cover))
            .add(field<String>("terms_hash", termsHash))
            .add(field<UInt64>("active", active))
            .add(field<UInt64>("deleted", deleted))
            .add(field<UInt64>("filesize", filesize))
            .add(field<String>("filesizeString", filesizeString))
            .add(field<String>("extension", extension))
            .add(field<String>("md5", md5))
            .add(field<String>("sha256", sha256))
            .add(field<String>("href", href))
            .add(field<String>("hash", hash))
            .add(field<Bool>("kindleAvailable", kindleAvailable))
            .add(field<Bool>("sendToEmailAvailable", sendToEmailAvailable))
            .add(field<String>("interestScore", interestScore))
            .add(field<String>("qualityScore", qualityScore))
            .add(field<String>("description", description))
            .add(field<String>("dl", dl))
            .add(field<?String>("readOnlineUrl", readOnlineUrl))
            .add(field<?Bool>("_isUserSavedBook", isUserSavedBook))
            .add(field<?String>('date_saved', dataSaved))
            .add(field<Bool>("readOnlineAvailable", readOnlineAvailable))
    }

    public static func deserialize(dm: DataModel): BookInfo {
        var dms = match (dm) {
            case data: DataModelStruct => data
            case _ => throw Exception("this data is not DataModelStruct")
        }
        
        var result = BookInfo()
        // 全部走容错反序列化：Z-Library 会偶尔省略字段（实测 `dl` 就有书缺），
        // 直接 String.deserialize 会抛 DataModelException 让整次搜索/详情失败
        result.title = strOr(dms.get("title"))
        result.id = u64Or(dms.get("id"))
        result.contentType = strOr(dms.get("content_type"))
        result.author = Option<String>.deserialize(dms.get("author"))
        result.volume = strOr(dms.get("volume"))
        result.year = u64Or(dms.get("year"))
        result.edition = Option<String>.deserialize(dms.get("edition"))
        result.publisher = Option<String>.deserialize(dms.get("publisher"))
        result.identifier = Option<String>.deserialize(dms.get("identifier"))
        result.language = strOr(dms.get("language"))
        result.pages = u64Or(dms.get("pages"))
        result.series = strOr(dms.get("series"))
        result.cover = strOr(dms.get("cover"))
        result.termsHash = strOr(dms.get("terms_hash"))
        result.active = u64Or(dms.get("active"))
        result.deleted = u64Or(dms.get("deleted"))
        result.filesize = u64Or(dms.get("filesize"))
        result.filesizeString = strOr(dms.get("filesizeString"))
        result.extension = strOr(dms.get("extension"))
        result.md5 = strOr(dms.get("md5"))
        result.sha256 = strOr(dms.get("sha256"))
        result.href = strOr(dms.get("href"))
        result.hash = strOr(dms.get("hash"))
        result.kindleAvailable = boolOr(dms.get("kindleAvailable"))
        result.sendToEmailAvailable = boolOr(dms.get("sendToEmailAvailable"))
        result.interestScore = strOr(dms.get("interestScore"))
        result.qualityScore = strOr(dms.get("qualityScore"))
        result.description = strOr(dms.get("description"))
        result.dl = strOr(dms.get("dl"))
        result.readOnlineUrl = Option<String>.deserialize(dms.get("readOnlineUrl"))
        result.isUserSavedBook = Option<Bool>.deserialize(dms.get("_isUserSavedBook"))
        result.dataSaved = Option<String>.deserialize(dms.get("date_saved"))
        result.readOnlineAvailable = boolOr(dms.get("readOnlineAvailable"))

        return result
    }
}

/*
 * 容错反序列化辅助：字段缺失或类型不符时退回默认值。
 * 实测 Z-Library 的搜索响应里部分书籍缺少 `dl` 字段，非可选字段直接反序列化
 * 会抛 DataModelException（"This data is not DataModelString"），导致整页结果作废。
 */
func strOr(dm: DataModel, fallback!: String = ""): String {
    try {
        String.deserialize(dm)
    } catch (_: Exception) {
        fallback
    }
}

func u64Or(dm: DataModel, fallback!: UInt64 = 0): UInt64 {
    try {
        UInt64.deserialize(dm)
    } catch (_: Exception) {
        fallback
    }
}

func boolOr(dm: DataModel, fallback!: Bool = false): Bool {
    try {
        Bool.deserialize(dm)
    } catch (_: Exception) {
        fallback
    }
}

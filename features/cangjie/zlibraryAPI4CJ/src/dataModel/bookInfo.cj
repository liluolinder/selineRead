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
    public var readOnlineUrl: String = ''
    public var isUserSavedBook: ?Bool = None
    public var dataSaved: ?String = None
    public var readOnlineAvailable: Bool = false

    public func saveBook(cookie!: String): Bool {
        var httpClient = LinderHttpClient(readTimeout: Duration.minute, writeTimeout: Duration.minute)
        let response = httpClient
            .destroy()
            .setDefaultHeader()
            .setUrl("${zlibEAPI}/user/book/${id}/save")
            .setMethod(RequestMethod.GET)
            .setHeader(HttpHeader().set(key: "cookie", value: cookie))
            .send()

        if (response.getBodyJsonObject().get('success').getOrThrow().asInt().getValue() == 1) {
            true
        } else {
            false
        }
    }

    public func unSaveBook(cookie!: String): Bool {
        var httpClient = LinderHttpClient(readTimeout: Duration.minute, writeTimeout: Duration.minute)
        let response = httpClient
            .destroy()
            .setUrl("${zlibEAPI}/user/book/${id}/unsave")
            .setMethod(RequestMethod.GET)
            .setHeader(HttpHeader().set(key: "cookie", value: cookie))
            .send()

        if (response.getBodyJsonObject().get('success').getOrThrow().asInt().getValue() == 1) {
            true
        } else {
            false
        }
    }

    public func getSimilarBook(): GetBookRes {
        var httpClient = LinderHttpClient(readTimeout: Duration.minute, writeTimeout: Duration.minute)
        let response = httpClient
            .destroy()
            .setDefaultHeader()
            .setUrl("${zlibEAPI}/book/${id}/${hash}/similar")
            .setMethod(RequestMethod.GET)
            .send()

        let res = GetBookRes.deserialize(response.getBodyDataModel())
        res
    }

    public func getDownloadInfo(cookie!: String): GetDownloadInfoRes {
        var httpClient = LinderHttpClient(readTimeout: Duration.minute, writeTimeout: Duration.minute)
        let response = httpClient
            .destroy()
            .setDefaultHeader()
            .setUrl("${zlibEAPI}/book/${id}/${hash}/file")
            .setMethod(RequestMethod.GET)
            .setHeader(HttpHeader())
            .setHeader(HttpHeader().set(key: "cookie", value: cookie))
            .send()

        let res = GetDownloadInfoRes.deserialize(response.getBodyDataModel())
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
            .add(field<String>("readOnlineUrl", readOnlineUrl))
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
        result.id = UInt64.deserialize(dms.get("id"))
        result.contentType = String.deserialize(dms.get("content_type"))
        result.title = String.deserialize(dms.get("title"))
        result.author = Option<String>.deserialize(dms.get("author"))
        result.volume = String.deserialize(dms.get("volume"))
        result.year = UInt64.deserialize(dms.get("year"))
        result.edition = Option<String>.deserialize(dms.get("edition"))
        result.publisher = Option<String>.deserialize(dms.get("publisher"))
        result.identifier = Option<String>.deserialize(dms.get("identifier"))
        result.language = String.deserialize(dms.get("language"))
        result.pages = UInt64.deserialize(dms.get("pages"))
        result.series = String.deserialize(dms.get("series"))
        result.cover = String.deserialize(dms.get("cover"))
        result.termsHash = String.deserialize(dms.get("terms_hash"))
        result.active = UInt64.deserialize(dms.get("active"))
        result.deleted = UInt64.deserialize(dms.get("deleted"))
        result.filesize = UInt64.deserialize(dms.get("filesize"))
        result.filesizeString = String.deserialize(dms.get("filesizeString"))
        result.extension = String.deserialize(dms.get("extension"))
        result.md5 = String.deserialize(dms.get("md5"))
        result.sha256 = String.deserialize(dms.get("sha256"))
        result.href = String.deserialize(dms.get("href"))
        result.hash = String.deserialize(dms.get("hash"))
        result.kindleAvailable = Bool.deserialize(dms.get("kindleAvailable"))
        result.sendToEmailAvailable = Bool.deserialize(dms.get("sendToEmailAvailable"))
        result.interestScore = String.deserialize(dms.get("interestScore"))
        result.qualityScore = String.deserialize(dms.get("qualityScore"))
        result.description = String.deserialize(dms.get("description"))
        result.dl = String.deserialize(dms.get("dl"))
        result.readOnlineUrl = String.deserialize(dms.get("readOnlineUrl"))
        result.isUserSavedBook = Option<Bool>.deserialize(dms.get("_isUserSavedBook"))
        result.dataSaved = Option<String>.deserialize(dms.get("date_saved"))
        result.readOnlineAvailable = Bool.deserialize(dms.get("readOnlineAvailable"))

        return result
    }
}

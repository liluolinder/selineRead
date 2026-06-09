package zlibraryAPI4CJ.dataModel

public struct GetBookRes <: Serializable<GetBookRes> {
    public var success: UInt8 = 0
    public var books: ?Array<BookInfoBrief> = []
    public var errorInfo: ?String = ''

    public func serialize(): DataModel {
        return DataModelStruct()
            .add(field<UInt8>("success", success))
            .add(field<Option<Array<BookInfoBrief>>>("books", books))
    }
    public static func deserialize(dm: DataModel): GetBookRes {
        var dms = match (dm) {
            case data: DataModelStruct => data
            case _ => throw Exception("this data is not DataModelStruct")
        }
        var result = GetBookRes()
        result.success = UInt8.deserialize(dms.get("success"))
        result.books = Option<Array<BookInfoBrief>>.deserialize(dms.get("books"))
        result.errorInfo = Option<String>.deserialize(dms.get("error"))
        return result
    }
}

public class BookInfoBrief <: Serializable<BookInfoBrief> {
    public var id: UInt64 = 0
    public var title: String = ''
    public var author: String = ''
    public var cover: String = ''
    public var hash: String = ''

    public func getBookInfo(cookie!: String = ''): GetBookInfoRes {
        var httpClient = LinderHttpClient(readTimeout: Duration.minute, writeTimeout: Duration.minute)
        let response = httpClient
            .setHeader(HttpHeader().set(key: "cookie", value: cookie))
            .setUrl("${zlibEAPI}/book/${id}/${hash}")
            .send()

        let res = GetBookInfoRes.deserialize(response.getBodyDataModel())
        res
    }

    public func getSimilarBook(): GetBookRes {
        var httpClient = LinderHttpClient(readTimeout: Duration.minute, writeTimeout: Duration.minute)
        let response = httpClient
            .destroy()
            .setDefaultHeader()
            .setUrl("${zlibEAPI}/book/${id}/${hash}/similar")
            .setMethod(RequestMethod.GET)
            .send()

        try {
            let res = GetBookRes.deserialize(response.getBodyDataModel())
            res
        } catch (err: Exception) {
            throw Exception('获取错误，错误信息${err.toString()}')
        }
    }

    public func getDownloadInfo(cookie!: String) {
        var httpClient = LinderHttpClient(readTimeout: Duration.minute, writeTimeout: Duration.minute)
        let response = httpClient
            .destroy()
            .setDefaultHeader()
            .setUrl("${zlibEAPI}/book/${id}/${hash}/file")
            .setMethod(RequestMethod.GET)
            .setHeader(HttpHeader().set(key: "cookie", value: cookie))
            .send()

        let res = GetDownloadInfoRes.deserialize(response.getBodyDataModel())
        res
    }

    public func serialize(): DataModel {
        return DataModelStruct()
            .add(field<UInt64>("id", id))
            .add(field<String>("title", title))
            .add(field<String>("author", author))
            .add(field<String>("cover", cover))
            .add(field<String>("hash", hash))
    }
    public static func deserialize(dm: DataModel): BookInfoBrief {
        var dms = match (dm) {
            case data: DataModelStruct => data
            case _ => throw Exception("this data is not DataModelStruct")
        }
        var result = BookInfoBrief()
        result.id = UInt64.deserialize(dms.get("id"))
        result.title = String.deserialize(dms.get("title"))
        result.author = String.deserialize(dms.get("author"))
        result.cover = String.deserialize(dms.get("cover"))
        result.hash = String.deserialize(dms.get("hash"))

        return result
    }
}

package zlibraryAPI4CJ.dataModel



public struct GetUserInfoOrLoginRes <: Serializable<GetUserInfoOrLoginRes> {
    public var success: UInt8 = 0

    public var errorInfo: ?String = ''

    public var userInfo: ?ZlibUserInfo = None

    public func serialize(): DataModel {
        return DataModelStruct()
            .add(field<UInt8>("success", success))
            .add(field<?String>("error", errorInfo))
            .add(field<?ZlibUserInfo>("user", userInfo))
    }
    public static func deserialize(dm: DataModel): GetUserInfoOrLoginRes {
        var dms = match (dm) {
            case data: DataModelStruct => data
            case _ => throw Exception("this data is not DataModelStruct")
        }
        var result = GetUserInfoOrLoginRes()
        result.success = UInt8.deserialize(dms.get("success"))
        result.errorInfo = Option<String>.deserialize(dms.get("error"))
        result.userInfo = Option<ZlibUserInfo>.deserialize(dms.get("user"))
        return result
    }
}

public class ZlibUserInfo <: Serializable<ZlibUserInfo> {
    public var id: UInt64 = 0
    public var email: String = ""
    public var name: String = ""
    public var kindleEmail: ?String = ""
    public var remixUserKey: String = ""
    public var todayDownloadNum: UInt64 = 0
    public var downloadLimit: UInt64 = 0
    // "donations_active": null,
    // "donations_expire": null,
    // "confirmed": 1,
    // "isPremium": 0

    public prop cookie: String {
        get() {
            'siteLanguage=zh; remix_userkey=${remixUserKey}; remix_userid=${id}'
        }
    }

    private prop header: Headers {
        get() {
            let header: Headers = Headers().set("cookie", cookie)
            header
        }
    }

    public func getPersonalInfo(): GetUserInfoOrLoginRes {
        var httpClient = LinderHttp.client()
        let response = httpClient
            .request(Method.Get, "${zlibEAPI}/user/profile")
            .headers(header)
            .timeout(Timeouts(read: Duration.minute, write: Duration.minute))
            .send()

        let res = GetUserInfoOrLoginRes.deserialize(response.dataModel())
        res
    }

    public func getSaved(page!: UInt64 = 1): GetBookWithInfoAndPaginationRes {
        let param = Form()
        param.add("page", "${page}")
        var url = URL.parse("${zlibEAPI}/user/book/saved")
        url = url.replace(query:param.toEncodeString())
        var httpClient = LinderHttp.client()
        let response = httpClient
            .request(Method.Get, url)
            .headers(header)
            .timeout(Timeouts(read: Duration.minute, write: Duration.minute))
            .send()

        let res = GetBookWithInfoAndPaginationRes.deserialize(response.dataModel())
        res
    }

    public func getRecommendBook(): GetBookRes {
        var httpClient = LinderHttp.client()
        let response = httpClient
            .request(Method.Get, "${zlibEAPI}/user/book/recommended")
            .headers(header)
            .timeout(Timeouts(read: Duration.minute, write: Duration.minute))
            .send()

        let res = GetBookRes.deserialize(response.dataModel())
        res
    }

    public func serialize(): DataModel {
        return DataModelStruct()
            .add(field<UInt64>("id", id))
            .add(field<String>("email", email))
            .add(field<String>("name", name))
            .add(field<?String>("kindle_email", kindleEmail))
            .add(field<String>("remix_userkey", remixUserKey))
            .add(field<UInt64>("downloads_today", todayDownloadNum))
            .add(field<UInt64>("downloads_limit", downloadLimit))
    }
    public static func deserialize(dm: DataModel): ZlibUserInfo {
        var dms = match (dm) {
            case data: DataModelStruct => data
            case _ => throw Exception("this data is not DataModelStruct")
        }
        var result = ZlibUserInfo()
        result.id = UInt64.deserialize(dms.get("id"))
        result.email = String.deserialize(dms.get("email"))
        result.name = String.deserialize(dms.get("name"))
        result.kindleEmail = Option<String>.deserialize(dms.get("kindle_email"))
        result.remixUserKey = String.deserialize(dms.get("remix_userkey"))
        result.todayDownloadNum = UInt64.deserialize(dms.get("downloads_today"))
        result.downloadLimit = UInt64.deserialize(dms.get("downloads_limit"))
        return result
    }
}

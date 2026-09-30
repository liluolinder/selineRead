package zlibraryAPI4CJ

import linderHttp.*
import zlibraryAPI4CJ.common.*
import zlibraryAPI4CJ.dataModel.*
import stdx.encoding.url.Form

public class ZlibClient {
    public func login(email!: String, password!: String): GetUserInfoOrLoginRes {
        let body = Form()
        body.add("email", email)
        body.add("password", password)
        var response = LinderHttp.client()
            .request(Method.Post, "${zlibEAPI}/user/login")
            .timeout(Timeouts(read: Duration.minute, write: Duration.minute))
            .body(Body.text(body.toEncodeString(), contentType: "application/x-www-form-urlencoded"))
            .send()

        let res = GetUserInfoOrLoginRes.deserialize(response.dataModel())

        res
    }

    public func login(userID!: UInt64, userKey!: String): GetUserInfoOrLoginRes {
        let tempUserInfo: ZlibUserInfo = ZlibUserInfo()
        tempUserInfo.id = userID
        tempUserInfo.remixUserKey = userKey
        tempUserInfo.getPersonalInfo()
    }

    public func getRecommendBook(): GetBookRes {
        let url = "${zlibEAPI}/book/most-popular"
        let response = LinderHttp.get(url)
        let res = GetBookRes.deserialize(response.dataModel())
        res
    }

    public func search(message!: String, yearFrom!: ?UInt16 = None, yearTo!: ?UInt16 = None, page!: UInt16 = 1,
        limit!: UInt16 = 20): GetBookWithInfoAndPaginationRes {
        let body = Form()
        body.add('message', message)
        body.add('page', "${page}")
        body.add('limit', "${limit}")
        if (yearFrom.isSome()) {
            body.add('yearFrom', "${yearFrom}")
        }

        if (yearTo.isSome()) {
            body.add('yearTo', "${yearTo}")
        }
        let response = LinderHttp.client()
            .request(Method.Post, "${zlibEAPI}/book/search")
            .timeout(Timeouts(read: Duration.minute, write: Duration.minute))
            .body(Body.text(body.toEncodeString(), contentType: "application/x-www-form-urlencoded"))
            .send()
        let res = GetBookWithInfoAndPaginationRes.deserialize(response.dataModel())
        res
    }
}

/**
 * Created on 2026/3/10
 */
package ohos_app_cangjie_entry.zlibAPI4cj

import ohos.ark_interop.*
import ohos.ark_interop_macro.*
import zlibraryAPI4CJ.dataModel.ZlibUserInfo

@Interop[ArkTS]
public class ZlibUserInfoArk {
    public var id: UInt64 = 0
    public var email: String = ""
    public var name: String = ""
    public var kindleEmail: String = ""
    public var remixUserKey: String = ""
    public var todayDownloadNum: UInt64 = 0
    public var downloadLimit: UInt64 = 0

    @Interop[ArkTS, Invisible]
    public static func fromCJ(cjValue: ZlibUserInfo): ZlibUserInfoArk {
        let r = ZlibUserInfoArk()
        r.id = cjValue.id
        r.email = cjValue.email
        r.name = cjValue.name
        r.kindleEmail = cjValue.kindleEmail
        r.remixUserKey = cjValue.remixUserKey
        r.todayDownloadNum = cjValue.todayDownloadNum
        r.downloadLimit = cjValue.downloadLimit
        r
    }

    public prop cookie: String {
        get() {
            'siteLanguage=zh; remix_userkey=${remixUserKey}; remix_userid=${id}'
        }
    }

    public ZlibUserInfoArk() {}
}

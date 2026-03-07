/**
 * Created on 2026/3/7
 */
package ohos_app_cangjie_entry.zlibAPI4cj

import ohos.ark_interop.*
import ohos.ark_interop_macro.*
import zlibraryAPI4CJ.dataModel.BookInfo

@Interop[ArkTS]
public class ZlibBookInfoArk {
    public var id: UInt64 = 0
    public var contentType: String = ''
    public var title: String = ''
    public var author: Option<String> = None
    public var volume: String = ''
    public var year: UInt64 = 0
    public var edition: Option<String> = None
    public var publisher: Option<String> = None
    public var identifier: Option<String> = None
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
    public var isUserSavedBook: Option<Bool> = None
    public var dataSaved: Option<String> = None
    public var readOnlineAvailable: Bool = false

    @Interop[ArkTS, Invisible]
    public static func fromCJ(cjValue: BookInfo): ZlibBookInfoArk {
        let r = ZlibBookInfoArk()
        r.id = cjValue.id
        r.contentType = cjValue.contentType
        r.title = cjValue.title
        r.author = cjValue.author
        r.volume = cjValue.volume
        r.year = cjValue.year
        r.edition = cjValue.edition
        r.publisher = cjValue.publisher
        r.identifier = cjValue.identifier
        r.language = cjValue.language
        r.pages = cjValue.pages
        r.series = cjValue.series
        r.cover = cjValue.cover
        r.termsHash = cjValue.termsHash
        r.active = cjValue.active
        r.deleted = cjValue.deleted
        r.filesize = cjValue.filesize
        r.filesizeString = cjValue.filesizeString
        r.extension = cjValue.extension
        r.md5 = cjValue.md5
        r.sha256 = cjValue.sha256
        r.href = cjValue.href
        r.hash = cjValue.hash
        r.kindleAvailable = cjValue.kindleAvailable
        r.sendToEmailAvailable = cjValue.sendToEmailAvailable
        r.interestScore = cjValue.interestScore
        r.qualityScore = cjValue.qualityScore
        r.description = cjValue.description
        r.dl = cjValue.dl
        r.readOnlineUrl = cjValue.readOnlineUrl
        r.isUserSavedBook = cjValue.isUserSavedBook
        r.dataSaved = cjValue.dataSaved
        r.readOnlineAvailable = cjValue.readOnlineAvailable
        r
    }

    public ZlibBookInfoArk() {}
}

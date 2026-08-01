/**
 * Created on 2026/3/7
 */
package ohos_app_cangjie_entry.zlib4cj

import ohos.ark_interop.*
import ohos.ark_interop_macro.*
import zlibraryAPI4CJ.dataModel.BookInfo
import ohos_app_cangjie_entry.run2JS
import ohos_app_cangjie_entry.globalcontext
import linderHttp.LinderHttpClient
import stdx.encoding.json.JsonObject
import stdx.encoding.json.JsonInt
import stdx.encoding.json.JsonString
import zlibraryAPI4CJ.common.zlibEAPI
import linderHttp.RequestMethod

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
    public var readOnlineUrl: Option<String> = ''
    public var isUserSavedBook: Option<Bool> = None
    public var dataSaved: Option<String> = None
    public var readOnlineAvailable: Bool = false

    var cjValue: BookInfo = BookInfo()

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
        r.cjValue = cjValue
        r
    }

    public func getDownloadInfo(cookie: String, returnFunc: (String) -> Unit, errorFunc: (String) -> Unit): Unit {
        spawn {
            try {
                let reqs = cjValue.getDownloadInfo(cookie: cookie)
                if (reqs.success == 1) {
                    if (let Some(file) <- reqs.file && file.allowDownload) {
                        run2JS {
                            returnFunc(file.downloadLink.getOrThrow())
                        }
                    } else {
                        run2JS {
                            errorFunc('获取错误:获取不到下载文件，检查是否超额下载或zlib服务器异常')
                        }
                    }
                } else {
                    run2JS {
                        errorFunc('获取错误:${reqs.errorInfo.getOrDefault {=> '未知错误'}}')
                    }
                }
            } catch (err: Exception) {
                run2JS {
                     err.toString() |> errorFunc
                }
            }
        }
    }

    public func saveBook(cookie: String, returnFunc: (Bool) -> Unit, errorFunc: (String) -> Unit): Unit {
        spawn {
            try {
                let reqs = cjValue.saveBook(cookie: cookie)
                run2JS {
                    returnFunc(reqs)
                }
            } catch (err: Exception) {
                run2JS {
                     err.toString() |> errorFunc
                }
            }
        }
    }

    public func unSaveBook(cookie: String, returnFunc: (Bool) -> Unit, errorFunc: (String) -> Unit): Unit {
        spawn {
            try {
                let reqs = cjValue.unSaveBook(cookie: cookie)
                run2JS {
                    returnFunc(reqs)
                }
            } catch (err: Exception) {
                run2JS {
                     err.toString() |> errorFunc
                }
            }
        }
    }

    public func send2QQGroup(cookie: String,qqNumber:String, qqGroup:String, returnFunc: (String) -> Unit, errorFunc: (String) -> Unit): Unit {
        spawn {
            try {
                let body = JsonObject()
                body.put("qqGroup", JsonString(qqGroup))
                body.put("qqNumber", JsonString(qqNumber))
                body.put("bookID", JsonInt(Int64(id)))
                body.put("bookHash", JsonString(hash))
                body.put("cookie", JsonString(cookie))
                body.put("downloadUrl", JsonString("${zlibEAPI}/book/${id}/${hash}/file"))
                let clinet = LinderHttpClient()
                    .setUrl("http://118.195.130.110:8800/notify")
                    .setMethod(RequestMethod.POST)
                    .setBody(body)
                let res = clinet.send()
                let resJson = res.getBodyJsonString()
                run2JS {
                    resJson |> returnFunc
                }
            } catch (err: Exception) {
                run2JS {
                   err.toString() |> errorFunc
                }
            }
        }
    }

    public func getSimilarBook(returnFunc:  (JSArrayEx<ZlibBookInfoBriefArk>) -> Unit, errorFunc: (String) -> Unit):Unit{
       spawn {
            try {
                let reqs = cjValue.getSimilarBook()
                if (let Some(books)<-reqs.books){
                    let temp = books.map({bookInfo => ZlibBookInfoBriefArk.fromCJ(bookInfo)})
                    let res = JSArrayEx<ZlibBookInfoBriefArk>(temp)
                    run2JS {
                        returnFunc(res)
                    }
                }else{
                     run2JS {
                        errorFunc("获取错误:${reqs.errorInfo.getOrDefault({=> '未知错误'})}")
                    }
                }
            } catch (err: Exception) {
                run2JS {
                     err.toString() |> errorFunc
                }
            }
       }
    }

    public ZlibBookInfoArk() {}
}

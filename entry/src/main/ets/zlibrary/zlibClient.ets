import { http } from "@kit.NetworkKit";
import { BusinessError, request } from "@kit.BasicServicesKit";
import { firstDownloadInfo, I_BookDetailedInfo, I_BookInfo } from "../selineRead/models/interfaces/I_BookInfo";
import { user_agent } from "../selineRead/commons/commonItem";
import { CJLoader } from "./CJloader/CJLoader";
import { I_LoginRes } from "./interface/I_loginInfo";
import { I_BasicUserInfo, I_UserDownloadLimitAndDonation, I_ZlibUserInfo } from "./interface/I_ZlibUserInfo";
import { JSON } from "@kit.ArkTS";
import { __Download__, __ZlibUser__ } from "../selineRead/commons/shareDatas";
import { LNotificationManager, XContext, XPreferencesManager } from "commonpackage";
import { I_trulyDownloadUrl } from "./interface/I_DownloadInfo";
import { fileIo } from "@kit.CoreFileKit";
import { promptAction } from "@kit.ArkUI";
import { DownloadConfig, DownloadListener, DownloadProgressInfo, DownloadTask } from "@hadss/super_fast_file_trans";
import { I_searchBook } from "./interface/I_SearchInfo";
import { backgroundProcessManager } from "@kit.BackgroundTasksKit";
import { BackgroundUtil } from "../selineRead/models/classes/BackgroundRunningManager";
import { shareBook } from "../selineRead/models/utils/ShareBook";
import { DownloadInfo, DownloadStatus } from "../selineRead/models/classes/DownloadInfo";

export class zlibClient {
  static async refreshUrl(): Promise<[number, string]> {
    console.log(`尝试刷新Url`)
    let req = http.createHttp()
    return await req.request(`${__ZlibUser__.base_url}`, {
      method: http.RequestMethod.GET,
      header: {
        'sec-ch-ua-platform': '"Windows"',
        'user-agent': user_agent,
      },
    }).then(async (data: http.HttpResponse) => {
      try {
        let location: string = data.header?.['location']
        if (location != undefined && location != '') {
          location = location.substring(0, location.length - 1)
          __ZlibUser__.base_url = location
          __ZlibUser__.baseApi_url = location + '/papi'
          XPreferencesManager.putPreferencesValue('selineRead', "zlibBaseUrl", location)

        }
        return [1, __ZlibUser__.base_url] as [number, string]
      } catch (err) {
        return [0, JSON.stringify(err)] as [number, string]
      }
    })
      .catch((err: BusinessError) => {
        return [0, JSON.stringify(err)] as [number, string]
      }).finally(() => {
        req.destroy()
      });
  }

  static async login(email: string, password: string): Promise<[number, string]> {
    console.log(`尝试登录`)
    let req = http.createHttp()
    return await req.request(`${__ZlibUser__.base_url}/rpc.php`, {
      method: http.RequestMethod.GET,
      header: {
        'sec-ch-ua-platform': '"Windows"',
        'user-agent': user_agent,
      },
      extraData: {
        'isModal': 'true',
        'email': email,
        'password': password,
        'site_mode': 'books',
        'action': 'login',
        'redirectUrl': '',
        'gg_json_mode': '1'
      }
    }).then(async (data: http.HttpResponse) => {
      try {
        let obj = JSON.parse(JSON.stringify(data))
        let result: I_LoginRes = JSON.parse((obj as object)?.['result']) as I_LoginRes
        if (result.response.message == undefined || result.response.message == null) {
          let cookie =
            `siteLanguage=zh; selectedSiteMode=books; remix_userkey=${result.response.user_key}; remix_userid=${result.response.user_id}; redirects_count=%7B%22auth%22%3A1%2C%22hide-auth-params%22%3A1%7D`
          let basicInfo: I_BasicUserInfo = JSON.parse((await zlibClient.getPersonInfo(cookie))[1]) as I_BasicUserInfo
          let userInfo: I_ZlibUserInfo = {
            account: email,
            password: password,
            cookie: cookie,
            userName: basicInfo.userName,
            userDownloadLimitNumber: basicInfo.userDownloadLimitNumber,
            userDonateNumber: basicInfo.userDonateNumber,
            userAvatar: basicInfo.userAvatar
          }
          return [1, JSON.stringify(userInfo)] as [number, string]
        } else {
          return [0, result.response.message] as [number, string]
        }
      } catch (err) {
        return [0, JSON.stringify(err)] as [number, string]
      }
    })
      .catch((err: BusinessError) => {
        return [0, JSON.stringify(err)] as [number, string]
      }).finally(() => {
        req.destroy()
      });
  }

  static async getPersonInfo(cookie: string): Promise<[number, string]> {
    console.log(`尝试获取用户数据`)
    let req = http.createHttp()
    return await req.request(`${__ZlibUser__.base_url}/?ts`, {
      method: http.RequestMethod.GET,
      header: {
        'sec-ch-ua-platform': '"Windows"',
        'user-agent': user_agent,
        'Cookie': cookie//this.cookie,;
      }
    }).then((data: http.HttpResponse) => {
      try {
        let res: I_UserDownloadLimitAndDonation =
          JSON.parse(CJLoader.getUserDownloadLimitAndDonation(JSON.stringify(data.result))) as I_UserDownloadLimitAndDonation
        let avatar = CJLoader.getUserAvatar(JSON.stringify(data.result))
        let userName = CJLoader.getUserName(JSON.stringify(data.result))
        let tempUserInfo: I_BasicUserInfo = {
          userName: userName,
          userDownloadLimitNumber: res.downloadLimit,
          userDonateNumber: res.donation,
          userAvatar: avatar
        }
        return [1, JSON.stringify(tempUserInfo)] as [number, string]
      } catch (err) {
        return [0, JSON.stringify(err)] as [number, string]
      }
    })
      .catch((err: BusinessError) => {
        return [0, JSON.stringify(err)] as [number, string]
      }).finally(() => {
        req.destroy()
      });
  }

  /*
    @Param req http请求体
    @Param page 请求页数>=1, 默认值位1
    @Return 类型为[number, string]元组 元素0表示获取状态（0为失败， 1为成功） string表示消息(成功为序列化后的数据字符串，其余为报错内容)
   */
  static async getRecommendBook(req: http.HttpRequest, page: number = 1): Promise<[number, string]> {
    console.log(`尝试获取推荐书籍`)
    return await req.request(`${__ZlibUser__.baseApi_url}/book/mostpopular/mosaic/20/${page}`, {
      method: http.RequestMethod.GET,
      header: {
        'sec-ch-ua-platform': '"Windows"',
        'user-agent': user_agent,
      }
    }).then((data: http.HttpResponse) => {
      try {
        let obj = JSON.parse(JSON.stringify(data))
        let result = JSON.parse((obj as object)?.['result'])
        let bookArray: I_BookInfo[] = (result as object)?.['books']
        return [1, JSON.stringify(bookArray)] as [number, string]
      } catch (err) {
        return [0, JSON.stringify(err)] as [number, string]
      }
    })
      .catch((err: BusinessError) => {
        return [0, JSON.stringify(err)] as [number, string]
      }).finally(() => {
        req.destroy()
      });
  }

  /*
  @Param req http请求体
  @Param bookHref 书籍详细url/Href
  @Return 类型为[number, string]元组 元素0表示获取状态（0为失败， 1为成功） string表示消息(成功为序列化后的数据字符串，其余为报错内容)
 */
  static async getBookInfo(req: http.HttpRequest, bookHref: string): Promise<[number, string]> {
    console.log(`尝试获取书籍信息`)
    return await req.request(`${__ZlibUser__.base_url}${bookHref}`, {
      method: http.RequestMethod.GET,
      header: {
        'sec-ch-ua-platform': '"Windows"',
        'user-agent': user_agent,
        'Cookie': __ZlibUser__.cookie,
      }
    }).then((data: http.HttpResponse) => {
      try {
        let resHtml = JSON.stringify(data.result)
        try {
          let resBookInfo: I_BookDetailedInfo = {
            name: '',
            description: "",
            author: [],
            publisher: { name: '' },
            image: "",
            isbn: "",
            numberOfPages: 0,
            datePublished: 0,
            inLanguage: { name: '' },
            terms: [],
            review: { reviewBody: '', datePublished: '', reviewRating: { ratingValue: '' } }
          }
          let firstDownloadUrl: string = CJLoader.getBookFirstDownloadUrl(resHtml)
          let firstDownloadInfo: string = CJLoader.getBookFirstDownloadInfo(resHtml)
          resHtml = CJLoader.getBookInfo(resHtml)
            .replaceAll("\\n", "")
            .replaceAll("\\\"", "\"")
            .replaceAll("\"datePublished\": ,", "")
          resBookInfo = (JSON.parse(resHtml) as object) as I_BookDetailedInfo
          resBookInfo.firstDownloadUrl = firstDownloadUrl.replaceAll("\\\"", "")
          resBookInfo.firstDownloadInfo = (JSON.parse(firstDownloadInfo) as object) as firstDownloadInfo
          return [1, JSON.stringify(resBookInfo)] as [number, string]
        } catch (err) {
          return [0, JSON.stringify(err)] as [number, string]
        }
      } catch (err) {
        return [0, JSON.stringify(err)] as [number, string]
      }
    })
      .catch((err: BusinessError) => {
        return [0, JSON.stringify(err)] as [number, string]
      }).finally(() => {
        req.destroy()
      });
  }

  /*
  @Param req http请求体
  @Param bookID 书籍id
  @Return 类型为[number, string]元组 元素0表示获取状态（0为失败， 1为成功） string表示消息(成功为序列化后的数据字符串，其余为报错内容)
 */
  static async getMoreDownloadWay(req: http.HttpRequest, bookID: number): Promise<[number, string]> {
    console.log(`尝试获取更多下载方式`)
    return await req.request(`${__ZlibUser__.baseApi_url}/book/${bookID}/formats`, {
      method: http.RequestMethod.GET,
      header: {
        'sec-ch-ua-platform': '"Windows"',
        'user-agent': user_agent,
        'Cookie': __ZlibUser__.cookie,
      }
    }).then((data: http.HttpResponse) => {
      let obj = JSON.parse(JSON.stringify(data));
      let result = JSON.parse((obj as object)?.['result']);
      console.log(JSON.stringify(result))
      return [1, JSON.stringify((result as object)?.['books'])] as [number, string]
    })
      .catch((err: BusinessError) => {
        return [0, JSON.stringify(err)] as [number, string]
      }).finally(() => {
        req.destroy()
      });
  }

  static async searchBook(req: http.HttpRequest, bookName: string, page: number = 1) {
    return await req.request(`${__ZlibUser__.base_url}/s/${encodeURI(bookName)}?page=${page}`, {
      method: http.RequestMethod.GET,
      header: {
        'sec-ch-ua-platform': '"Windows"',
        'user-agent': user_agent,
        'Cookie': __ZlibUser__.cookie,
      }
    }).then((data: http.HttpResponse) => {
      let jsonString: string = CJLoader.getSearchBookArray(JSON.stringify(data.result))
      let jsonArray: I_searchBook[] = JSON.parse(jsonString) as I_searchBook[]
      return [1, JSON.stringify(jsonArray)] as [number, string]
    })
      .catch((err: BusinessError) => {
        return [0, JSON.stringify(err)] as [number, string]
      }).finally(() => {
        req.destroy()
      });
  }

  static async downloadBook(bookUrl: string, bookInfo: I_BookDetailedInfo): Promise<[number, string]> {
    let req = http.createHttp()
    let url: string = __ZlibUser__.base_url + bookUrl
    XContext.toast($r('app.string.Tip_TryToDownload'))
    return await req.request(url,
      {
        method: http.RequestMethod.POST,
        header: {
          'sec-ch-ua-platform': '"Windows"',
          'user-agent': user_agent,
          'Cookie': __ZlibUser__.cookie,
        }
      }).then(async (data: http.HttpResponse) => {

      let temp: I_trulyDownloadUrl = JSON.parse(JSON.stringify(data.header)) as I_trulyDownloadUrl
      if (temp.location == undefined || temp.location.includes('wrongHash') || !temp.location.includes('books-files')) {
        return [0, XContext.getStringFromResource($r('app.string.Tip_DownloadError'))] as [number, string]
      } else {
        let matches = JSON.stringify(temp.location.split('/')[7]).match(new RegExp('filename=([^&]+)'));
        let encodedFilename: string = matches ? matches[1] : '';
        let decodedFilename = decodeURI(encodedFilename)
        let downloadPath = await XContext.getDownloadFolderPath()

        let id = __ZlibUser__.notificationID++

        let downloadItem: DownloadInfo = new DownloadInfo()
        downloadItem.fileName = decodedFilename
        downloadItem.fileImage = bookInfo.image

        let customDownloadListener: DownloadListener = {
          onSuccess: () => {
            downloadItem.status = DownloadStatus.Complete
            LNotificationManager.pushNotificationWithProgress(id, 100, '下载完成', decodedFilename)
            shareBook(`${downloadPath}/${decodedFilename}`)
            XContext.toast(XContext.getStringFromResource($r('app.string.Tip_DownloadSuccess')) + decodedFilename, 3000)
            console.log(`下载成功`)
          },
          onFail: (err: BusinessError) => {
            LNotificationManager.pushNotificationWithProgress(id, 100, '下载失败', decodedFilename)
            console.log(`下载失败:${JSON.stringify(err)}`)
            XContext.toast(XContext.getStringFromResource($r('app.string.Tip_DownloadingError')) + JSON.stringify(err),
              3000)
            downloadItem.status = DownloadStatus.Error
            return [0, JSON.stringify(err)] as [number, string]
          },
          onPause: () => {
            downloadItem.status = DownloadStatus.Pause
          },
          onProgressUpdate: (downloadProgress: DownloadProgressInfo) => {
            let progress = Math.trunc(downloadProgress.transferredSize / downloadProgress.totalSize * 10000) / 100

            downloadItem.progress = progress
            LNotificationManager.pushNotificationWithProgress(id, progress, `正在下载${progress}%`, decodedFilename)

            console.log(`onProgressUpdate:, download: transferred size:${downloadProgress.transferredSize}, total size:${downloadProgress.totalSize}`)
          },
          onStart: () => {
            downloadItem.status = DownloadStatus.Downloading
          },
          onCancel: () => {

          },
          onResume: () => {
            downloadItem.status = DownloadStatus.Downloading
          }
        };


        if (__ZlibUser__.downloadManager) {
          try {
            let downloadConfig: DownloadConfig = {
              url: temp.location, // 远端下载地址（必选）
              fileName: decodedFilename, // 下载后的本地文件名（必选）
              fileDir: downloadPath,
              concurrency: 1
            };
            BackgroundUtil.startContinuousTask()

            XContext.toast($r('app.string.Tip_StartDownload'))

            downloadItem.downLoadTask =
              __ZlibUser__.downloadManager.createDownloadTask(downloadConfig, customDownloadListener)

            __Download__.downloadArray.pushData(downloadItem)

          } catch (e) {
            XContext.toast(XContext.getStringFromResource($r('app.string.Tip_DownloadingError')) + JSON.stringify(e),
              3000)
          }
        }
        return [1, ''] as [number, string]
      }
    })
      .catch((err: BusinessError) => {
        XContext.toast(XContext.getStringFromResource($r('app.string.Tip_DownloadingError')) + JSON.stringify(err),
          3000)
        return [0, JSON.stringify(err)] as [number, string]
      })
      .finally(() => {
        req.destroy()
      });
  }
}
import { http } from '@kit.NetworkKit';
import { BusinessError, request } from '@kit.BasicServicesKit';
import { firstDownloadInfo, I_BookDetailedInfo, I_BookInfo } from '../selineRead/models/interfaces/I_BookInfo';
import { user_agent } from '../selineRead/commons/commonItem';
import { JSON, util } from '@kit.ArkTS';
import { Download, __Download__, __Setting__, __ZlibUser__ } from '../selineRead/commons/shareDatas';
import { File, LNotificationManager, XContext, XPreferencesManager } from 'commonpackage';
import { I_trulyDownloadUrl } from './interface/I_DownloadInfo';
import { DownloadConfig, DownloadListener, DownloadProgressInfo } from '@hadss/super_fast_file_trans';
import { I_searchBook } from './interface/I_SearchInfo';
import { BackgroundUtil } from '../selineRead/models/classes/BackgroundRunningManager';
import { shareBook } from '../selineRead/models/utils/ShareBook';
import { DownloadInfo, DownloadStatus } from '../selineRead/models/classes/DownloadInfo';
import { RelationStoreManager } from '../selineRead/models/classes/DataBase';
import { relationalStore } from '@kit.ArkData';
import { fileIo } from '@kit.CoreFileKit';
import { BookInfo } from '../selineRead/pages/zlibrary/BookInfo/BookInfo';
import { CommonEvent } from '../selineRead/models/classes/CommonEvent';
import { I_loginRes } from './interface/I_loginInfo';

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
    return await req.request(`${__ZlibUser__.baseEApi_url}/user/login?email=${email}&password=${password}`, {
      method: http.RequestMethod.POST,
      header: {
        'sec-ch-ua-platform': '"Windows"',
        'user-agent': user_agent,
      },
    }).then(async (data: http.HttpResponse) => {
      let obj = JSON.parse(JSON.stringify(data))
      let result = JSON.parse((obj as object)?.['result']) as I_loginRes

      if (result.success == 0) {
        return [0,result.error] as [number, string]
      }else {
        result.user.passWord = password
        return [1,JSON.stringify(result.user)] as [number, string]
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
    return await req.request(`${__ZlibUser__.baseEApi_url}/eapi/user/profile`, {
      method: http.RequestMethod.GET,
      header: {
        'sec-ch-ua-platform': '"Windows"',
        'user-agent': user_agent,
        'Cookie': cookie//this.cookie,;
      }
    }).then((data: http.HttpResponse) => {
      try {
        console.log(JSON.stringify(data.result));
        return [1, ''] as [number, string]

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
        'cookie': __ZlibUser__.cookie
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
    console.log(bookHref)
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
      //let jsonString: string = CJLoader.getSearchBookArray(JSON.stringify(data.result))
      let jsonArray: I_searchBook[] = JSON.parse("") as I_searchBook[]
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

        if (__ZlibUser__.downloadManager) {
          try {
            if (__Setting__.overrideConflictFile) {
              if (fileIo.accessSync(downloadPath + decodedFilename)) {
                fileIo.unlinkSync(downloadPath + decodedFilename)
                console.log(`删除重复文件成功`)
              }
            }else {
              let newFileName = decodedFilename
              if (!__Setting__.overrideConflictFile) {
                const fileList: string[] =  fileIo.listFileSync(downloadPath);
                if (fileList.includes(decodedFilename)) {
                  let counter = 1;
                  const nameParts = decodedFilename.split('.');
                  const baseName = nameParts[0];
                  console.log(baseName)
                  const extension = nameParts.length > 1 ? `.${nameParts.slice(1).join('.')}` : '';
                  while (fileList.includes(newFileName)) {
                    newFileName = `${baseName}(${counter})${extension}`;
                    counter++;
                  }
                }
              }
              decodedFilename = newFileName
            }
            BackgroundUtil.startContinuousTask()
            XContext.toast($r('app.string.Tip_StartDownload'))
            let time = new Date()
            let downloadItem: DownloadInfo = new DownloadInfo()
            downloadItem.fileName = decodedFilename
            downloadItem.fileImage = bookInfo.image
            downloadItem.status = DownloadStatus.Idle
            downloadItem.bookAuthor = bookInfo.author[0].name
            downloadItem.bookHref = bookInfo.href ?? ''
            downloadItem.bookId = bookInfo.bookID ?? 0
            downloadItem.downloadTime = time.toISOString()
            downloadItem.downLoadTask = undefined
            await RelationStoreManager.addValue(__ZlibUser__.dataBase, 'ZlibDownloadTable', {
              BookID: bookInfo.bookID ?? 0,
              BookHref: bookInfo.href ?? '',
              BookName: decodedFilename,
              BookAuthor: JSON.stringify(bookInfo.author[0]?.name),
              BookPublisher: bookInfo.publisher.name,
              BookImage: bookInfo.image,
              BookDownLoadTime: time.toISOString(),
              HaveDownload: 0
            })
            let predicates = new relationalStore.RdbPredicates('ZlibDownloadTable');
            predicates.equalTo('BookName', decodedFilename)
              .equalTo("BookID", bookInfo.bookID ?? 0)
              .equalTo("BookDownLoadTime", time.toISOString())
            if (decodedFilename.includes('txt') || decodedFilename.includes('TXT')) {
              let allContent: ArrayBuffer[] = []
              let length: number = 0
              downloadItem.downloadType = 'txt'
              __Download__.downloadArray.pushUnshiftData(downloadItem)
              let req = http.createHttp()
              req.request(temp.location,
                {
                  method: http.RequestMethod.HEAD,
                  header: {
                    'sec-ch-ua-platform': '"Windows"',
                    'user-agent': user_agent,
                    'Cookie': __ZlibUser__.cookie,
                  }
                })
                .then((res) => {
                  if (res.responseCode == 200) {
                    let httpRequest = http.createHttp();
                    downloadItem.downLoadTask = httpRequest
                    downloadItem.status = DownloadStatus.Downloading
                    LNotificationManager.pushNotificationWithProgress(id, 10, `TXT文件不展示下载进度`,
                      decodedFilename)

                    httpRequest.on("dataReceive", (data: ArrayBuffer) => {
                      length += data.byteLength
                      console.log(`下载了:${data.byteLength}`);
                      allContent.push(data)
                    });
                    httpRequest.on("dataReceiveProgress", (data: http.DataReceiveProgressInfo) => {
                      console.info("dataReceiveProgress:" + JSON.stringify(data.totalSize));
                    });
                    httpRequest.on("dataEnd", () => {
                      let content: ArrayBuffer = new ArrayBuffer(length)
                      const mergedView = new Uint8Array(content);
                      let offset = 0;
                      allContent.forEach(buffer => {
                        const view = new Uint8Array(buffer);
                        mergedView.set(view, offset);
                        offset += view.length;
                      });


                      File.write(downloadPath + decodedFilename, mergedView.buffer).then((res) => {
                        if (res) {
                          LNotificationManager.pushNotificationWithProgress(id, 100, '下载完成', decodedFilename)
                          downloadItem.status = DownloadStatus.Complete
                          RelationStoreManager.updateValue(__ZlibUser__.dataBase, predicates, {
                            BookID: bookInfo.bookID ?? 0,
                            BookHref: bookInfo.href ?? '',
                            BookName: decodedFilename,
                            BookAuthor: JSON.stringify(bookInfo.author[0]?.name),
                            BookPublisher: bookInfo.publisher.name,
                            BookImage: bookInfo.image,
                            BookDownLoadTime: time.toISOString(),
                            HaveDownload: 1
                          })
                          if (__Setting__.shareAfterDownload) {
                            shareBook(`${downloadPath}/${decodedFilename}`)
                          }
                          console.log(`下载完成`);
                        } else {
                          RelationStoreManager.updateValue(__ZlibUser__.dataBase, predicates, {
                            BookID: bookInfo.bookID ?? 0,
                            BookHref: bookInfo.href ?? '',
                            BookName: decodedFilename,
                            BookAuthor: JSON.stringify(bookInfo.author[0]?.name),
                            BookPublisher: bookInfo.publisher.name,
                            BookImage: bookInfo.image,
                            BookDownLoadTime: time.toISOString(),
                            HaveDownload: 2
                          })
                          downloadItem.status = DownloadStatus.Failed
                          LNotificationManager.pushNotificationWithProgress(id, 100, '下载失败', decodedFilename)
                          XContext.toast(XContext.getStringFromResource($r('app.string.Tip_DownloadingError')) + JSON.stringify('保存失败'),3000)
                        }
                      })
                      httpRequest.off('dataEnd')
                      httpRequest.off('dataReceive')
                      httpRequest.off('dataReceiveProgress')
                    });
                    console.log(temp.location)
                    httpRequest.requestInStream(temp.location, {
                      method: http.RequestMethod.GET,
                      header: {
                        'sec-ch-ua-platform': '"Windows"',
                        'user-agent': user_agent,
                        'Cookie': __ZlibUser__.cookie,
                      }
                    }).then((data: number) => {
                      console.info("requestInStream OK!" + data);
                    }).catch((err: Error) => {
                      RelationStoreManager.updateValue(__ZlibUser__.dataBase, predicates, {
                        BookID: bookInfo.bookID ?? 0,
                        BookHref: bookInfo.href ?? '',
                        BookName: decodedFilename,
                        BookAuthor: JSON.stringify(bookInfo.author[0]?.name),
                        BookPublisher: bookInfo.publisher.name,
                        BookImage: bookInfo.image,
                        BookDownLoadTime: time.toISOString(),
                        HaveDownload: 2
                      })
                      console.log(`下载失败:${JSON.stringify(err)}`)
                      downloadItem.status = DownloadStatus.Failed
                      LNotificationManager.pushNotificationWithProgress(id, 100, '下载失败', decodedFilename)
                      XContext.toast(XContext.getStringFromResource($r('app.string.Tip_DownloadingError')) + JSON.stringify(err),3000)
                    })
                  }else {
                    RelationStoreManager.updateValue(__ZlibUser__.dataBase, predicates, {
                      BookID: bookInfo.bookID ?? 0,
                      BookHref: bookInfo.href ?? '',
                      BookName: decodedFilename,
                      BookAuthor: JSON.stringify(bookInfo.author[0]?.name),
                      BookPublisher: bookInfo.publisher.name,
                      BookImage: bookInfo.image,
                      BookDownLoadTime: time.toISOString(),
                      HaveDownload: 2
                    })
                    downloadItem.status = DownloadStatus.Failed
                    LNotificationManager.pushNotificationWithProgress(id, 100, '下载失败', decodedFilename)
                    XContext.toast(XContext.getStringFromResource($r('app.string.Tip_DownloadingError')) + '链接服务器失败',3000)
                  }

                }).catch((err: BusinessError) => {
                RelationStoreManager.updateValue(__ZlibUser__.dataBase, predicates, {
                  BookID: bookInfo.bookID ?? 0,
                  BookHref: bookInfo.href ?? '',
                  BookName: decodedFilename,
                  BookAuthor: JSON.stringify(bookInfo.author[0]?.name),
                  BookPublisher: bookInfo.publisher.name,
                  BookImage: bookInfo.image,
                  BookDownLoadTime: time.toISOString(),
                  HaveDownload: 2
                })
                console.log(`下载失败:${JSON.stringify(err)}`)
                downloadItem.status = DownloadStatus.Failed
                downloadItem.downloadType = 'other'
                LNotificationManager.pushNotificationWithProgress(id, 100, '下载失败', decodedFilename)
                XContext.toast(XContext.getStringFromResource($r('app.string.Tip_DownloadingError')) + JSON.stringify(err),3000)
              })


            } else {
              let downloadConfig: DownloadConfig = {
                url: temp.location, // 远端下载地址（必选）
                fileName: decodedFilename, // 下载后的本地文件名（必选）
                fileDir: downloadPath,
                concurrency: 1,
                isOverwrite: __Setting__.overrideConflictFile,
                isBreakpointResume: false,
                requestHeaders: {
                  'sec-ch-ua-platform': '"Windows"',
                  'user-agent': user_agent
                }
              }

              let customDownloadListener: DownloadListener = {
                onSuccess: () => {
                  downloadItem.status = DownloadStatus.Complete
                  LNotificationManager.pushNotificationWithProgress(id, 100, '下载完成', decodedFilename)
                  if (__Setting__.shareAfterDownload) {
                    shareBook(`${downloadPath}/${decodedFilename}`)
                  }
                  XContext.toast(XContext.getStringFromResource($r('app.string.Tip_DownloadSuccess')) + decodedFilename,
                    3000)
                  console.log(`下载成功`)
                  let predicates = new relationalStore.RdbPredicates('ZlibDownloadTable');
                  predicates.equalTo('BookName', decodedFilename)
                    .equalTo("BookID", bookInfo.bookID ?? 0)
                    .equalTo("BookDownLoadTime", time.toISOString())
                  RelationStoreManager.updateValue(__ZlibUser__.dataBase, predicates, {
                    BookID: bookInfo.bookID ?? 0,
                    BookHref: bookInfo.href ?? '',
                    BookName: decodedFilename,
                    BookAuthor: JSON.stringify(bookInfo.author[0]?.name),
                    BookPublisher: bookInfo.publisher.name,
                    BookImage: bookInfo.image,
                    BookDownLoadTime: time.toISOString(),
                    HaveDownload: 1
                  })
                },
                onFail: (err: BusinessError) => {
                  downloadItem.status = DownloadStatus.Failed
                  LNotificationManager.pushNotificationWithProgress(id, 100, '下载失败', decodedFilename)
                  console.log(`下载失败:${JSON.stringify(err)}`)
                  XContext.toast(XContext.getStringFromResource($r('app.string.Tip_DownloadingError')) +
                  JSON.stringify(err),
                    3000)
                  RelationStoreManager.updateValue(__ZlibUser__.dataBase, predicates, {
                    BookID: bookInfo.bookID ?? 0,
                    BookHref: bookInfo.href ?? '',
                    BookName: decodedFilename,
                    BookAuthor: JSON.stringify(bookInfo.author[0]?.name),
                    BookPublisher: bookInfo.publisher.name,
                    BookImage: bookInfo.image,
                    BookDownLoadTime: time.toISOString(),
                    HaveDownload: 2
                  })
                  return [0, JSON.stringify(err)] as [number, string]
                },
                onProgressUpdate: (downloadProgress: DownloadProgressInfo) => {
                  if (downloadItem.status != DownloadStatus.Downloading) {
                    downloadItem.status = DownloadStatus.Downloading
                  }
                  let progress = Math.trunc(downloadProgress.transferredSize / downloadProgress.totalSize * 10000) / 100
                  downloadItem.progress = progress
                  LNotificationManager.pushNotificationWithProgress(id, progress, `正在下载${progress}%`,
                    decodedFilename)
                  console.log(`onProgressUpdate:, download: transferred size:${downloadProgress.transferredSize}, total size:${downloadProgress.totalSize}`)
                },
                onStart: () => {
                  downloadItem.status = DownloadStatus.Starting
                  console.log(`正在开始`)
                },
                onCancel: () => {
                  downloadItem.status = DownloadStatus.Cancel
                  console.log(`正在取消`)
                }
              };

              downloadItem.downLoadTask =
                __ZlibUser__.downloadManager.createDownloadTask(downloadConfig, customDownloadListener)

              downloadItem.downLoadTask?.start()

              __Download__.downloadArray.pushUnshiftData(downloadItem)

            }
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
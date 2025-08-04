import { BusinessError, request } from '@kit.BasicServicesKit';
import { BasicDataSource } from './BasicDataSource';
import { I_RecommendBook } from '../interfaces/I_RecommendBook';
import { JSON } from '@kit.ArkTS';
import { CJLoader } from '../../CJloader/CJLoader';
import { firstDownloadInfo, I_BookInfo, I_searchBook } from '../interfaces/I_BookInfo';
import { I_DownloadInfo, I_trulyDownloadUrl } from '../interfaces/I_DownloadInfo';
import { fileUri, fileIo as fs, picker } from '@kit.CoreFileKit';
import { promptAction } from '@kit.ArkUI';
import { I_CookieInfo } from '../interfaces/I_CookieInfo';
import http from '@ohos.net.http';
import { __DataBase__, __Notification__, __User__ } from './ShareDatas';
import NeoPreferencesUtil from './XPreferencesUtil';
import { linderNotificationManager } from './LNotificationManager';
import { I_UserDownloadLimit } from '../interfaces/I_UserDownloadLimit';
import { linderDataBaseManger } from './LDataBaseManager';
import { relationalStore } from '@kit.ArkData';
import { zlibHaveDownloadTable } from '../commons/zlibHaveDownloadTable';
import { I_ZlibHaveDownloadTable } from '../interfaces/I_zlibHaveDownloadTable';
import { common } from '@kit.AbilityKit';
import { uniformTypeDescriptor as utd } from '@kit.ArkData';
import { systemShare } from '@kit.ShareKit';

@ObservedV2
export class zlib {
  @Trace recommendBooksArray: BasicDataSource<I_RecommendBook> = new BasicDataSource<I_RecommendBook>()
  @Trace searchBooksArray: BasicDataSource<I_searchBook> = new BasicDataSource<I_searchBook>()
  @Trace localDownloadHistoryArray: BasicDataSource<I_ZlibHaveDownloadTable> = new BasicDataSource<I_ZlibHaveDownloadTable>()
  @Trace userDownloadLimitAndDonation: I_UserDownloadLimit | undefined
  //官方:https://zh.z-library.sk
  base_url: string = 'https://zh.zlibraryd.ru'
  baseApi_url: string = 'https://zh.zlibraryd.ru/papi'
  cookie: string = ''

  private setCookies(remix_userkey: string, remix_userid: string) {
    this.cookie =
      `siteLanguage=zh; selectedSiteMode=books; remix_userkey=${remix_userkey}; remix_userid=${remix_userid}; redirects_count=%7B%22auth%22%3A1%2C%22hide-auth-params%22%3A1%7D`
  }

  private getUtdForm(fileName:string):utd.UniformDataType
  {
    let fileSuffix:string[] = fileName.split('.')

    switch (fileSuffix[fileSuffix.length-1].toLowerCase())
    {
      case 'pdf':
        return utd.UniformDataType.PDF
      case 'epub':
        return utd.UniformDataType.EPUB
      case 'azw3':
        return utd.UniformDataType.AZW3
      case 'text': case 'txt':
        return utd.UniformDataType.TEXT
      default :
        return utd.UniformDataType.EBOOK
    }

  }


  async loginIn(email: string, password: string) {

    let req = http.createHttp()
    await req.request(`${this.base_url}/rpc.php`, {
      method: http.RequestMethod.GET,
      header: {
        'sec-ch-ua-platform': '"Windows"',
        'user-agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/138.0.0.0 Safari/537.36 Edg/138.0.0.0',
        'Cookie': this.cookie,
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
    }).then((data: http.HttpResponse) => {
      let obj = JSON.parse(JSON.stringify(data))
      let result = JSON.parse((obj as object)?.['result'])
      let tempCookies: I_CookieInfo = (result as object)?.['response']
      if (tempCookies.message == undefined) {
        promptAction.showToast({ message: `欢迎`, duration: 1000 })
        this.setCookies(tempCookies.user_key, tempCookies.user_id.toString())
        NeoPreferencesUtil.putPreferencesValue('selineRead', "isLoginZlib", true)
        NeoPreferencesUtil.putPreferencesValue('selineRead', "zlibAccount", email)
        NeoPreferencesUtil.putPreferencesValue('selineRead', "zlibPassword", password)
        NeoPreferencesUtil.putPreferencesValue('selineRead', "zlibCookie", this.cookie)
        __User__.zlibAccount = email
        __User__.zlibPassword = password
        __User__.isLoginZlib = true
        this.getUserDownloadLimit()
      } else {
        //todo:API18后换成openToast
        promptAction.showToast({ message: `登录失败`, duration: 1000 })
        NeoPreferencesUtil.putPreferencesValue('selineRead', "isLoginZlib", false)
        NeoPreferencesUtil.putPreferencesValue('selineRead', "zlibCookies", '')
        NeoPreferencesUtil.putPreferencesValue('selineRead', "zlibAccount", '')
        NeoPreferencesUtil.putPreferencesValue('selineRead', "zlibPassword", '')
        __User__.zlibAccount = ''
        __User__.zlibPassword = ''
        __User__.isLoginZlib = false
      }
    }).catch((err: Error) => {
      console.error('error:' + JSON.stringify(err));
    });
    req.destroy()
  }


  async getUserDownloadLimit() {
    let req = http.createHttp()
    this.userDownloadLimitAndDonation = undefined
    await req.request(`${this.base_url}/?ts`, {
      method: http.RequestMethod.GET,
      header: {
        'sec-ch-ua-platform': '"Windows"',
        'user-agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/138.0.0.0 Safari/537.36 Edg/138.0.0.0',
        'Cookie': this.cookie,
      }
    }).then((data: http.HttpResponse) => {
      let res = CJLoader.getUserDownloadLimitAndDonation(JSON.stringify(data.result))
      if (res) {
        this.userDownloadLimitAndDonation = JSON.parse(res) as I_UserDownloadLimit
        console.log(`FUCK${this.userDownloadLimitAndDonation.downloadLimit}`)
      }
    }).catch((err: Error) => {
      console.error('error2:' + JSON.stringify(err));
    });
    req.destroy()
  }

  async getLocalDownloadHistory(){
    let res:string  =  await linderDataBaseManger.queryValueToRelationalDataBase(__DataBase__.baseStore,"zlibHaveDownload",[],zlibHaveDownloadTable)
    let resArray:I_ZlibHaveDownloadTable[] = JSON.parse(res) as I_ZlibHaveDownloadTable[]
    resArray.forEach((item)=>{
      this.localDownloadHistoryArray.pushData(item)
    })
  }

  async refreshUrl() {
    let req = http.createHttp()
    await req.request(`${this.base_url}`, {
      method: http.RequestMethod.GET,
      header: {
        'sec-ch-ua-platform': '"Windows"',
        'user-agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/138.0.0.0 Safari/537.36 Edg/138.0.0.0',
      }
    }).then((data: http.HttpResponse) => {

      let location: string = data.header?.['location']

      if (location != undefined && location != '') {
        location = location.substring(0, location.length - 1)
        this.base_url = location
        this.baseApi_url = location + '/papi'
        NeoPreferencesUtil.putPreferencesValue('selineRead', "zlibUrl", location)
      }

    }).catch((err: Error) => {
      console.error('error2:' + JSON.stringify(err));
    });
    req.destroy()

  }

  async getRecommendBooks(page: number) {
    let req = http.createHttp()
    req.request(`${this.baseApi_url}/book/mostpopular/mosaic/20/${page}`, {
      method: http.RequestMethod.GET,
      header: {
        'sec-ch-ua-platform': '"Windows"',
        'user-agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/138.0.0.0 Safari/537.36 Edg/138.0.0.0',
        'Cookie': this.cookie,
      }
    }, (err: Error, data: http.HttpResponse) => {
      if (!err) {
        try {
          let obj = JSON.parse(JSON.stringify(data))
          let result = JSON.parse((obj as object)?.['result'])
          let tempArray: I_RecommendBook[] = (result as object)?.['books']

          tempArray.forEach((item) => {
            this.recommendBooksArray.pushData(item)
          })
        } catch (e) {
        }
      } else {
        console.error('FUCK error:' + JSON.stringify(err));
      }
      req.destroy();
    });
  }


  async getBookInfo(bookHref: string): Promise<I_BookInfo> {
    let req = http.createHttp()
    let res: string = ''
    let resBookInfo: I_BookInfo = {
      name: '',
      description: "",
      author: [],
      publisher: { name: '' },
      image: "",
      isbn: "",
      numberOfPages: 0,
      datePublished: 0,
      inLanguage: { name: '' },
      review: { reviewBody: '', datePublished: '', reviewRating: { ratingValue: '' } }
    }
    await req.request(`${this.base_url}${bookHref}`, {
      method: http.RequestMethod.GET,
      header: {
        'sec-ch-ua-platform': '"Windows"',
        'user-agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/138.0.0.0 Safari/537.36 Edg/138.0.0.0',
        'Cookie': this.cookie,
      }
    }).then((data: http.HttpResponse) => {
      res = JSON.stringify(data.result)

    }).catch((err: Error) => {
      res = 'error'
      console.error('error1:' + JSON.stringify(err));
    });

    req.destroy()

    if (res != 'error') {
      let firstDownloadUrl: string = CJLoader.getBookFirstDownloadUrl(res)
      let firstDownloadInfo: string = CJLoader.getBookFirstDownloadInfo(res)
      res = CJLoader.getBookInfo(res).replaceAll("\\n", "").replaceAll("\\\"", "\"")
      resBookInfo = (JSON.parse(res) as object) as I_BookInfo
      resBookInfo.firstDownloadUrl = firstDownloadUrl.replaceAll("\\\"", "")
      resBookInfo.firstDownloadInfo = (JSON.parse(firstDownloadInfo) as object) as firstDownloadInfo
    }
    return resBookInfo;

  }


  async getBookDownloadsInfo(bookID: number): Promise<I_DownloadInfo[]> {
    let req = http.createHttp()

    let res: I_DownloadInfo[] = []

    await req.request(`${this.baseApi_url}/book/${bookID}/formats`, {
      method: http.RequestMethod.GET,
      header: {
        'sec-ch-ua-platform': '"Windows"',
        'user-agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/138.0.0.0 Safari/537.36 Edg/138.0.0.0',
        'Cookie': this.cookie,
      }
    }).then((data: http.HttpResponse) => {
      let obj = JSON.parse(JSON.stringify(data))
      let result = JSON.parse((obj as object)?.['result'])
      res = (result as object)?.['books']
    }).catch((err: Error) => {
      console.error('error2:' + JSON.stringify(err));
    });
    req.destroy()

    return res
  }


  async searchBooks(bookName: string, page: number = 1, needClear: boolean = false) {
    if (needClear) {
      this.searchBooksArray.clearData()
    }
    let req = http.createHttp()
    await req.request(`${this.base_url}/s/${encodeURI(bookName)}?page=${page}`, {
      method: http.RequestMethod.GET,
      header: {
        'sec-ch-ua-platform': '"Windows"',
        'user-agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/138.0.0.0 Safari/537.36 Edg/138.0.0.0',
        'Cookie': this.cookie,
      }
    }).then((data: http.HttpResponse) => {

      let jsonString: string = CJLoader.getSearchBookArray(JSON.stringify(data.result))
      let jsonArray: I_searchBook[] = JSON.parse(jsonString) as I_searchBook[]

      if (jsonArray.length == 0 || jsonArray == undefined) {
        //todo:API18后换成openToast
        promptAction.showToast({ message: `未搜到任何结果`, duration: 2000 })
      }

      jsonArray.forEach((item) => {
        this.searchBooksArray.pushData(item)
      })

    }).catch((err: Error) => {

      console.error('error3:' + JSON.stringify(err));
    });

    req.destroy()
  }

  async getTrueDownloadBookUrl(context: Context, bookUrl: string, bookInfo: I_BookInfo) {
    //todo:API18后换成openToast
    promptAction.showToast({ message: `开始下载,通知栏查看进度`, duration: 800 })
    let req = http.createHttp()
    let url: string = this.base_url + bookUrl
    await req.request(url, {
      method: http.RequestMethod.POST,
      header: {
        'sec-ch-ua-platform': '"Windows"',
        'user-agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/138.0.0.0 Safari/537.36 Edg/138.0.0.0',
        'Cookie': this.cookie,
      }
    }).then((data: http.HttpResponse) => {

      let temp: I_trulyDownloadUrl = JSON.parse(JSON.stringify(data.header)) as I_trulyDownloadUrl
      let urlParams = JSON.stringify(temp.location.split('/')[7])
      let pattern = 'filename=([^&]+)'; // 匹配filename参数直到下一个&符号
      let regex = new RegExp(pattern);
      let matches = urlParams.match(regex);
      let encodedFilename: string = matches ? matches[1] : '';
      let decodedFilename = decodeURI(encodedFilename);
      this.downloadBook(context, temp.location, decodedFilename, bookInfo)
    }).catch((err: Error) => {
      //todo:API18后换成openToast
      promptAction.showToast({ message: `下载失败`, duration: 800 })
      console.error('error4:' + JSON.stringify(err));
    });

    req.destroy()
  }

  async downloadBook(context: Context, bookHref: string, fileName: string, bookInfo: I_BookInfo) {
    let notificationID = __Notification__.id++

    try {
      let cachedir = context.cacheDir
      let filePath = cachedir + '/' + fileName
      console.log('downloadTask1 filesDir============: %s/%s', cachedir, fileName);

      await fs.access(filePath).then((canAccess: boolean) => {
        if (canAccess) {
          fs.unlinkSync(filePath)
        }
      })
      request.downloadFile(context, {
        //替换下载地址
        url: bookHref,
        //文件下载后保存的沙箱路径
        filePath: filePath,
        enableMetered: true
      }).then((downloadTask: request.DownloadTask) => {

        const valueBucket: relationalStore.ValuesBucket = {
          BookID: bookInfo.bookID!,
          BookName: bookInfo.name,
          BookHref: bookInfo.href!,
          BookAuthor: bookInfo.author[0].name,
          BookPublisher: bookInfo.publisher.name,
          BookImage: bookInfo.image,
          BookDownLoadTime: new Date().toISOString(),
        };

        linderDataBaseManger.insertValueToRelationalDataBase(__DataBase__.baseStore, 'zlibHaveDownload', valueBucket)

        let progressValue: number = 0

        linderNotificationManager.pushNotificationWithProgress(notificationID, 0, "正在下载", fileName)

        //开启进度回调
        downloadTask.on('progress', (receivedSize: number, totalSize: number) => {

          console.log('download receivedSize: %s, totalSize: %s', receivedSize, totalSize);

          progressValue = receivedSize / totalSize * 100

          linderNotificationManager.pushNotificationWithProgress(notificationID, progressValue, "正在下载", fileName)

        })
        //开启下载完成回调
        downloadTask.on('complete', async () => {
          const taskInfo = await downloadTask.getTaskInfo();
          console.log('downloadTask complete,status: %s', taskInfo.status);
          //todo:API18后换成openToast
          promptAction.showToast({ message: `下载完成`, duration: 800 })
          linderNotificationManager.pushNotificationWithProgress(notificationID, 100, "下载完成", fileName)

          let uri1: string = '';
          const documentViewPicker = new picker.DocumentViewPicker(context);
          documentViewPicker.save({ pickerMode: picker.DocumentPickerMode.DOWNLOAD })
            .then((documentSaveResult: Array<string>) => {
              uri1 = documentSaveResult[0];
              let file0 = fs.openSync(filePath, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE)
              let testFilePath = new fileUri.FileUri(uri1 + '/' + fileName).path;
              let file1 = fs.openSync(testFilePath, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE);
              fs.moveFile(file0.path, file1.path, 0).then(() => {
                console.info("move file succeed");
              }).catch((err: BusinessError) => {
                console.error("move file failed with error message: " + err.message + ", error code: " + err.code);
              });

              fs.closeSync(file0)
              fs.closeSync(file1)

              let data: systemShare.SharedData = new systemShare.SharedData({
                utd: this.getUtdForm(fileName),
                title:fileName,
                uri:uri1 + '/' + fileName
              });

              let controller: systemShare.ShareController = new systemShare.ShareController(data);

              controller.on('dismiss', () => {
                console.info('Share panel closed');
              });

              controller.show(context as common.UIAbilityContext, {
                previewMode: systemShare.SharePreviewMode.DETAIL,
                selectionMode: systemShare.SelectionMode.SINGLE
              });

            })
            .catch((err: BusinessError) => {
              console.error(`Invoke documentViewPicker.save failed, code is ${err.code}, message is ${err.message}`);
            })

        })
      }).catch((err: BusinessError) => {
        promptAction.showToast({
          message: err.message
        });
        //todo:API18后换成openToast
        promptAction.showToast({ message: `下载失败`, duration: 800 })
        linderNotificationManager.pushNotification(notificationID, '下载失败', fileName)
        // 下载请求失败回调，可以弹窗提示失败
        console.log(`FUCK:Invoke downloadTask failed-----, message is: ${err.message}`);
      });

    } catch (error) {
      // 下载请求失败回调，可以弹窗提示失败
      let err: BusinessError = error as BusinessError;
      console.log('Invoke downloadTask failed-----, message is: %s', err.message);
    }

  }
}

export let zlibClient: zlib = new zlib()

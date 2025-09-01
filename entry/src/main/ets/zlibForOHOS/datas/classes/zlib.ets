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
import { __DataBase__, __Notification__, __UI__, __User__ } from './ShareDatas';
import NeoPreferencesUtil from './XPreferencesUtil';
import { linderNotificationManager } from './LNotificationManager';
import { linderDataBaseManger } from './LDataBaseManager';
import { relationalStore } from '@kit.ArkData';
import { zlibHaveDownloadTable } from '../commons/zlibHaveDownloadTable';
import { I_ZlibHaveDownloadTable } from '../interfaces/I_zlibHaveDownloadTable';
import { common, wantAgent, WantAgent } from '@kit.AbilityKit';
import { I_UserInfo } from '../interfaces/I_UserInfo';
import { globlContext } from '../../../entryability/EntryAbility';
import { addLog, getDownloadFolderPath, shareBook } from '../../utils/ToolsUtil';
import { I_Bookshelf, I_Bookshelf_extraBooks, I_ReadLists_Bookshelf } from '../interfaces/I_BookShelf';

@ObservedV2
export class zlib {
  @Trace recommendBooksArray: BasicDataSource<I_RecommendBook> = new BasicDataSource<I_RecommendBook>()
  @Trace searchBooksArray: BasicDataSource<I_searchBook> = new BasicDataSource<I_searchBook>()
  @Trace localDownloadHistoryArray: BasicDataSource<I_ZlibHaveDownloadTable> = new BasicDataSource<I_ZlibHaveDownloadTable>()
  @Trace bookshelfArray: BasicDataSource<I_ReadLists_Bookshelf> = new BasicDataSource<I_ReadLists_Bookshelf>()
  @Trace bookshelfBooks: BasicDataSource<I_Bookshelf_extraBooks> = new BasicDataSource<I_Bookshelf_extraBooks>()
  @Trace userInfo: I_UserInfo | undefined
  //官方:https://zh.z-library.sk
  base_url: string = ''
  baseApi_url: string = ''
  cookie: string = ''

  autoShare: boolean = false

  private setCookies(remix_userkey: string, remix_userid: string) {
    this.cookie =
      `siteLanguage=zh; selectedSiteMode=books; remix_userkey=${remix_userkey}; remix_userid=${remix_userid}; redirects_count=%7B%22auth%22%3A1%2C%22hide-auth-params%22%3A1%7D`
  }


  async loginIn(email: string, password: string) {
    let req = http.createHttp()
    addLog('login', `正在尝试登录`)
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
        addLog('login', `登录成功`)
        this.setCookies(tempCookies.user_key, tempCookies.user_id.toString())
        NeoPreferencesUtil.putPreferencesValue('selineRead', "isLoginZlib", true)
        NeoPreferencesUtil.putPreferencesValue('selineRead', "zlibAccount", email)
        NeoPreferencesUtil.putPreferencesValue('selineRead', "zlibPassword", password)
        NeoPreferencesUtil.putPreferencesValue('selineRead', "zlibCookie", this.cookie)
        __User__.zlibAccount = email
        __User__.zlibPassword = password
        __User__.isLoginZlib = true
        this.getUserInfo()
      } else {
        //todo:API18后换成openToast
        promptAction.showToast({ message: `登录失败,账号密码错误`, duration: 1000 })
        addLog('login', `登录失败,账号密码错误`,true)
        NeoPreferencesUtil.putPreferencesValue('selineRead', "isLoginZlib", false)
        NeoPreferencesUtil.putPreferencesValue('selineRead', "zlibCookies", '')
        NeoPreferencesUtil.putPreferencesValue('selineRead', "zlibAccount", '')
        NeoPreferencesUtil.putPreferencesValue('selineRead', "zlibPassword", '')
        __User__.zlibAccount = ''
        __User__.zlibPassword = ''
        __User__.isLoginZlib = false
      }
    }).catch((err: Error) => {
      addLog('login', `error! ${err.name} ${err.message}`, true)
      promptAction.showToast({ message: JSON.stringify(err), duration: 1000 })
    });
    req.destroy()
  }

  async getUserInfo() {
    let req = http.createHttp()
    await req.request(`${this.base_url}/?ts`, {
      method: http.RequestMethod.GET,
      header: {
        'sec-ch-ua-platform': '"Windows"',
        'user-agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/138.0.0.0 Safari/537.36 Edg/138.0.0.0',
        'Cookie': this.cookie,
      }
    }).then((data: http.HttpResponse) => {
      let res = CJLoader.getUserDownloadLimitAndDonation(JSON.stringify(data.result))
      let avatar = this.userInfo?.avatar ?? CJLoader.getUserAvatar(JSON.stringify(data.result))
      let userName = this.userInfo?.userName ?? CJLoader.getUserName(JSON.stringify(data.result))
      if (res) {
        addLog('getUserInfo', `成功获取用户信息`)
        this.userInfo = JSON.parse(res) as I_UserInfo
        this.userInfo.avatar = avatar
        this.userInfo.userName = userName
      }else{
        addLog('getUserInfo', `获取用户信息失败,疑似仓颉错误`, true)
      }
    }).catch((err: Error) => {
      addLog('getUserInfo', `error! ${err.name} ${err.message}`, true)
      promptAction.showToast({ message: JSON.stringify(err), duration: 1000 })
    });
    req.destroy()
  }

  async getLocalDownloadHistory(){
    addLog('getLocalBook', `获取书架中`)
    let res:string  =  await linderDataBaseManger.queryValueToRelationalDataBase(__DataBase__.baseStore,"zlibHaveDownload",[],zlibHaveDownloadTable)
    let resArray:I_ZlibHaveDownloadTable[] = JSON.parse(res) as I_ZlibHaveDownloadTable[]
    resArray.forEach((item)=>{
      this.localDownloadHistoryArray.pushUnshiftData(item)
    })
    addLog('getLocalBook', `获取完成`)
  }

  async refreshUrl() {
    addLog('refreshUrl', `尝试刷新Url`)
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
      addLog('refreshUrl', `刷新Url成功`)

    }).catch((err: Error) => {
      addLog('refreshUrl', `error! ${err.name} ${err.message}`, true)
      promptAction.showToast({ message: JSON.stringify(err), duration: 1000 })
    });
    req.destroy()

  }

  async getRecommendBooks(page: number): Promise<boolean> {
    addLog('getRecommendBooks', `正在获取推荐书籍page=${page}`)
    return new Promise<boolean>((resolve)=>{
      let req = http.createHttp()
      req.request(`${this.baseApi_url}/book/mostpopular/mosaic/20/${page}`, {
        method: http.RequestMethod.GET,
        header: {
          'sec-ch-ua-platform': '"Windows"',
          'user-agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/138.0.0.0 Safari/537.36 Edg/138.0.0.0',
          'Cookie': this.cookie,
        }
      }, (err: Error, data: http.HttpResponse) => {
        req.destroy();
        if (!err) {
          try {
            let obj = JSON.parse(JSON.stringify(data))
            let result = JSON.parse((obj as object)?.['result'])
            let tempArray: I_RecommendBook[] = (result as object)?.['books']
            tempArray.forEach((item) => {
              this.recommendBooksArray.pushData(item)
            })
            addLog('getRecommendBooks', `获取成功`)
            resolve(true)
          } catch (e) {
            resolve(false)
          }
        } else {
          addLog('getRecommendBooks', `error! ${err.name} ${err.message}`, true)
          promptAction.showToast({ message: JSON.stringify(err), duration: 1000 })
          resolve(false)
        }
      });
    })

  }


  async getBookInfo(bookHref: string): Promise<I_BookInfo> {
    addLog('getBookInfo', `尝试获取书籍信息`)
    __UI__.isHaveOpenBook=true
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
    console.log(`FUCK${bookHref}`)
    await req.request(`${this.base_url}${bookHref}`, {
      method: http.RequestMethod.GET,
      header: {
        'sec-ch-ua-platform': '"Windows"',
        'user-agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/138.0.0.0 Safari/537.36 Edg/138.0.0.0',
        'Cookie': this.cookie,
      }
    }).then((data: http.HttpResponse) => {
      res = JSON.stringify(data.result)
      console.log(`FUCK${res}`)

    }).catch((err: Error) => {
      res = 'error'
      addLog('getBookInfo', `error! ${err.name} ${err.message}`, true)
      promptAction.showToast({ message: JSON.stringify(err), duration: 1000 })
    });

    req.destroy()

    if (res != 'error') {
      console.log(`FUCK123124`)
      try {
        let firstDownloadUrl: string = CJLoader.getBookFirstDownloadUrl(res)
        console.log(`FUCK!${firstDownloadUrl}`)
        let firstDownloadInfo: string = CJLoader.getBookFirstDownloadInfo(res)
        console.log(`FUCK!!${firstDownloadInfo}`)
        res = CJLoader.getBookInfo(res).replaceAll("\\n", "").replaceAll("\\\"", "\"").replaceAll("\"datePublished\": ,","")
        console.log(`FUCK!!!${res}`)
        resBookInfo = (JSON.parse(res) as object) as I_BookInfo
        resBookInfo.firstDownloadUrl = firstDownloadUrl.replaceAll("\\\"", "")
        resBookInfo.firstDownloadInfo = (JSON.parse(firstDownloadInfo) as object) as firstDownloadInfo
        addLog('getBookInfo', `获取成功`)
      }catch (e)
      {
        promptAction.showToast({ message: JSON.stringify(e), duration: 1000 })
        addLog('getBookInfo', `error! ${e.name} ${e.message}`, true)
      }
    }else {
      addLog('getBookInfo', `获取失败`,true)
    }
    console.log(`FUCK${JSON.stringify(resBookInfo)}`)
    __UI__.isHaveOpenBook = false
    return resBookInfo;


  }

  async getBookShelf(page:number)
  {
    addLog('getBookShelf', `尝试获取书单page=${page}`)
    let req = http.createHttp()
    console.log(`FUCK${`${this.baseApi_url}/booklist/get-page/${page}`}`)
    await req.request(`${this.baseApi_url}/booklist/get-page/${page}`, {
      method: http.RequestMethod.POST,
      header: {
        'sec-ch-ua-platform': '"Windows"',
        'user-agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/138.0.0.0 Safari/537.36 Edg/138.0.0.0',
        'Cookie': this.cookie,
      },
      extraData:{
        'access': "public",
        'color': "all",
        'hide18plus': "1",
        'languages':"null",
        'order': "date_updated",
        'searchQuery': ""
      }
    }).then((data: http.HttpResponse) => {
      let obj = JSON.parse(JSON.stringify(data))
      let result = JSON.parse((obj as object)?.['result'])
      let temp:I_Bookshelf = result as I_Bookshelf
      temp.readlists.forEach((item:I_ReadLists_Bookshelf, index:number)=>{
        item.readListsOwners = temp.readlistsOwners[item.user_id]
        item.booksGrouped = temp.booksGrouped[item.id]
        this.bookshelfArray.pushData(item)
      })
      addLog('getBookShelf', `获取书单page=${page}成功`)
    }).catch((err: Error) => {
      addLog('getBookShelf', `error! ${err.name} ${err.message}`, true)
      promptAction.showToast({ message: JSON.stringify(err), duration: 1000 })
    });
    req.destroy()
  }

  async getBookShelfMoreInfo(shelfID:number, page:number)
  {
    addLog('getBookShelfMoreInfo', `获取书单${shelfID},page=${page}`)
    let req = http.createHttp()
    await req.request(`${this.baseApi_url}/booklist/${shelfID}/get-books/${page}`, {
      method: http.RequestMethod.POST,
      header: {
        'sec-ch-ua-platform': '"Windows"',
        'user-agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/138.0.0.0 Safari/537.36 Edg/138.0.0.0',
        'Cookie': this.cookie,
      },
      extraData:{
        'order': "date_savedA",
        'searchQuery': ""
      }
    }).then((data: http.HttpResponse) => {
      let obj = JSON.parse(JSON.stringify(data))
      let result = JSON.parse((obj as object)?.['result'])

      let tempArray:I_Bookshelf_extraBooks[] = (result as object)?.['books']

      tempArray.forEach((item:I_Bookshelf_extraBooks)=>{
        this.bookshelfBooks.pushData(item)
        console.log(`FUCK${JSON.stringify(item)}`);
      })
      addLog('getBookShelfMoreInfo', `书单${shelfID},page=${page}成功`)
    }).catch((err: Error) => {
      addLog('getBookShelfMoreInfo', `error! ${err.name} ${err.message}`, true)
      promptAction.showToast({ message: JSON.stringify(err), duration: 1000 })
    });
    req.destroy()
  }

  async getBookDownloadsInfo(bookID: number): Promise<I_DownloadInfo[]> {
    addLog('getBookDownloadsInfo', `尝试获取${bookID}下载信息`)

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
      addLog('getBookDownloadsInfo', `获取${bookID}下载信息成功`)
    }).catch((err: Error) => {
      addLog('getBookDownloadsInfo', `error! ${err.name} ${err.message}`, true)
      promptAction.showToast({ message: JSON.stringify(err), duration: 1000 })
    });
    req.destroy()

    return res
  }


  async searchBooks(bookName: string, page: number = 1, needClear: boolean = false): Promise<boolean> {
    addLog('searchBooks', `尝试获取${bookName}搜索信息page=${page}`)
    return new Promise<boolean>(async (resolve)=>{
      if (needClear) {
        this.searchBooksArray.clearData()
      }
      let req = http.createHttp()
      req.request(`${this.base_url}/s/${encodeURI(bookName)}?page=${page}`, {
        method: http.RequestMethod.GET,
        header: {
          'sec-ch-ua-platform': '"Windows"',
          'user-agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/138.0.0.0 Safari/537.36 Edg/138.0.0.0',
          'Cookie': this.cookie,
        },
        readTimeout:3000
      }).then((data: http.HttpResponse) => {


        let jsonString: string = CJLoader.getSearchBookArray(JSON.stringify(data.result))
        let jsonArray: I_searchBook[] = JSON.parse(jsonString) as I_searchBook[]

        if (jsonArray.length == 0 || jsonArray == undefined) {
          //todo:API18后换成openToast
          promptAction.showToast({ message: `无更多结果`, duration: 2000 })
          addLog('searchBooks', `无更多结果`)
        }

        jsonArray.forEach((item) => {
          this.searchBooksArray.pushData(item)
        })
        addLog('searchBooks', `获取成功`)
        resolve(true)

      }).catch((err: Error) => {
        promptAction.showToast({ message: JSON.stringify(err), duration: 1000 })
        addLog('searchBooks', `error! ${err.name} ${err.message}`, true)
        resolve(false)
      });

      req.destroy()

    })

  }

  async getTrueDownloadBookUrl(context: Context, bookUrl: string, bookInfo: I_BookInfo) {
    addLog('getTrueDownloadBookUrl', `正在尝试下载`)
    //todo:API18后换成openToast
    promptAction.showToast({ message: `正在尝试下载`, duration: 800 })
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
      promptAction.showToast({ message: `下载失败，请检查是否登录，是否超出下载限制`, duration: 800 })
      addLog('getTrueDownloadBookUrl', `error! ${err.name} ${err.message}`, true)
    });

    req.destroy()
  }

  async downloadBook(context: Context, bookHref: string, fileName: string, bookInfo: I_BookInfo) {
    let notificationID = __Notification__.id++
    addLog('downloadBook', `正在下载,查看通知栏下载进度`)
    //todo:API18后换成openToast
    promptAction.showToast({ message: `正在下载,查看通知栏下载进度`, duration: 800 })
    try {
      let cachedir = context.cacheDir
      let filePath = cachedir + '/' + fileName
      console.log('downloadTask1 filesDir============: %s/%s', cachedir, fileName);
      try {
        fs.unlinkSync(filePath)
      }catch{}
      const downloadPath = await getDownloadFolderPath()
      request.downloadFile(context, {
        //替换下载地址
        url: bookHref,
        //文件下载后保存的沙箱路径
        filePath: filePath,
        enableMetered: true,
        background: true
      }).then((downloadTask: request.DownloadTask) => {

        //开启下载完成回调
        downloadTask.on('complete', async () => {
          const taskInfo = await downloadTask.getTaskInfo();
          console.log('FUCK:downloadTask complete,status: %s', taskInfo.status);
          //todo:API18后换成openToast
          promptAction.showToast({ message: `下载完成`, duration: 800 })
          addLog('downloadBook', `下载完成`)
          try {
            let file0 = fs.openSync(filePath, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE)
            let testFilePath = new fileUri.FileUri(downloadPath + fileName).path;
            let file1 = fs.openSync(testFilePath, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE);
            fs.moveFile(file0.path, file1.path, 0).then(() => {
              console.info("move file succeed");
            }).catch((err: BusinessError) => {
              console.error("move file failed with error message: " + err.message + ", error code: " + err.code);
            });

            fs.closeSync(file0)
            fs.closeSync(file1)
            const valueBucket: relationalStore.ValuesBucket = {
              BookID: bookInfo.bookID!,
              BookName: bookInfo.name,
              BookHref: bookInfo.href!,
              BookAuthor: bookInfo.author[0].name,
              BookPublisher: bookInfo.publisher.name,
              BookImage: bookInfo.image,
              BookDownLoadTime: new Date().toISOString(),
              BookFilePath: testFilePath,
              haveDownload : 0
            };

            linderDataBaseManger.insertValueToRelationalDataBase(__DataBase__.baseStore, 'zlibHaveDownload', valueBucket).then(()=>{
              this.flashDownloadHistoryAndLocalBooksList()
            })
            if(this.autoShare) shareBook(testFilePath)


          }catch (e)
          {
            console.log(`FUCK${JSON.stringify(e)}`)
          }

        })
      }).catch((err: BusinessError) => {
        promptAction.showToast({
          message: err.message
        });
        //todo:API18后换成openToast
        promptAction.showToast({ message: `下载失败`, duration: 800 })
        addLog('downloadBook', `下载失败${JSON.stringify(err)}`,true)
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

  flashDownloadHistoryAndLocalBooksList(){
    zlibClient.localDownloadHistoryArray.clearData()
    setTimeout(()=>{zlibClient.getLocalDownloadHistory()}, 100)
  }
}

export let zlibClient: zlib = new zlib()

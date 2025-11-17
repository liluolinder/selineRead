import { http } from "@kit.NetworkKit";
import { BusinessError } from "@kit.BasicServicesKit";
import { firstDownloadInfo, I_BookDetailedInfo, I_BookInfo } from "../selineRead/models/interfaces/I_BookInfo";
import { user_agent } from "../selineRead/commons/commonItem";
import { CJLoader } from "./CJloader/CJLoader";
import { I_LoginRes } from "./interface/I_loginInfo";
import { I_BasicUserInfo, I_UserDownloadLimitAndDonation, I_ZlibUserInfo } from "./interface/I_ZlibUserInfo";
import { JSON } from "@kit.ArkTS";

let base_url: string = 'https://zh.fra101.ru'
let baseApi_url: string = base_url+'/papi'

export class zlibClient {

  static async login(email: string, password: string):Promise<[number, string]> {
    let req = http.createHttp()
    return await req.request(`${base_url}/rpc.php`, {
      method: http.RequestMethod.GET,
      header: {
        'sec-ch-ua-platform': '"Windows"',
        'user-agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/138.0.0.0 Safari/537.36 Edg/138.0.0.0',
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
        let result:I_LoginRes= JSON.parse((obj as object)?.['result']) as I_LoginRes
        if (result.response.message==undefined || result.response.message==null) {
          let cookie = `siteLanguage=zh; selectedSiteMode=books; remix_userkey=${result.response.user_key}; remix_userid=${result.response.user_id}; redirects_count=%7B%22auth%22%3A1%2C%22hide-auth-params%22%3A1%7D`
          let basicInfo:I_BasicUserInfo  = JSON.parse((await zlibClient.getPersonInfo(cookie))[1]) as I_BasicUserInfo
          let userInfo:I_ZlibUserInfo = {
            account: email,
            password: password,
            cookie: cookie,
            userName: basicInfo.userName,
            userDownloadLimitNumber: basicInfo.userDownloadLimitNumber,
            userDonateNumber: basicInfo.userDonateNumber,
            userAvatar: basicInfo.userAvatar
          }
          return [1,JSON.stringify(userInfo)] as [number,string]
        }else {
          return [0,result.response.message] as [number,string]
        }
      }catch (err) {
        return [0,JSON.stringify(err)] as [number,string]
      }
    })
      .catch((err: BusinessError) => {
        return [0,JSON.stringify(err)] as [number,string]
      }).finally(() => {
        req.destroy()
      });
  }

  static async getPersonInfo(cookie:string):Promise<[number, string]> {
    let req = http.createHttp()
    return await req.request(`${base_url}/?ts`, {
      method: http.RequestMethod.GET,
      header: {
        'sec-ch-ua-platform': '"Windows"',
        'user-agent':user_agent,
        'Cookie': cookie//this.cookie,;
      }
    }).then((data: http.HttpResponse) => {
      try {
        let res:I_UserDownloadLimitAndDonation = JSON.parse( CJLoader.getUserDownloadLimitAndDonation(JSON.stringify(data.result))) as I_UserDownloadLimitAndDonation
        let avatar =  CJLoader.getUserAvatar(JSON.stringify(data.result))
        let userName = CJLoader.getUserName(JSON.stringify(data.result))
        let tempUserInfo:I_BasicUserInfo = {
          userName:userName,
          userDownloadLimitNumber:res.downloadLimit,
          userDonateNumber:res.donation,
          userAvatar:avatar
        }
        return [1,JSON.stringify(tempUserInfo)] as [number,string]
      }catch (err) {
        return [0,JSON.stringify(err)] as [number,string]
      }
    })
      .catch((err: BusinessError) => {
        return [0,JSON.stringify(err)] as [number,string]
      }).finally(() => {
        req.destroy()
      });
  }

  /*
    @Param req http请求体
    @Param page 请求页数>=1, 默认值位1
    @Return 类型为[number, string]元组 元素0表示获取状态（0为失败， 1为成功） string表示消息(成功为序列化后的数据字符串，其余为报错内容)
   */
  static async getRecommendBook(req: http.HttpRequest, page: number = 1):Promise<[number, string]> {
    return await req.request(`${baseApi_url}/book/mostpopular/mosaic/20/${page}`, {
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
        return [1,JSON.stringify(bookArray)] as [number,string]
      }catch (err) {
        return [0,JSON.stringify(err)] as [number,string]
      }
    })
      .catch((err: BusinessError) => {
        return [0,JSON.stringify(err)] as [number,string]
      }).finally(() => {
        req.destroy()
      });
  }

  /*
  @Param req http请求体
  @Param bookHref 书籍详细url/Href
  @Return 类型为[number, string]元组 元素0表示获取状态（0为失败， 1为成功） string表示消息(成功为序列化后的数据字符串，其余为报错内容)
 */
  static async getBookInfo(req: http.HttpRequest,bookHref: string):Promise<[number, string]>{
    return await req.request(`${base_url}${bookHref}`, {
      method: http.RequestMethod.GET,
      header: {
        'sec-ch-ua-platform': '"Windows"',
        'user-agent':user_agent,
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
          return [1,JSON.stringify(resBookInfo)] as [number,string]
        } catch (err) {
          return [0,JSON.stringify(err)] as [number,string]
        }
      }catch (err) {
        return [0,JSON.stringify(err)] as [number,string]
      }
    })
      .catch((err: BusinessError) => {
        return [0,JSON.stringify(err)] as [number,string]
      }).finally(() => {
        req.destroy()
      });
  }

  /*
  @Param req http请求体
  @Param bookID 书籍id
  @Return 类型为[number, string]元组 元素0表示获取状态（0为失败， 1为成功） string表示消息(成功为序列化后的数据字符串，其余为报错内容)
 */
  static async getMoreDownloadWay(req: http.HttpRequest,bookID: number):Promise<[number, string]>{
    console.log(`${baseApi_url}/book/${bookID}/formats`)
    return await req.request(`${baseApi_url}/book/${bookID}/formats`, {
      method: http.RequestMethod.GET,
      header: {
        'sec-ch-ua-platform': '"Windows"',
        'user-agent':user_agent,
      }
    }).then((data: http.HttpResponse) => {
      let obj = JSON.parse(JSON.stringify(data));
      let result = JSON.parse((obj as object)?.['result']);
      console.log(JSON.stringify(result))
      return [1,JSON.stringify((result as object)?.['books'])] as [number,string]
    })
      .catch((err: BusinessError) => {
        return [0,JSON.stringify(err)] as [number,string]
      }).finally(() => {
        req.destroy()
      });
  }

}
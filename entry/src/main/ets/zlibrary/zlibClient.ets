import { http } from "@kit.NetworkKit";
import { BusinessError } from "@kit.BasicServicesKit";
import { XContext } from "commonpackage";
import { I_BookInfo } from "../selineRead/models/interfaces/I_BookInfo";

let base_url: string = 'https://zh.fra101.ru'
let baseApi_url: string = base_url+'/papi'

export class zlibClient {

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
        'user-agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/138.0.0.0 Safari/537.36 Edg/138.0.0.0',
      }
    }).then((data: http.HttpResponse) => {
      try {
        let obj:object = JSON.parse(JSON.stringify(data))
        let result:object = JSON.parse((obj as object)?.['result'])
        let bookArray: I_BookInfo[] = (result as object)?.['books']
        return [1,JSON.stringify(bookArray)] as [number,string]
      }catch (err) {
        return [-1,JSON.stringify(err)] as [number,string]
      }
    })
      .catch((err: BusinessError) => {
        return [-1,JSON.stringify(err)] as [number,string]
      }).finally(() => {
        req.destroy()
      });
  }
}
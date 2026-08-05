import { LFileKit, XContext } from "commonpackage";
import { BookSourceParserArk } from "libohos_app_cangjie_entry.bookSource.so";
import { __BookSource__ } from "../../commons/shareDatas";

export class FileKit{
  static bookSourcePath = `${XContext.getFilesDir()}/bookSource`

  static async checkSourcePath(): Promise<boolean>{
    let flag = await LFileKit.access(FileKit.bookSourcePath)
    return flag
  }

  static async createSourcePath(): Promise<boolean>{
    return await FileKit.checkSourcePath().then(async (res)=>{
      if (res) {
        return true
      }else {
       return await LFileKit.mkdir(FileKit.bookSourcePath).then((res)=>{
          return res
        })
      }
    })
  }

  static getBookSourceParser(){
    FileKit.createSourcePath().then((canAccess)=>{
      if (canAccess) {
        LFileKit.listDir(FileKit.bookSourcePath).then((name)=>{
          name.forEach((item)=>{
            let dir = `${FileKit.bookSourcePath}/${item}`
            LFileKit.read(dir).then((json)=>{
              __BookSource__.parsers.push(new BookSourceParserArk(item, json))
            })
          })
        })
      }
    })
  }

}
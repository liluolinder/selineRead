import { XContext } from "commonpackage"
import { fileIo } from "@kit.CoreFileKit"

export async function deleteDownloadCache(){
  let downloadPath = await XContext.getDownloadFolderPath()
  fileIo.listFileSync(downloadPath).forEach((item) => {
    let textFragment: string[] = item.split('.')
    if (textFragment[textFragment.length-1] == 'sfftdownload') {
      try {
        fileIo.unlinkSync(downloadPath + item)
        console.log('删除废物文件失成功')
      } catch (e) {
        console.log('删除废物文件失败' + JSON.stringify(e))
      }
    }
  })
}
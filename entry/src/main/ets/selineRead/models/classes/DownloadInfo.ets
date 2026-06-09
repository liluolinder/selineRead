import { DownloadTask } from "@hadss/super_fast_file_trans"
import { I_DownloadInfo } from "../interfaces/I_DownloadInfo"
import { http } from "@kit.NetworkKit"
import { DownloadTaskArk } from "libohos_app_cangjie_entry.download.so"

@ObservedV2
export class DownloadInfo implements I_DownloadInfo{
  @Trace fileName:string = ''
  @Trace fileImage:ResourceStr = ''
  @Trace progress:number = 0
  @Trace status:DownloadStatus = DownloadStatus.Idle
  downloadType: "txt" | "other" = 'other'
  bookAuthor :string = ''
  bookHref : string = ''
  downLoadTask?:DownloadTask|http.HttpRequest|DownloadTaskArk
  bookId:number = 0
  downloadTime:string=''

  toInterface():I_DownloadInfo {
    let res:I_DownloadInfo = {
      fileName: this.fileName,
      fileImage: this.fileImage,
      progress: this.progress,
      status: this.status,
      bookAuthor: this.bookAuthor,
      bookHref: this.bookHref,
      downLoadTask: this.downLoadTask,
      bookId: this.bookId,
      downloadType: this.downloadType
    }
    return res
  }

  static fromInterface(data:I_DownloadInfo):DownloadInfo{
    let res:DownloadInfo = new DownloadInfo()
    res.fileName = data.fileName
    res.fileImage = data.fileImage
    res.progress = data.progress
    res.status = data.status
    res.bookAuthor = data.bookAuthor
    res.bookHref = data.bookHref
    res.downLoadTask = data.downLoadTask
    res.bookId = data.bookId
    res.downloadType = data.downloadType
		return res
	}

}

export enum DownloadStatus{
  Idle, Starting, Downloading, Complete, Failed, Cancel
}
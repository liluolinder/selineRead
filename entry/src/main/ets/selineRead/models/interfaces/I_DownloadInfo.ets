import { DownloadTask } from "@hadss/super_fast_file_trans"
import { DownloadStatus } from "../classes/DownloadInfo"
import { http } from "@kit.NetworkKit"
import { DownloadTaskArk } from "libohos_app_cangjie_entry.so"

export interface I_DownloadInfo {
  fileName: string
  fileImage: ResourceStr
  progress: number
  status: DownloadStatus
  downloadType:'txt'|'other'
  bookAuthor: string
  bookHref: string
  downLoadTask?: DownloadTask|http.HttpRequest|DownloadTaskArk
  bookId: number
}
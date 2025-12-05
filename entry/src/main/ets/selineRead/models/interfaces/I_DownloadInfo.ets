import { DownloadTask } from "@hadss/super_fast_file_trans"
import { DownloadStatus } from "../classes/DownloadInfo"

export interface I_DownloadInfo {
  fileName: string
  fileImage: ResourceStr
  progress: number
  status: DownloadStatus
  bookAuthor: string
  bookHref: string
  downLoadTask?: DownloadTask
  bookId: number
}
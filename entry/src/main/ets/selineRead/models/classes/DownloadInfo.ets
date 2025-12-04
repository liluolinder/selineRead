import { DownloadTask } from "@hadss/super_fast_file_trans"

@ObservedV2
export class DownloadInfo{
  @Trace fileName:string = ''
  @Trace fileImage:ResourceStr = ''
  @Trace progress:number = 0
  @Trace status:DownloadStatus = DownloadStatus.Idle
  bookAuthor :string = ''
  bookHref : string = ''
  downLoadTask?:DownloadTask
  bookId:number = 0

}

export enum DownloadStatus{
  Idle, Starting, Downloading, Complete, Failed, Cancel
}
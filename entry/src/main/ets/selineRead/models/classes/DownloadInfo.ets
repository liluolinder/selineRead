import { DownloadTask } from "@hadss/super_fast_file_trans"

@ObservedV2
export class DownloadInfo{
  @Trace fileName:string = ''
  @Trace fileImage:ResourceStr = ''

  @Trace progress:number = 0

  @Trace status:DownloadStatus = DownloadStatus.Idle
  downLoadTask?:DownloadTask

}

export enum DownloadStatus{
  Idle, Downloading, Pause,Complete,Error
}
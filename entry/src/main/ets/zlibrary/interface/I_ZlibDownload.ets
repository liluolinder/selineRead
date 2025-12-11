export interface I_ZlibDownloadRes{
  success:number
  file:I_ZlibDownloadRes_file
  error:string
}

export interface I_ZlibDownloadRes_file{
  downloadLink: string
  description: string
  author: string
  extension:string
  allowDownload: boolean
}
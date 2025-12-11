export interface I_ZlibBookInfoRes{
  success:number
  book:I_ZlibBookInfoRes_Book
  error:string
}

export interface I_ZlibSearchRes{
  success:number
  books:I_ZlibBookInfoRes_Book[]
  error:string
}


export interface I_ZlibBookInfoRes_Book{
  id: number
  content_type: string
  title: string
  author: string
  volume: string
  year: number
  edition: string
  publisher: string
  identifier: string
  language: string
  pages: number
  series: string
  cover: string
  terms_hash: string
  active:number
  deleted:number
  filesize:number
  filesizeString: string
  extension:string
  md5: string
  sha256: string
  href: string
  hash:string
  kindleAvailable: boolean
  sendToEmailAvailable: boolean
  interestScore: string
  qualityScore:string
  description: string
  dl: string
  readOnlineUrl:string
  _isUserSavedBook: boolean
  readOnlineAvailable:boolean
}
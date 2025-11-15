export interface I_BookInfo{
  id: number
  isbn: string
  url: string
  title: string
  author: string
  cover: string
  coverData: string
  bookID?:string
  isReady?:boolean
}
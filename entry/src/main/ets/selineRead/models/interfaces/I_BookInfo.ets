export interface I_BookInfo{
  id: number
  isbn: string
  url: string
  title: string
  author: string
  cover: string
  coverData: string
  bookID?:string
}

export interface I_BookDetailedInfo{
  name:string
  description:string
  author:authorInfo[]
  publisher:publisherInfo
  image:string
  isbn:string
  numberOfPages:number
  datePublished?:number
  inLanguage:inLanguageInfo
  review:reviewInfo
  bookID?:number
  firstDownloadUrl?:string
  firstDownloadInfo?:firstDownloadInfo
  terms?:I_Terms[]
  href?:string
  readUrl?:string
  bookIDsRelated?:number[]
}

export interface authorInfo{
  name:string
  url:string
}

export interface publisherInfo {
  name:string
}

export interface inLanguageInfo {
  name:string
}

export interface reviewInfo {
  reviewBody:string
  datePublished:string
  reviewRating:reviewRatingInfo
}

export interface reviewRatingInfo{
  ratingValue:string
}

export interface firstDownloadInfo{
  format:string
  size:string
}

export interface I_Terms{
  term:string
  href:string
}
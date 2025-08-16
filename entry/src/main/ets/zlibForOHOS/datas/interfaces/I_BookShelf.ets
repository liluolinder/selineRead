/*
Copyright (c) 2025 琉离铟落linder
SelineRead is licensed under Mulan PSL v2.
You can use this software according to the terms and conditions of the Mulan
PSL v2.
You may obtain a copy of Mulan PSL v2 at:
         http://license.coscl.org.cn/MulanPSL2
THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY
KIND, EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO
NON-INFRINGEMENT, MERCHANTABILITY OR FIT FOR A PARTICULAR PURPOSE.
See the Mulan PSL v2 for more details.

Mulan Permissive Software License，Version 2

Mulan Permissive Software License，Version 2 (Mulan PSL v2)

January 2020 http://license.coscl.org.cn/MulanPSL2
 */


export interface I_Bookshelf
{
  success:number
  readlists:I_ReadLists_Bookshelf[]
  readlistsOwners:object
  booksGrouped:object
  favoriteReadlists:object[]
  nextPage:number
}

export interface I_ReadListsOwners_Bookshelf{
  id: number
  avatar: string
  name: string
  link: string
}

export interface I_ReadLists_Bookshelf{
  id: number
  user_id: number
  title: string
  description:string
  languages: string
  public: number
  adult: number
  editors_choice: number
  views_count: number
  books_count: number
  favorites_count: number
  comments_count: number
  color: number
  date_updated: I_Date_Bookshelf
  date:I_Date_Bookshelf
  link: number

  readListsOwners?:I_ReadListsOwners_Bookshelf
  booksGrouped?:I_BookInfo_Bookshelf[]

}

export interface I_Date_Bookshelf
{
  date: string
  timezone_type: number
  timezone: string
}

export interface I_BookInfo_Bookshelf
{
  id: number
  title: string
  author: string
  cover:string
  storage: string
  identifier: string
  language: string
  link:string
  coverUrl:string
}


export interface I_Bookshelf_extraInfo{
  success:number,
  books:I_Bookshelf_extraBooks[]
  pagination:I_Bookshelf_pagination
}

export interface I_Bookshelf_extraBooks{
  id: number,
  readlist_id: number,
  book_id: number,
  description: string,
  deleted: number,
  book: I_Bookshelf_extraBooksInfo
}

export interface I_Bookshelf_extraBooksInfo{
  id: number,
  content_type:string,
  title: string,
  author: string,
  volume: string,
  year: number,
  edition: string,
  publisher: string,
  identifier: string,
  language: string,
  pages: number,
  series: string,
  cover: string,
  terms_hash: string,
  active: number,
  deleted: number,
  filesize: number,
  filesizeString: string,
  extension: string,
  md5: string,
  sha256: string,
  href: string,
  hash: string,
  kindleAvailable: boolean,
  sendToEmailAvailable: boolean,
  interestScore: string,
  qualityScore: string,
  description:string,
  isbn: string,
  _isUserSavedBook: boolean
}

export interface I_Bookshelf_pagination {
  limit: number,
  current: number,
  before: number,
  next: number,
  total_items: number,
  total_pages: number,
  baseUrl: string
}
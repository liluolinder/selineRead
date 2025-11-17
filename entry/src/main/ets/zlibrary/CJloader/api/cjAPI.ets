export interface CJLib {
  testCJ(src: string): string
  getBookInfo(src: string): string
  getSearchBookArray(src: string): string
  getBookFirstDownloadUrl(src: string): string
  getBookFirstDownloadInfo(src: string): string
  getUserDownloadLimitAndDonation(src: string): string
  getUserAvatar(src: string): string
  getUserName(src: string): string
  getReadUrl(src: string): string
  getTerms(src: string): string
  getSearchTermsArray(src: string): string
  getBookShelfIsLoved(src: string): boolean
}
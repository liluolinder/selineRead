export declare class webdavArk {
    start(): void
    stop(): void
}

export declare class RuleContentArk {
    url: string
    content: string
    nextUrl: string
    filters: Array<string>
    token: TokenConfigArk | undefined
}

export declare class TokenConfigArk {
    algo: string
    key: string
    iv: string
    input: string
    bookIdFrom: string
}

export declare class RuleTocArk {
    url: string
    chapterList: string
    chapterName: string
    chapterUrl: string
    nextTocUrl: string
}

export declare class RuleBookInfoArk {
    url: string
    name: string
    author: string
    coverUrl: string
    intro: string
    kind: string
    wordCount: string
    latestChapter: string
    status: string
}

export declare class RuleSearchArk {
    searchUrl: string
    method: string
    postBody: string
    bookList: string
    name: string
    author: string
    bookUrl: string
    bookUrlTemplate: string
    coverUrl: string
    intro: string
    kind: string
    wordCount: string
    latestChapter: string
}

export declare class ChapterArk {
    index: number
    name: string
    url: string
    sourceUrl: string
    getContent(returnFunc: (funcArg0: string) => void, errorFunc: (funcArg0: string) => void): void
}

export declare class BookSourceArk {
    bookSourceUrl: string
    bookSourceName: string
    bookSourceGroup: string
    bookSourceComment: string
    bookSourceType: number
    enabled: boolean
    header: string
    ruleSearch: RuleSearchArk | undefined
    ruleBookInfo: RuleBookInfoArk | undefined
    ruleToc: RuleTocArk | undefined
    ruleContent: RuleContentArk | undefined
}

export declare class BookSourceParserArk {
    fileName: string
    bookSource: BookSourceArk
    supportsPage: boolean
    search(keyWord: string, page: string | undefined, returnFunc: (funcArg0: Array<BookArk>) => void, errorFunc: (funcArg0: string) => void): void
}

export declare class BookArk {
    bookUrl: string
    name: string
    author: string
    coverUrl: string
    intro: string
    kind: string
    wordCount: string
    latestChapter: string
    sourceUrl: string
    getToc(returnFunc: (funcArg0: Array<ChapterArk>) => void, errorFunc: (funcArg0: string) => void): void
    getBookInfo(returnFunc: (funcArg0: BookArk) => void, errorFunc: (funcArg0: string) => void): void
}

export declare class PaginationArk {
    limit: number
    current: number
    totalItems: number
    totalPages: number
}

export declare class ZlibUserInfoArk {
    id: number
    email: string
    name: string
    kindleEmail: string
    remixUserKey: string
    todayDownloadNum: number
    downloadLimit: number
    cookie: string
    getSavedBook(page: number, returnFunc: (funcArg0: Array<ZlibBookInfoArk>, funcArg1: PaginationArk) => void, errorFunc: (funcArg0: string) => void): void
    getRecommendBook(returnFunc: (funcArg0: Array<ZlibBookInfoBriefArk>) => void, errorFunc: (funcArg0: string) => void): void
}

export declare class ZlibClientArk {
    checkAccess(autoRedirect: boolean, returnFunc: (funcArg0: boolean) => void, errorFunc: (funcArg0: string) => void): void
    checkAccessByAddress(address: string, autoRedirect: boolean, returnFunc: (funcArg0: boolean, funcArg1: string) => void, errorFunc: (funcArg0: string) => void): void
    getRecommendBook(returnFunc: (funcArg0: Array<ZlibBookInfoBriefArk>) => void, errorFunc: (funcArg0: string) => void): void
    login(email: string, password: string, returnFunc: (funcArg0: ZlibUserInfoArk) => void, errorFunc: (funcArg0: string) => void): void
    search(bookName: string, page: number, returnFunc: (funcArg0: Array<ZlibBookInfoBriefArk>) => void, errorFunc: (funcArg0: string) => void): void
    getZlibUrl(returnFunc: (funcArg0: string) => void): void
    setZlibUrl(url: string): void
}

export declare class ZlibBookInfoBriefArk {
    id: number
    title: string
    author: string
    cover: string
    hash: string
    toCJ(): void
    getDetailInfo(cookie: string, returnFunc: (funcArg0: ZlibBookInfoArk) => void, errorFunc: (funcArg0: string) => void): void
}

export declare class ZlibBookInfoArk {
    id: number
    contentType: string
    title: string
    author: string | undefined
    volume: string
    year: number
    edition: string | undefined
    publisher: string | undefined
    identifier: string | undefined
    language: string
    pages: number
    series: string
    cover: string
    termsHash: string
    active: number
    deleted: number
    filesize: number
    filesizeString: string
    extension: string
    md5: string
    sha256: string
    href: string
    hash: string
    kindleAvailable: boolean
    sendToEmailAvailable: boolean
    interestScore: string
    qualityScore: string
    description: string
    dl: string
    readOnlineUrl: string | undefined
    isUserSavedBook: boolean | undefined
    dataSaved: string | undefined
    readOnlineAvailable: boolean
    getDownloadInfo(cookie: string, returnFunc: (funcArg0: string) => void, errorFunc: (funcArg0: string) => void): void
    saveBook(cookie: string, returnFunc: (funcArg0: boolean) => void, errorFunc: (funcArg0: string) => void): void
    unSaveBook(cookie: string, returnFunc: (funcArg0: boolean) => void, errorFunc: (funcArg0: string) => void): void
    send2QQGroup(cookie: string, qqNumber: string, qqGroup: string, returnFunc: (funcArg0: string) => void, errorFunc: (funcArg0: string) => void): void
    getSimilarBook(returnFunc: (funcArg0: Array<ZlibBookInfoBriefArk>) => void, errorFunc: (funcArg0: string) => void): void
}

export declare class DownloadTaskArk {
    setStartCallback(event: () => void): DownloadTaskArk
    setProgressCallback(event: (funcArg0: number, funcArg1: number, funcArg2: string) => void): DownloadTaskArk
    setRetryCallback(event: (funcArg0: number, funcArg1: number) => void): DownloadTaskArk
    setErrorCallback(event: (funcArg0: string) => void): DownloadTaskArk
    setPauseCallback(event: () => void): DownloadTaskArk
    setCompleteCallback(event: () => void): DownloadTaskArk
    start(): void
    cancel(): void
}

export declare class DownloadManageArk {
    createTask(taskID: string, downloadUrl: string, fileName: string, returnFunc: (funcArg0: DownloadTaskArk) => void, errorFunc: (funcArg0: string) => void): void
}

export declare class QQbot {
    getBotQQGroup(): void
    getCommonGroup(qqNum: string, returnFunc: (funcArg0: Array<QQGroupInfoArk>) => void, errorFunc: (funcArg0: string) => void): void
    getConfig(returnFunc: (funcArg0: BotConfig) => void, errorFunc: (funcArg0: string) => void): void
}

export declare class QQGroupInfoArk {
    id: string
    name: string
}

export declare class BotConfig {
    canPush2QQ: boolean
    status: string
    message: string | undefined
}

export declare interface CustomLib {
    BotConfig: {new (): BotConfig}
    QQGroupInfoArk: {new (): QQGroupInfoArk}
    QQbot: {new (): QQbot}
    DownloadManageArk: {new (downloadPath: string): DownloadManageArk}
    DownloadTaskArk: {new (): DownloadTaskArk}
    ZlibBookInfoArk: {new (): ZlibBookInfoArk}
    ZlibBookInfoBriefArk: {new (id: number, hash: string): ZlibBookInfoBriefArk}
    ZlibClientArk: {new (): ZlibClientArk}
    ZlibUserInfoArk: {new (): ZlibUserInfoArk}
    PaginationArk: {new (): PaginationArk}
    BookArk: {new (): BookArk}
    BookSourceParserArk: {new (_fileName: string, bookSourceJson: string): BookSourceParserArk}
    BookSourceArk: {new (): BookSourceArk}
    ChapterArk: {new (): ChapterArk}
    RuleSearchArk: {new (): RuleSearchArk}
    RuleBookInfoArk: {new (): RuleBookInfoArk}
    RuleTocArk: {new (): RuleTocArk}
    TokenConfigArk: {new (): TokenConfigArk}
    RuleContentArk: {new (): RuleContentArk}
    webdavArk: {new (rootPath: string, port: number, account: string, password: string): webdavArk}
}
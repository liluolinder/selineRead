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

export declare class webdavArk {
    start(): void
    stop(): void
}

export declare interface CustomLib {
    webdavArk: { new (rootPath: string, port: number, account: string, password: string): webdavArk }
    DownloadManageArk: { new (downloadPath: string): DownloadManageArk }
    DownloadTaskArk: { new (): DownloadTaskArk }
    ZlibBookInfoArk: { new (): ZlibBookInfoArk }
    ZlibBookInfoBriefArk: { new (): ZlibBookInfoBriefArk }
    ZlibBookInfoBriefArk: { new (id: number, hash: string): ZlibBookInfoBriefArk }
    ZlibClientArk: { new (): ZlibClientArk }
    ZlibUserInfoArk: { new (): ZlibUserInfoArk }
    PaginationArk: { new (): PaginationArk }
}

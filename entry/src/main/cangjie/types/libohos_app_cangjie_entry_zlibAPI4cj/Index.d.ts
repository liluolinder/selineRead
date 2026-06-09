
export declare class ZlibUserInfoArk {
    id: number
    email: string
    name: string
    kindleEmail: string
    remixUserKey: string
    todayDownloadNum: number
    downloadLimit: number
    cookie: string
    constructor()
}

export declare class ZlibClientArk {
    checkAccess(autoRedirect: boolean, returnFunc: (funcArg0: boolean) => void, errorFunc: (funcArg0: string) => void): void
    getRecommendBook(returnFunc: (funcArg0: Array<ZlibBookInfoBriefArk>) => void, errorFunc: (funcArg0: string) => void): void
    login(email: string, password: string, returnFunc: (funcArg0: ZlibUserInfoArk) => void, errorFunc: (funcArg0: string) => void): void
    search(bookName: string, page: number, returnFunc: (funcArg0: Array<ZlibBookInfoBriefArk>) => void, errorFunc: (funcArg0: string) => void): void
    getZlibUrl(returnFunc: (funcArg0: string) => void): void
    setZlibUrl(url: string): void
    constructor()
}

export declare class ZlibBookInfoBriefArk {
    id: number
    title: string
    author: string
    cover: string
    hash: string
    getDetailInfo(cookie: string, returnFunc: (funcArg0: ZlibBookInfoArk) => void, errorFunc: (funcArg0: string) => void): void
    constructor()
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
    readOnlineUrl: string
    isUserSavedBook: boolean | undefined
    dataSaved: string | undefined
    readOnlineAvailable: boolean
    getDownloadInfo(cookie: string, returnFunc: (funcArg0: string) => void, errorFunc: (funcArg0: string) => void): void
    constructor()
}

export declare class RuleContentArk {
    url: string
    content: string
    nextUrl: string
    filters: Array<string>
    token: TokenConfigArk | undefined
    constructor ()
}

export declare class TokenConfigArk {
    algo: string
    key: string
    iv: string
    input: string
    bookIdFrom: string
    constructor ()
}

export declare class RuleTocArk {
    url: string
    chapterList: string
    chapterName: string
    chapterUrl: string
    nextTocUrl: string
    constructor ()
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
    constructor ()
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
    constructor ()
}

export declare class ChapterArk {
    index: number
    name: string
    url: string
    sourceUrl: string
    getContent(returnFunc: (funcArg0: string) => void, errorFunc: (funcArg0: string) => void): void
    constructor ()
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
    constructor ()
}

export declare class BookSourceParserArk {
    fileName: string
    bookSource: BookSourceArk
    supportsPage: boolean
    search(keyWord: string, page: string | undefined, returnFunc: (funcArg0: Array<BookArk>) => void, errorFunc: (funcArg0: string) => void): void
    constructor (_fileName: string, bookSourceJson: string)
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
    constructor ()
}


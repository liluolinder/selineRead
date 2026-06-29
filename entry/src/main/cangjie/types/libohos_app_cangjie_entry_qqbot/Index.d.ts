export declare class QQbot {
    getBotQQGroup(): void
    getCommonGroup(qqNum: string, returnFunc: (funcArg0: Array<QQGroupInfoArk>) => void, errorFunc: (funcArg0: string) => void): void
    constructor ()
}

export declare class QQGroupInfoArk {
    id: string
    name: string
    constructor ()
}


export declare class QQbot {
    changeUrl(newUrl: string): void
    getBotQQGroup(): void
    getCommonGroup(qqNum: string, returnFunc: (funcArg0: Array<QQGroupInfoArk>) => void, errorFunc: (funcArg0: string) => void): void
    getConfig(returnFunc: (funcArg0: BotConfig) => void, errorFunc: (funcArg0: string) => void): void
    constructor ()
}

export declare class QQGroupInfoArk {
    id: string
    name: string
    constructor ()
}

export declare class BotConfig {
    canPush2QQ: boolean
    constructor ()
}


export declare class DownloadTaskArk {
    setStartCallback(event: () => void): DownloadTaskArk
    setProgressCallback(event: (funcArg0: number, funcArg1: number, funcArg2: string) => void): DownloadTaskArk
    setRetryCallback(event: (funcArg0: number, funcArg1: number) => void): DownloadTaskArk
    setErrorCallback(event: (funcArg0: string) => void): DownloadTaskArk
    setPauseCallback(event: () => void): DownloadTaskArk
    setCompleteCallback(event: () => void): DownloadTaskArk
    start(): void
    cancel(): void
    constructor ()
}

export declare class DownloadManageArk {
    createTask(taskID: string, downloadUrl: string, fileName: string, returnFunc: (funcArg0: DownloadTaskArk) => void, errorFunc: (funcArg0: string) => void): void
    constructor (downloadPath: string)
}


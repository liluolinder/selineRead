/**
 * Created on 2026/3/11
 */
package ohos_app_cangjie_entry.download

import ohos.ark_interop.*
import ohos.ark_interop_macro.*
import selineDownload.DownloadTask

@Interop[ArkTS]
public class DownloadTaskArk {
    private var task: Option<DownloadTask> = None

    @Interop[ArkTS, Invisible]
    public func setTask(newTask: DownloadTask): Unit {
        task = newTask
    }

    public func setStartCallback(event: () -> Unit): DownloadTaskArk {
        if (let Some(Context) <- globalcontext) {
            if (let Some(_task) <- task) {
                _task.setStartCallback {
                    Context.postJSTask {
                        event()
                    }
                }
            }
        }
        this
    }

    public func setProgressCallback(event: (Int64,Int64,String) -> Unit):DownloadTaskArk{
         if (let Some(Context) <- globalcontext) {
            if (let Some(_task) <- task) {
                _task.setProgressCallback {
                    progress =>
                    Context.postJSTask {
                        event(progress.downloadedBytes, progress.totalBytes, progress.formattedSpeed)
                    }
                }
            }
        }
        this
    }

    public func setRetryCallback(event: (Int64, Int64) -> Unit): DownloadTaskArk {
        if (let Some(Context) <- globalcontext) {
            if (let Some(_task) <- task) {
                _task.setRetryCallback {
                    retryNum, totalNum => Context.postJSTask {
                        event(retryNum, totalNum)
                    }
                }
            }
        }
        this
    }

    public func setErrorCallback(event: (String) -> Unit): DownloadTaskArk {
        if (let Some(Context) <- globalcontext) {
            if (let Some(_task) <- task) {
                _task.setErrorCallback {
                    error => Context.postJSTask {
                        event(error.toString())
                    }
                }
            }
        }
        this
    }

    public func setPauseCallback(event: () -> Unit): DownloadTaskArk {
        if (let Some(Context) <- globalcontext) {
            if (let Some(_task) <- task) {
                _task.setPauseCallback {
                    Context.postJSTask {
                        event()
                    }
                }
            }
        }
        this
    }

    public func setCompleteCallback(event: () -> Unit): DownloadTaskArk {
        if (let Some(Context) <- globalcontext) {
            if (let Some(_task) <- task) {
                _task.setCompleteCallback {
                    Context.postJSTask {
                        event()
                    }
                }
            }
        }
        this
    }

    public func start(): Unit {
        if (let Some(_task) <- task) {
            _task.start()
        }
    }

    public func cancel(): Unit {
        if (let Some(_task) <- task) {
            _task.cancel()
        }
    }

    public DownloadTaskArk() {}
}

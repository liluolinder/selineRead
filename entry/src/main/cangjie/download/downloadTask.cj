/**
 * Created on 2026/3/11
 */
package ohos_app_cangjie_entry.download

import ohos.ark_interop_advance.*
import ohos.ark_interop_macro.*
import selineDownload.DownloadTask
import ohos_app_cangjie_entry.run2JS

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
                    run2JS {
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
                    run2JS {
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
                    retryNum, totalNum => run2JS {
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
                    error => run2JS {
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
                    run2JS {
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
                    run2JS {
                        event()
                    }
                }
            }
        }
        this
    }

    public func start(): Unit {
        if (let Some(_task) <- task) {
            spawn {
            	_task.start()
            }
        }
    }

    public func cancel(): Unit {
        if (let Some(_task) <- task) {
            spawn {
            	_task.cancel()
            }
        }
    }

    public DownloadTaskArk() {}
}

/**
 * Created on 2026/3/11
 */
package ohos_app_cangjie_entry.download

import ohos.ark_interop.*
import ohos.ark_interop_macro.*
import selineDownload.DownloadManager
import selineDownload.DownloadConfig
import selineDownload.DownloadTask

var globalcontext: Option<JSContext> = None

let _ = JSModule.registerModule {context, _ => globalcontext = context}

@Interop[ArkTS]
public class DownloadManageArk {
    let downloadManage = DownloadManager()

    public func createTask(taskID: String, downloadUrl: String, fileName: String, returnFunc: (DownloadTaskArk) -> Unit,
        errorFunc: (String) -> Unit): Unit {
        if (let Some(context) <- globalcontext) {
            spawn {
                try {
                    let config = DownloadConfig()
                        .setUrl(downloadUrl)
                        .setReadTimeout(Duration.hour)
                        .setSavePath(downloadPath + fileName)
                    let task = downloadManage.createTask(taskID, config)
                    let resTask = DownloadTaskArk()
                    resTask.setTask(task)
                    context.postJSTask{
                        returnFunc(resTask)
                    }
                } catch (eror: Exception) {
                    context.postJSTask{
                        errorFunc("错误:${eror.toString()}")
                    }
                }
            }
        }
    }



    public DownloadManageArk(public var downloadPath: String) {}
}

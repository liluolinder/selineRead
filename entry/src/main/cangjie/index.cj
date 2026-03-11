package ohos_app_cangjie_entry

import ohos.ark_interop.JSContext
import ohos.ark_interop.JSModule
import ohos.ark_interop_macro.*
import ohos.ark_interop.*
import ohos.hilog.Hilog
import selineWebdav.startWebDavWithAuth
import selineDownload.DownloadConfig
import selineDownload.DownloadTask
import stdx.log.LogLevel
import stdx.logger.SimpleLogger
import std.env.getStdOut
import stdx.log.setGlobalLogger
import stdx.encoding.url.URL

var globalcontext: Option<JSContext> = None

let _ = JSModule.registerModule {context, _ => globalcontext = context}

@Interop[ArkTS]
public func startWevDav(path: String): Unit {
    spawn {
        startWebDavWithAuth(path, "admin", "admin123", port: 8088, host: '127.0.0.1')
    }
}

//@Interop[ArkTS]
//public func download(downloadUrl: String, downloadPath: String, fileName: String): Unit {
//    //解码URL暂时放在Ark出后续移过来
//    spawn {
//        let config = DownloadConfig()
//            .setUrl(downloadUrl)
//            .setSavePath(downloadPath + fileName)
//            .setMaxRetries(1)
//            .setReadTimeout(Duration.day)
//            .setWriteTimeout(Duration.day)
//
//        // 创建下载任务
//        let task = DownloadTask(config)
//
//        // 设置进度回调
//        task.setProgressCallback({
//            progress => Hilog.info(123, 'download',
//                "📊 下载进度: ${progress.progress}%，已下载${progress.downloadedBytes},共${progress.totalBytes}，下载速度${progress.formattedSpeed}")
//        })
//
//        // 设置错误回调
//        task.setErrorCallback({
//            e => Hilog.info(123, 'download', "❌ 下载失败: ${e.message}")
//        })
//
//        task.setRetryCallback({
//            _, _ => Hilog.info(114514, 'meow', '发起重试！')
//        })
//
//        // 开始下载
//        task.start()
//        task.await()
//    }
//}

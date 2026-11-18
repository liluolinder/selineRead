@NonProduct
features {}
package ohos_app_cangjie_entry.viewmodel

internal import ohos.state_manage.ObservedObject
internal import ohos.state_manage.ObservedProperty
internal import ohos.state_manage.ObservedComplexAbstract
import ohos.state_macro_manage.Observed
import ohos.state_macro_manage.Publish
import std.collection.ArrayList
import ohos_app_cangjie_entry.model.*

// ---------------------------------------------------------------------------
// 下载：本地已下载文件记录（元数据由 SelineSettings 持久化）。
// ---------------------------------------------------------------------------

@Observed
public class DownloadsViewModel {
    public var owner: ?SelineViewModel = None

    @Publish
    public var downloadsRev: Int64 = 0
    @Publish
    public var downloads: ArrayList<LocalDownload> = ArrayList<LocalDownload>()

    public func reload(): Unit {
        this.downloads = SelineSettings.downloads()
        this.downloadsRev += 1
    }

    public func clearDownloads(): Unit {
        SelineSettings.clearDownloads()
        this.downloads = ArrayList<LocalDownload>()
        this.downloadsRev += 1
        toast("下载记录已清空（文件仍保留在应用目录）")
    }
}

@NonProduct
features {}
package ohos_app_cangjie_entry.viewmodel

internal import ohos.state_manage.ObservedObject
internal import ohos.state_manage.ObservedProperty
internal import ohos.state_manage.ObservedComplexAbstract
import ohos.state_macro_manage.Observed
import ohos.state_macro_manage.Publish
import ohos.concurrency.launch
import zlibraryAPI4CJ.*
import ohos_app_cangjie_entry.model.*

// ---------------------------------------------------------------------------
// 图书详情：元数据加载、收藏切换、下载。
// ---------------------------------------------------------------------------

@Observed
public class DetailViewModel {
    public var owner: ?SelineViewModel = None

    @Publish
    public var detailTitle: String = ""
    @Publish
    public var detailAuthor: String = ""
    @Publish
    public var detailCover: String = ""
    @Publish
    public var detailMeta: String = ""
    @Publish
    public var detailDescription: String = ""
    @Publish
    public var detailSaved: Bool = false
    @Publish
    public var detailBusy: Bool = false
    @Publish
    public var detailLoading: Bool = true
    @Publish
    public var detailError: String = ""
    @Publish
    public var detailId: Int64 = 0
    @Publish
    public var detailHash: String = ""

    public var onOpenDetail: (Int64, String) -> Unit = {_, _ => ()}

    private func shell(): SelineViewModel {
        match (this.owner) {
            case Some(value) => value
            case None => throw Exception("DetailViewModel is not attached to SelineViewModel")
        }
    }

    public func openDetail(id: Int64, hash: String): Unit {
        this.detailId = id
        this.detailHash = hash
        this.detailTitle = ""
        this.detailAuthor = ""
        this.detailCover = ""
        this.detailMeta = ""
        this.detailDescription = ""
        this.detailSaved = false
        this.detailError = ""
        this.detailLoading = true
        this.shell().showDetail = true
        this.onOpenDetail(id, hash)
        spawn {
            => try {
                let book = ZlibService.bookInfo(id, hash)
                let title = book.title
                let author = book.authorText()
                let cover = book.cover
                let meta = "${book.year} · ${book.language} · ${book.extension} · ${book.sizeText()} · ${book.pages} 页"
                let description = book.description
                let saved = book.saved()
                launch(
                    {
                        =>
                            this.detailTitle = title
                            this.detailAuthor = author
                            this.detailCover = cover
                            this.detailMeta = meta
                            this.detailDescription = description
                            this.detailSaved = saved
                            this.detailLoading = false
                    }
                )
            } catch (err: ZlibError) {
                let text = formatZlibError(err)
                launch(
                    {
                        =>
                            this.detailError = text
                            this.detailLoading = false
                    }
                )
            } catch (err: Exception) {
                let text = err.message
                launch(
                    {
                        =>
                            this.detailError = text
                            this.detailLoading = false
                    }
                )
            }
        }
    }

    public func toggleSave(): Unit {
        if (!this.shell().loggedIn) {
            this.shell().switchTab(4)
            toast("请先到「设置」页登录")
            return
        }
        if (this.detailBusy) {
            return
        }
        let wasSaved = this.detailSaved
        this.detailBusy = true
        spawn {
            => try {
                let next = ZlibService.toggleSaved(this.detailId, wasSaved)
                launch(
                    {
                        =>
                            this.detailSaved = next
                            this.detailBusy = false
                            this.shell().saved.invalidate()
                            toast(
                                if (next) {
                                    "已加入收藏"
                                } else {
                                    "已取消收藏"
                                }
                            )
                    }
                )
            } catch (err: ZlibError) {
                let text = formatZlibError(err)
                launch(
                    {
                        =>
                            this.detailBusy = false
                            toast(text)
                    }
                )
            } catch (err: Exception) {
                let text = err.message
                launch(
                    {
                        =>
                            this.detailBusy = false
                            toast(text)
                    }
                )
            }
        }
    }

    public func downloadBook(): Unit {
        if (!this.shell().loggedIn) {
            this.shell().switchTab(4)
            toast("请先到「设置」页登录")
            return
        }
        if (this.detailBusy) {
            return
        }
        this.detailBusy = true
        spawn {
            => try {
                let book = ZlibService.bookInfo(this.detailId, this.detailHash)
                let item = ZlibService.download(book)
                let fileName = item.fileName
                launch(
                    {
                        =>
                            this.detailBusy = false
                            this.shell().downloads.reload()
                            toast("已下载：${fileName}")
                    }
                )
            } catch (err: ZlibError) {
                let text = formatZlibError(err)
                launch(
                    {
                        =>
                            this.detailBusy = false
                            toast(text)
                    }
                )
            } catch (err: Exception) {
                let text = err.message
                launch(
                    {
                        =>
                            this.detailBusy = false
                            toast(text)
                    }
                )
            }
        }
    }
}

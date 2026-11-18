@NonProduct
features {}
package ohos_app_cangjie_entry.viewmodel

internal import ohos.state_manage.ObservedObject
internal import ohos.state_manage.ObservedProperty
internal import ohos.state_manage.ObservedComplexAbstract
import ohos.base.AppLog
import ohos.state_macro_manage.Observed
import ohos.state_macro_manage.Publish
import ohos.concurrency.launch
import std.collection.ArrayList
import zlibraryAPI4CJ.*
import ohos_app_cangjie_entry.model.*

// ---------------------------------------------------------------------------
// 首页：推荐列表 + 搜索结果 + 瀑布流/列表切换。
// ---------------------------------------------------------------------------

@Observed
public class HomeViewModel {
    public var owner: ?SelineViewModel = None

    @Publish
    public var waterfall: Bool = true
    @Publish
    public var columns: Int64 = 2
    @Publish
    public var recLoading: Bool = false
    @Publish
    public var recError: String = ""
    @Publish
    public var recRev: Int64 = 0
    @Publish
    public var recBooks: ArrayList<BookInfoBrief> = ArrayList<BookInfoBrief>()
    @Publish
    public var recLoaded: Bool = false

    @Publish
    public var searchMode: Bool = false
    @Publish
    public var query: String = ""
    @Publish
    public var order: String = "relevance"
    @Publish
    public var loading: Bool = false
    @Publish
    public var loadingMore: Bool = false
    @Publish
    public var error: String = ""
    @Publish
    public var total: Int64 = 0
    @Publish
    public var page: Int64 = 0
    @Publish
    public var more: Bool = false
    @Publish
    public var booksRev: Int64 = 0
    @Publish
    public var books: ArrayList<BookInfo> = ArrayList<BookInfo>()

    private func shell(): SelineViewModel {
        match (this.owner) {
            case Some(value) => value
            case None => throw Exception("HomeViewModel is not attached to SelineViewModel")
        }
    }

    /// Skeleton placeholders only while the active list is loading and empty.
    public func skeletonItems(): Array<Int64> {
        if (this.searchMode) {
            if (this.loading && this.books.size == 0) {
                return [0, 1, 2, 3, 4, 5]
            }
            return []
        }
        if (this.recLoading && this.recBooks.size == 0) {
            return [0, 1, 2, 3, 4, 5]
        }
        []
    }

    public func lanes(): Int32 {
        if (this.waterfall) {
            Int32(this.columns)
        } else {
            1
        }
    }

    public func updateContentWidth(width: Float64): Unit {
        let raw = Int64(width / 220.0)
        let next = if (raw < 2) {
            2
        } else if (raw > 4) {
            4
        } else {
            raw
        }
        if (this.columns != next) {
            this.columns = next
        }
    }

    public func waterfallTemplate(): String {
        var template = ""
        var index: Int64 = 0
        while (index < this.columns) {
            if (index > 0) {
                template += " "
            }
            template += "1fr"
            index += 1
        }
        template
    }

    public func coverUrl(raw: String): String {
        if (raw.size == 0 || raw.contains("cover-not-exists")) {
            return ""
        }
        if (raw.startsWith("//")) {
            return "https:" + raw
        }
        if (raw.startsWith("/")) {
            return ZlibService.currentSite() + raw
        }
        raw
    }

    public func clearSearch(): Unit {
        this.searchMode = false
        this.query = ""
        this.books = ArrayList<BookInfo>()
        this.booksRev += 1
        this.error = ""
        this.loading = false
        this.loadingMore = false
    }

    public func setOrder(value: String): Unit {
        this.order = value
        SelineSettings.setSearchOrder(value)
    }

    public func loadRecommendations(force: Bool): Unit {
        AppLog.info("VM loadRecommendations force=${force} loading=${this.recLoading}")
        if (this.recLoading || (this.recLoaded && !force)) {
            return
        }
        this.recLoading = true
        this.recError = ""
        spawn {
            => try {
                let items = ZlibService.mostPopular()
                launch(
                    {
                        =>
                            this.recBooks = items
                            this.recLoaded = true
                            this.recLoading = false
                            this.recRev += 1
                            this.shell().site = ZlibService.currentSite()
                    }
                )
            } catch (err: ZlibError) {
                let text = formatZlibError(err)
                launch(
                    {
                        =>
                            this.recError = text
                            this.recLoading = false
                    }
                )
            } catch (err: Exception) {
                let text = err.message
                launch(
                    {
                        =>
                            this.recError = text
                            this.recLoading = false
                    }
                )
            }
        }
    }

    public func startSearch(): Unit {
        let message = this.query
        if (message.size == 0 || this.loading) {
            return
        }
        this.searchMode = true
        this.loading = true
        this.error = ""
        this.books = ArrayList<BookInfo>()
        this.booksRev += 1
        this.total = 0
        this.page = 0
        this.more = false
        spawn {
            => try {
                let result = ZlibService.search(message, 1, this.order)
                let items = result.books
                let count = result.pagination.totalItems
                let nextMore = result.hasMore()
                launch(
                    {
                        =>
                            this.books = items
                            this.booksRev += 1
                            this.total = count
                            this.page = 1
                            this.more = nextMore
                            this.loading = false
                            this.shell().site = ZlibService.currentSite()
                    }
                )
            } catch (err: ZlibError) {
                let text = formatZlibError(err)
                launch(
                    {
                        =>
                            this.error = text
                            this.loading = false
                    }
                )
            } catch (err: Exception) {
                let text = err.message
                launch(
                    {
                        =>
                            this.error = text
                            this.loading = false
                    }
                )
            }
        }
    }

    public func loadMore(): Unit {
        if (this.loading || this.loadingMore || !this.more) {
            return
        }
        let message = this.query
        let nextPage = this.page + 1
        this.loadingMore = true
        spawn {
            => try {
                let result = ZlibService.search(message, nextPage, this.order)
                let items = result.books
                let nextMore = result.hasMore()
                launch(
                    {
                        =>
                            for (book in items) {
                                this.books.add(book)
                            }
                            this.booksRev += 1
                            this.page = nextPage
                            this.more = nextMore
                            this.loadingMore = false
                    }
                )
            } catch (err: ZlibError) {
                let text = formatZlibError(err)
                launch(
                    {
                        =>
                            this.error = text
                            this.loadingMore = false
                    }
                )
            } catch (err: Exception) {
                let text = err.message
                launch(
                    {
                        =>
                            this.error = text
                            this.loadingMore = false
                    }
                )
            }
        }
    }
}

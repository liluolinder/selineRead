@NonProduct
features {}
package ohos_app_cangjie_entry.viewmodel

internal import ohos.state_manage.ObservedObject
internal import ohos.state_manage.ObservedProperty
internal import ohos.state_manage.ObservedComplexAbstract
import ohos.state_macro_manage.Observed
import ohos.state_macro_manage.Publish
import ohos.concurrency.launch
import std.collection.ArrayList
import zlibraryAPI4CJ.*
import ohos_app_cangjie_entry.model.*

// ---------------------------------------------------------------------------
// 收藏：需要登录态，分页加载。
// ---------------------------------------------------------------------------

@Observed
public class SavedViewModel {
    public var owner: ?SelineViewModel = None

    @Publish
    public var savedLoading: Bool = false
    @Publish
    public var savedError: String = ""
    @Publish
    public var savedPage: Int64 = 0
    @Publish
    public var savedMore: Bool = false
    @Publish
    public var savedRev: Int64 = 0
    @Publish
    public var savedBooks: ArrayList<BookInfo> = ArrayList<BookInfo>()

    public func invalidate(): Unit {
        this.savedBooks = ArrayList<BookInfo>()
        this.savedRev += 1
        this.savedPage = 0
        this.savedMore = false
    }

    public func refreshSaved(clear: Bool): Unit {
        if (this.savedLoading) {
            return
        }
        if (clear) {
            this.invalidate()
        }
        this.savedLoading = true
        this.savedError = ""
        spawn {
            => try {
                let result = ZlibService.saved(1)
                let items = result.books
                let nextMore = result.hasMore()
                launch(
                    {
                        =>
                            this.savedBooks = items
                            this.savedRev += 1
                            this.savedPage = 1
                            this.savedMore = nextMore
                            this.savedLoading = false
                    }
                )
            } catch (err: ZlibError) {
                let text = formatZlibError(err)
                launch(
                    {
                        =>
                            this.savedError = text
                            this.savedLoading = false
                    }
                )
            } catch (err: Exception) {
                let text = err.message
                launch(
                    {
                        =>
                            this.savedError = text
                            this.savedLoading = false
                    }
                )
            }
        }
    }

    public func loadMoreSaved(): Unit {
        if (this.savedLoading || !this.savedMore) {
            return
        }
        let nextPage = this.savedPage + 1
        this.savedLoading = true
        spawn {
            => try {
                let result = ZlibService.saved(nextPage)
                let items = result.books
                let nextMore = result.hasMore()
                launch(
                    {
                        =>
                            for (book in items) {
                                this.savedBooks.add(book)
                            }
                            this.savedRev += 1
                            this.savedPage = nextPage
                            this.savedMore = nextMore
                            this.savedLoading = false
                    }
                )
            } catch (err: ZlibError) {
                let text = formatZlibError(err)
                launch(
                    {
                        =>
                            this.savedError = text
                            this.savedLoading = false
                    }
                )
            } catch (err: Exception) {
                let text = err.message
                launch(
                    {
                        =>
                            this.savedError = text
                            this.savedLoading = false
                    }
                )
            }
        }
    }
}

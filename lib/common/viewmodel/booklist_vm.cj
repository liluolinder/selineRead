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
// 书单：书单列表 + 单个书单内的书籍。
// ---------------------------------------------------------------------------

@Observed
public class BooklistViewModel {
    public var owner: ?SelineViewModel = None

    @Publish
    public var booklistLoading: Bool = false
    @Publish
    public var booklistError: String = ""
    @Publish
    public var booklistRev: Int64 = 0
    @Publish
    public var booklistOpen: Bool = false
    @Publish
    public var booklistTitle: String = ""
    @Publish
    public var booklistBooksLoading: Bool = false
    @Publish
    public var booklistBooksError: String = ""
    @Publish
    public var booklistBooksRev: Int64 = 0
    @Publish
    public var booklists: ArrayList<Readlist> = ArrayList<Readlist>()
    @Publish
    public var booklistPageData: BooklistPage = BooklistPage()
    @Publish
    public var booklistBooks: ArrayList<BookInfo> = ArrayList<BookInfo>()
    @Publish
    public var currentBooklistId: Int64 = 0
    @Publish
    public var booklistsLoaded: Bool = false

    public func booklistCover(id: Int64): String {
        match (this.booklistPageData.previewOf(id)) {
            case Some(list) =>
                if (list.size > 0) {
                    list[0].coverUrl
                } else {
                    ""
                }
            case None => ""
        }
    }

    public func booklistOwner(userId: Int64): String {
        match (this.booklistPageData.owners.get("${userId}")) {
            case Some(owner) => owner.name
            case None => "书单作者"
        }
    }

    public func loadBooklists(force: Bool): Unit {
        if (this.booklistLoading || (this.booklistsLoaded && !force)) {
            return
        }
        this.booklistLoading = true
        this.booklistError = ""
        spawn {
            => try {
                let pageData = ZlibService.booklists(1)
                let items = pageData.readlists
                launch(
                    {
                        =>
                            this.booklistPageData = pageData
                            this.booklists = items
                            this.booklistsLoaded = true
                            this.booklistLoading = false
                            this.booklistRev += 1
                    }
                )
            } catch (err: ZlibError) {
                let text = formatZlibError(err)
                launch(
                    {
                        =>
                            this.booklistError = text
                            this.booklistLoading = false
                    }
                )
            } catch (err: Exception) {
                let text = err.message
                launch(
                    {
                        =>
                            this.booklistError = text
                            this.booklistLoading = false
                    }
                )
            }
        }
    }

    public func openBooklist(rl: Readlist): Unit {
        this.currentBooklistId = rl.id
        this.booklistTitle = rl.title
        this.booklistBooks = ArrayList<BookInfo>()
        this.booklistBooksRev += 1
        this.booklistBooksError = ""
        this.booklistOpen = true
        this.booklistBooksLoading = true
        spawn {
            => try {
                let pageData = ZlibService.booklistBooks(rl.id, 1)
                let items = pageData.books
                launch(
                    {
                        =>
                            this.booklistBooks = items
                            this.booklistBooksRev += 1
                            this.booklistBooksLoading = false
                    }
                )
            } catch (err: ZlibError) {
                let text = formatZlibError(err)
                launch(
                    {
                        =>
                            this.booklistBooksError = text
                            this.booklistBooksLoading = false
                    }
                )
            } catch (err: Exception) {
                let text = err.message
                launch(
                    {
                        =>
                            this.booklistBooksError = text
                            this.booklistBooksLoading = false
                    }
                )
            }
        }
    }
}

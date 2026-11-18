@NonProduct
features {}
package ohos_app_cangjie_entry.viewmodel

import std.collection.ArrayList
import ohos_app_cangjie_entry.model.*
import zlibraryAPI4CJ.*

// ---------------------------------------------------------------------------
// Model: reusable session facade (merged from the former SelineKit library).
// The actual transport/credential handling lives in ZlibService; this facade
// gives other code a small, library-like API surface.
// ---------------------------------------------------------------------------

public class SelineSession {
    public static func isLoggedIn(): Bool {
        ZlibService.isLoggedIn()
    }

    public static func currentSite(): String {
        ZlibService.currentSite()
    }

    public static func login(email: String, password: String): String {
        ZlibService.login(email, password)
    }

    public static func logout(): Unit {
        ZlibService.logout()
    }

    public static func search(message: String, page: Int64, order: String): BookPage {
        ZlibService.search(message, page, order)
    }

    public static func saved(page: Int64): BookPage {
        ZlibService.saved(page)
    }

    public static func bookInfo(id: Int64, hash: String): BookInfo {
        ZlibService.bookInfo(id, hash)
    }

    public static func download(book: BookInfo): LocalDownload {
        ZlibService.download(book)
    }

    public static func mostPopular(): ArrayList<BookInfoBrief> {
        ZlibService.mostPopular()
    }

    public static func booklists(page: Int64): BooklistPage {
        ZlibService.booklists(page)
    }

    public static func booklistBooks(id: Int64, page: Int64): BooklistBooksPage {
        ZlibService.booklistBooks(id, page)
    }
}







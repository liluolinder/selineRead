@NonProduct
features {}
package ohos_app_cangjie_entry.viewmodel

import std.collection.*
import std.fs.Path as FsPath
import std.time.*
import zlibraryAPI4CJ.*
import zlibraryAPI4CJ.login.*
import zlibraryAPI4CJ.search.*
import zlibraryAPI4CJ.book.*
import zlibraryAPI4CJ.user.*
import zlibraryAPI4CJ.booklist.*
import linderHttp.http.*
import ohos.base.AppLog
import ohos_app_cangjie_entry.model.*

// ---------------------------------------------------------------------------
// Thin, platform-neutral service around zlibraryAPI4CJ.
//
// Every call here is synchronous and blocking; UI code must run it inside
// spawn { ... } and commit @State through launch { ... }.
// ---------------------------------------------------------------------------

public class ZlibService {
    private static var guestClient: ?ZlibClient = None
    private static var sessionClient: ?ZlibClient = None
    private static var loggedIn: Bool = false
    private static var displayName: String = ""

    /// All requests use TrustAll TLS. Android's system CA store is not wired
    /// into stdx/OpenSSL, so certificate verification is disabled here.
    private static func makeClient(baseUrl: String, credential!: ZlibCredential = ZlibCredential.anonymous()): ZlibClient {
        let tls = TlsOptions.trustAll()
        let http = HttpClientBuilder().cookies(true).tls(tls).build()
        ZlibClient.fromHttpClient(
            http,
            baseUrl: baseUrl,
            credential: credential,
            seed: SelineSettings.seedUrl())
    }

    private static var redirectChecked: Bool = false

    /// zlibraryAPI4CJ's own `probeSite` uses a default-TLS HttpClient, which
    /// cannot verify Android's CA store. Probe the entry domain here with
    /// TrustAll + followRedirects(false), and adopt the Location target.
    public static func ensureSite(): Unit {
        if (redirectChecked) {
            return
        }
        redirectChecked = true
        let client = match (guestClient) {
            case Some(value) => value
            case None => return
        }
        let base = client.currentSiteUrl()
        var target = ""
        try {
            let probe = HttpClientBuilder()
                .followRedirects(false)
                .cookies(false)
                .tls(TlsOptions.trustAll())
                .readTimeout(Duration.second * 5)
                .totalTimeout(Duration.second * 10)
                .build()
            let response = probe.head(base)
            match (response.location) {
                case Some(location) =>
                    let text = location.trimAscii()
                    if (text.startsWith("http://") || text.startsWith("https://")) {
                        target = text
                    } else if (text.startsWith("/")) {
                        target = "${ZlibHost.of(base).url}${text}"
                    } else if (text.size > 0) {
                        target = "${ZlibHost.of(base).url}/${text}"
                    }
                case None => ()
            }
            probe.close()
        } catch (_: Exception) {
            target = ""
        }
        if (target.size > 0 && target != base) {
            client.setCustomSite(target)
            match (sessionClient) {
                case Some(session) => session.setCustomSite(target)
                case None => ()
            }
            SelineSettings.setBaseUrl(target)
            AppLog.info("site redirect: ${base} -> ${target}")
        }
    }
    /// Create the guest client and restore a persisted session (no network I/O).
    public static func bootstrap(): Unit {
        if (guestClient.isNone()) {
            guestClient = Some(makeClient(SelineSettings.baseUrl()))
        }
        let cookie = SelineSettings.cookie()
        if (cookie.size > 0 && sessionClient.isNone()) {
            try {
                let credential = ZlibCredential.fromCookieString(cookie)
                if (credential.isLoggedIn) {
                    sessionClient = Some(makeClient(SelineSettings.baseUrl(), credential: credential))
                    loggedIn = true
                    displayName = SelineSettings.accountName()
                }
            } catch (_: Exception) {
                loggedIn = false
            }
        }
    }

    public static func isLoggedIn(): Bool {
        loggedIn
    }

    public static func accountName(): String {
        if (displayName.size > 0) {
            displayName
        } else {
            SelineSettings.accountName()
        }
    }

    public static func currentSite(): String {
        match (sessionClient) {
            case Some(client) => client.currentSiteUrl()
            case None =>
                match (guestClient) {
                    case Some(client) => client.currentSiteUrl()
                    case None => SelineSettings.baseUrl()
                }
        }
    }

    public static func login(email: String, password: String): String {
        let guest = requireGuest()
        let result = LoginApi.login(guest, email, password)
        let session = result.withClient(guest)
        sessionClient = Some(session)
        loggedIn = true
        displayName = result.user.name
        SelineSettings.saveLogin(result.credential.toCookieHeader(), result.user.name, email)
        result.user.name
    }

    public static func logout(): Unit {
        sessionClient = None
        loggedIn = false
        displayName = ""
        SelineSettings.clearLogin()
    }

    public static func resetClients(): Unit {
        // close() is idempotent and closes the shared connection pool; do it once.
        match (guestClient) {
            case Some(client) =>
                try {
                    client.close()
                } catch (_: Exception) {
                    ()
                }
            case None => ()
        }
        guestClient = None
        sessionClient = None
        loggedIn = false
        displayName = ""
    }

    public static func search(message: String, page: Int64, order: String): BookPage {
        let client = activeClient()
        let orderOption: ?String = if (order.size == 0 || order == "relevance") {
            None
        } else {
            Some(order)
        }
        SearchApi.search(client, message, order: orderOption, page: page, limit: 20)
    }

    public static func saved(page: Int64): BookPage {
        let client = requireSession()
        UserApi.saved(client, order: "date", page: page, limit: 20)
    }

    public static func downloaded(page: Int64): BookPage {
        let client = requireSession()
        UserApi.downloaded(client, order: "date", page: page, limit: 20)
    }

    public static func mostPopular(): ArrayList<BookInfoBrief> {
        SearchApi.mostPopular(activeClient())
    }

    public static func booklists(page: Int64): BooklistPage {
        BooklistApi.list(activeClient(), page: page)
    }

    public static func booklistBooks(id: Int64, page: Int64): BooklistBooksPage {
        BooklistApi.books(activeClient(), id, page: page)
    }

    public static func profile(): ZlibUser {
        let client = requireSession()
        UserApi.profile(client)
    }

    public static func bookInfo(id: Int64, hash: String): BookInfo {
        BookApi.info(activeClient(), id, hash)
    }

    public static func toggleSaved(id: Int64, currentlySaved: Bool): Bool {
        let client = requireSession()
        if (currentlySaved) {
            BookApi.unsave(client, id)
            false
        } else {
            BookApi.save(client, id)
            true
        }
    }

    public static func download(book: BookInfo): LocalDownload {
        let client = requireSession()
        let info = BookApi.file(client, book.id, book.hash)
        if (!info.available()) {
            throw Exception("该书暂时没有可用下载链接（可能需要登录或更换站点）")
        }
        let dir = FsPath(SelineSettings.downloadsDir())
        let written = BookApi.download(client, info, dir)
        let fileName = info.fileName()
        let path = SelineSettings.downloadsDir() + "/" + fileName
        let item = LocalDownload(book.title, fileName, path)
        SelineSettings.addDownload(item)
        AppLog.info("downloaded " + fileName)
        item
    }

    public static func fileInfo(book: BookInfo): DownloadInfo {
        BookApi.file(requireSession(), book.id, book.hash)
    }

    public static func formats(book: BookInfo): ArrayList<BookFormat> {
        BookApi.formats(activeClient(), book.id, book.hash)
    }

    private static func requireGuest(): ZlibClient {
        bootstrap()
        match (guestClient) {
            case Some(client) => client
            case None => throw Exception("Z-Library 客户端初始化失败")
        }
    }

    private static func activeClient(): ZlibClient {
        ensureSite()
        match (sessionClient) {
            case Some(client) => client
            case None => requireGuest()
        }
    }

    private static func requireSession(): ZlibClient {
        ensureSite()
        match (sessionClient) {
            case Some(client) => client
            case None => throw Exception("请先在「设置」中登录 Z-Library 账号")
        }
    }
}

















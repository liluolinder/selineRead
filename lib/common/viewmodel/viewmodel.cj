@NonProduct
features {}
package ohos_app_cangjie_entry.viewmodel

internal import ohos.state_manage.ObservedObject
internal import ohos.state_manage.ObservedProperty
internal import ohos.state_manage.ObservedComplexAbstract
import ohos.state_macro_manage.Observed
import ohos.state_macro_manage.Publish
internal import ohos.component.*
import zlibraryAPI4CJ.*
import ohos_app_cangjie_entry.model.*
import ohos_app_cangjie_entry.model.*

// ---------------------------------------------------------------------------
// 根 ViewModel / 外壳。
//
// 只保留跨分类共享的外壳状态（宽窄屏、避让区、当前 Tab、登录态）与页面路由，
// 具体业务状态按分类拆到独立的 @Observed 类里：
//   HomeViewModel      首页（推荐 + 搜索）
//   BooklistViewModel  书单
//   SavedViewModel     收藏
//   DownloadsViewModel 下载
//   DetailViewModel    图书详情
//   SettingsViewModel  设置（登录 / 服务器）
//
// 分类 ViewModel 通过 owner 反向访问外壳，宿主是唯一持有者。
// ---------------------------------------------------------------------------

@Observed
public class SelineViewModel {
    // shell
    @Publish
    public var wide: Bool = false
    @Publish
    public var tab: Int64 = 0
    @Publish
    public var showDetail: Bool = false
    @Publish
    public var loggedIn: Bool = false
    @Publish
    public var accountName: String = ""
    @Publish
    public var site: String = ""

    /// Tab 容器控制器：让 switchTab() 成为唯一的页面切换入口。
    public var tabs: TabsController = TabsController()

    public var pathStack: NavPathStack = NavPathStack()

    /// 窗口数据（避让区 / 尺寸 / 宽屏 / PC 形态）。
    @Publish
    public var window: WindowData = windowData()

    // category view models
    @Publish
    public var home: HomeViewModel = HomeViewModel()
    @Publish
    public var booklists: BooklistViewModel = BooklistViewModel()
    @Publish
    public var saved: SavedViewModel = SavedViewModel()
    @Publish
    public var downloads: DownloadsViewModel = DownloadsViewModel()
    @Publish
    public var detail: DetailViewModel = DetailViewModel()
    @Publish
    public var settings: SettingsViewModel = SettingsViewModel()

    private func attachCategories(): Unit {
        this.home.owner = Some(this)
        this.booklists.owner = Some(this)
        this.saved.owner = Some(this)
        this.downloads.owner = Some(this)
        this.detail.owner = Some(this)
        this.settings.owner = Some(this)
    }

    public func start(): Unit {
        this.attachCategories()
        ZlibService.bootstrap()
        this.site = ZlibService.currentSite()
        this.loggedIn = ZlibService.isLoggedIn()
        this.accountName = ZlibService.accountName()
        this.home.waterfall = true
        this.home.order = SelineSettings.searchOrder()
        this.settings.baseUrlInput = SelineSettings.baseUrl()
        this.settings.seedUrlInput = SelineSettings.seedUrl()
        this.downloads.reload()
        this.home.loadRecommendations(false)
    }

    public func handleBack(): Bool {
        if (this.showDetail) {
            this.showDetail = false
            return true
        }
        if (this.tab == 1 && this.booklists.booklistOpen) {
            this.booklists.booklistOpen = false
            return true
        }
        if (this.tab == 0 && this.home.searchMode) {
            this.home.clearSearch()
            return true
        }
        false
    }

    public func currentTitle(): String {
        if (this.showDetail) {
            return "图书详情"
        }
        if (this.tab == 1 && this.booklists.booklistOpen) {
            return this.booklists.booklistTitle
        }
        match (this.tab) {
            case 0 => "首页"
            case 1 => "书单"
            case 2 => "收藏"
            case 3 => "下载"
            case _ => "设置"
        }
    }

    public func switchTab(index: Int64): Unit {
        this.showDetail = false
        this.booklists.booklistOpen = false
        this.tab = index
        this.tabs.changeIndex(Int32(index))
        this.loggedIn = ZlibService.isLoggedIn()
        this.accountName = ZlibService.accountName()
        this.site = ZlibService.currentSite()
        if (index == 0) {
            this.home.loadRecommendations(false)
        }
        if (index == 1) {
            this.booklists.loadBooklists(false)
        }
        if (index == 2 && this.loggedIn && this.saved.savedBooks.size == 0) {
            this.saved.refreshSaved(true)
        }
        if (index == 3) {
            this.downloads.reload()
        }
    }
}











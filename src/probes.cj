/*
 * 探针/诊断代码集中在这里。
 *
 * `applyDebugProbes` 用 `@When[debug]` 包着：`cjpm build`（release）里这段
 * 不参与编译，`SELINE_READ_*` / 自测开关等界面验收入口只存在于 `cjpm build -g`。
 * release 版留一个空实现，调用点不需要额外的条件编译。
 *
 * `PerfStats` 是 `--perf` 的帧耗时统计，同样只服务开发期测量。
 */
package seline_read

import std.convert.*
import std.env.getVariable
import chui.*
import seline_ui.*
class PerfStats {
    let enabled: Bool
    var frames: Int64 = 0
    var totalMs: Float64 = 0.0
    var maxMs: Float64 = 0.0
    var slowFrames: Int64 = 0

    init(enabled: Bool) {
        this.enabled = enabled
    }

    func onFrame(deltaMs: Float32): Unit {
        if (!enabled) {
            return
        }
        frames += 1
        totalMs += Float64(deltaMs)
        let value = Float64(deltaMs)
        if (value > maxMs) {
            maxMs = value
        }
        if (deltaMs > 33.0) {
            slowFrames += 1
        }
        if (frames % 30 == 0) {
            writeDebugLog("PERF frame=${frames} avg=${Int64(totalMs / Float64(frames))}ms " +
                "max=${Int64(maxMs)}ms slow=${slowFrames}")
        }
    }

    func summary(): Unit {
        if (enabled && frames > 0) {
            writeDebugLog("PERF FINAL frames=${frames} avg=${Int64(totalMs / Float64(frames))}ms " +
                "max=${Int64(maxMs)}ms slow=${slowFrames}")
        }
    }
}
/**
 * 启动期的验收/诊断探针：`--shot`、`SELINE_READ_*` 环境变量、自测开关等。
 *
 * 用 `@When[debug]` 包起来：`cjpm build`（release）里整段不参与编译，
 * 只有 `cjpm build -g`（debug）才包含，release 产物里搜不到这些环境变量名。
 */
@When[debug]
func applyDebugProbes(state: AppState, options: LaunchOptions, app: DesktopApp): Unit {
        if ((getVariable("SELINE_READ_SKELETON") ?? "") == "1") {
            state.forceSkeleton.value = true
        }
        // 验收：启动即为浅色（并可选触发一次辐射切换）
        if ((getVariable("SELINE_READ_LIGHT") ?? "") == "1") {
            state.darkMode.value = false
            setSelineTheme(SelineTheme.light())
            app.setTheme(selineChuiTheme())
        }
        let themeMs = getVariable("SELINE_READ_TOGGLE_THEME_MS") ?? ""
        if (!themeMs.isEmpty()) {
            let _ = spawn {=>
                sleep(Int64.parse(themeMs) * Duration.millisecond)
                state.postThemeToggleForTest()
            }
        }
        if (options.booklistAutoOpen) {
            state.setAutoOpenFirstBooklist()
        }
        if (options.railOpen) {
            state.railExpanded.value = true
            state.railZonesOpen.value = true
        }
        // 验收开关必须在 attach 之后：后台结果靠 `postToUi` 回投，
        // 窗口没建好时那条通道会直接丢弃。
        // 验收开关：--search= 或环境变量 SELINE_READ_SEARCH（中文参数在子系统下可能传不进来）
        let envKeyword = getVariable("SELINE_READ_SEARCH") ?? ""
        if (!options.searchKeyword.isEmpty() || !envKeyword.isEmpty()) {
            let keyword = if (!options.searchKeyword.isEmpty()) {
                options.searchKeyword
            } else {
                envKeyword
            }
            state.searchText.value = keyword
            state.submitSearch()
            // 验收：延迟 500ms 再搜 B，验证 A 的迟到结果会被丢弃
            let clearMs = getVariable("SELINE_READ_CLEAR_SEARCH_MS") ?? ""
            if (!clearMs.isEmpty()) {
                state.scheduleClearSearchForTest(Int64.parse(clearMs))
            }
            let raceB = getVariable("SELINE_READ_SEARCH_RACE_B") ?? ""
            if (!raceB.isEmpty()) {
                let delayMs = Int64.parse(getVariable("SELINE_READ_SEARCH_RACE_DELAY_MS") ?? "500")
                state.scheduleSearchForTest(raceB, delayMs)
            }
        }
        if (options.login) {
            let email = getVariable("ZLIB_TEST_EMAIL") ?? ""
            let password = getVariable("ZLIB_TEST_PASSWORD") ?? ""
            if (!email.isEmpty() && !password.isEmpty()) {
                state.loginEmail.value = email
                state.loginPassword.value = password
                state.submitLogin()
            } else {
                writeDebugLog("--login: ZLIB_TEST_EMAIL/PASSWORD not set")
            }
        }
        if (options.openDownloadMenu) {
            state.openDownloadMenu()
        }
        let openMenuMs = getVariable("SELINE_READ_OPEN_DL_MENU_AFTER_MS") ?? ""
        if (!openMenuMs.isEmpty()) {
            state.scheduleOpenDownloadMenuForTest(Int64.parse(openMenuMs))
        }
        let popularIndexEnv = getVariable("SELINE_READ_OPEN_POPULAR_INDEX") ?? ""
        if (!popularIndexEnv.isEmpty()) {
            let index = Int64.parse(popularIndexEnv)
            state.whenClientReady({=> state.openPopularForTest(index) })
        }
        // 验收用：延时展开/收起侧栏（动画观测）
        let railToggleMs = getVariable("SELINE_READ_RAIL_TOGGLE_MS") ?? ""
        if (!railToggleMs.isEmpty()) {
            state.scheduleRailToggleForTest(Int64.parse(railToggleMs))
        }
        let searchIndexEnv = getVariable("SELINE_READ_OPEN_SEARCH_INDEX") ?? ""
        if (!searchIndexEnv.isEmpty()) {
            state.openSearchResultForTest(Int64.parse(searchIndexEnv))
        }
        let favIndexEnv = getVariable("SELINE_READ_OPEN_FAVORITE_INDEX") ?? ""
        if (!favIndexEnv.isEmpty()) {
            state.openFavoriteForTest(Int64.parse(favIndexEnv))
        }
        if (!options.bookTarget.isEmpty()) {
            let parts = options.bookTarget.split("|")
            if (parts.size >= 2) {
                let bookId = Int64.tryParse(parts[0]) ?? 0
                if (bookId > 0) {
                    state.openBookById(bookId, parts[1])
                }
            }
        }
        if ((getVariable("SELINE_READ_FAKE_LOGGED_IN") ?? "") == "1") {
            state.loggedIn.value = true
            writeDebugLog("test: fake logged in")
        }
        let clickDownloadMs = getVariable("SELINE_READ_CLICK_DOWNLOAD_MS") ?? ""
        if (!clickDownloadMs.isEmpty()) {
            state.scheduleClickDownloadForTest(Int64.parse(clickDownloadMs))
        }
        let downloadBookMs = getVariable("SELINE_READ_DOWNLOAD_BOOK_MS") ?? ""
        if (!downloadBookMs.isEmpty()) {
            state.scheduleDownloadBookForTest(Int64.parse(downloadBookMs))
        }
        // 验收用：SELINE_READ_TOAST_TEST=info|success|error，启动后弹一条对应语义的 toast
        let toastTest = getVariable("SELINE_READ_TOAST_TEST") ?? ""
        if (!toastTest.isEmpty()) {
            let (text, kind) = match (toastTest) {
                case "success" => ("已加入下载队列（5731855-1）", ToastKind.Success)
                case "error" => ("收藏失败：网络连接不可用", ToastKind.Error)
                case _ => ("正在获取中，请稍后", ToastKind.Info)
            }
            state.startToastLoopForTest(text, kind: kind)
        }
        let favoriteMs = getVariable("SELINE_READ_FAVORITE_MS") ?? ""
        if (!favoriteMs.isEmpty()) {
            state.scheduleToggleFavoriteForTest(Int64.parse(favoriteMs))
        }
        let favorite2Ms = getVariable("SELINE_READ_FAVORITE2_MS") ?? ""
        if (!favorite2Ms.isEmpty()) {
            state.scheduleToggleFavoriteForTest(Int64.parse(favorite2Ms))
        }
        if ((getVariable("SELINE_READ_TEST_DL_TWICE") ?? "") == "1") {
            // 验收：未登录连点两次下载，应该弹两次 toast
            state.downloadBook()
            state.downloadBook()
        }
        if ((getVariable("SELINE_READ_TEST_DL") ?? "") == "1") {
            state.runDownloadSelfTest()
        }
        let fakeAccounts = getVariable("SELINE_READ_FAKE_ACCOUNTS") ?? ""
        if (!fakeAccounts.isEmpty()) {
            state.forceFakeAccountsForShot(fakeAccounts == "dialog")
        }
        let forceErrorsMode = getVariable("SELINE_READ_FORCE_ERRORS") ?? ""
        if (!forceErrorsMode.isEmpty()) {
            state.forceErrorStatesForShot(forceErrorsMode)
        }
        if ((getVariable("SELINE_READ_TEST_MOCK_RACE") ?? "") == "1") {
            state.runMockRaceSelfTest()
        }
        if ((getVariable("SELINE_READ_FAKE_SEARCH") ?? "") == "1") {
            state.forceFakeSearchForShot()
        }
        if ((getVariable("SELINE_READ_TEST_STALE") ?? "") == "1") {
            state.runStalePayloadSelfTest()
            state.runSearchPagingOfflineTest()
        }
        if ((getVariable("SELINE_READ_TEST_RACE") ?? "") == "1") {
            state.runDetailRaceSelfTest()
        }
        let searchPagingKeyword = getVariable("SELINE_READ_TEST_SEARCH_PAGING") ?? ""
        if (!searchPagingKeyword.isEmpty()) {
            state.runSearchPagingSelfTest(searchPagingKeyword)
        }
        if ((getVariable("SELINE_READ_TEST_NAV") ?? "") == "1") {
            state.runNavStackSelfTest()
        }
        let settingsTabEnv = getVariable("SELINE_READ_SETTINGS_TAB") ?? ""
        if (!settingsTabEnv.isEmpty()) {
            state.selectSettingsTab(Int64.parse(settingsTabEnv))
        }
        // 验收：各页面滚动位置（截图用）
        let detailScrollEnv = getVariable("SELINE_READ_DETAIL_SCROLL") ?? ""
        if (!detailScrollEnv.isEmpty()) {
            state.detailScroll.value = Float32.parse(detailScrollEnv)
        }
        let scrollAfterEnv = getVariable("SELINE_READ_SCROLL_AFTER_MS") ?? ""
        let scrollValueEnv = getVariable("SELINE_READ_DETAIL_SCROLL") ?? "0"
        if (!scrollAfterEnv.isEmpty()) {
            let delayMs = Int64.parse(scrollAfterEnv)
            let value = Float32.parse(scrollValueEnv)
            let _ = spawn {=>
                sleep(delayMs * Duration.millisecond)
                state.postDetailScrollForTest(value)
            }
        }
        let searchScrollEnv = getVariable("SELINE_READ_SEARCH_SCROLL") ?? ""
        if (!scrollAfterEnv.isEmpty() && !searchScrollEnv.isEmpty()) {
            let delayMs = Int64.parse(scrollAfterEnv)
            let value = Float32.parse(searchScrollEnv)
            let _ = spawn {=>
                sleep(delayMs * Duration.millisecond)
                state.postScrollForTest(state.searchScroll, value)
            }
        }
        let homeScrollEnv = getVariable("SELINE_READ_HOME_SCROLL") ?? ""
        if (!homeScrollEnv.isEmpty()) {
            state.homeScroll.value = Float32.parse(homeScrollEnv)
        }
        let openRelatedMs = getVariable("SELINE_READ_OPEN_RELATED_MS") ?? ""
        if (!openRelatedMs.isEmpty()) {
            state.scheduleOpenFirstRelatedForTest(Int64.parse(openRelatedMs))
        }
        let backMs = getVariable("SELINE_READ_BACK_MS") ?? ""
        if (!backMs.isEmpty()) {
            state.scheduleCloseDetailForTest(Int64.parse(backMs))
        }
        // 验收：简介滚动偏移（验证固定高度内的滚动）
        let descOffset = getVariable("SELINE_READ_DESC_OFFSET") ?? ""
        if (!descOffset.isEmpty()) {
            state.detailDescriptionOffset.value = Float32.parse(descOffset)
        }
        // 验收：直接切到详情页某个分段（0 信息 / 1 评论 / 2 相关）
        let detailSectionEnv = getVariable("SELINE_READ_DETAIL_SECTION") ?? ""
        if (!detailSectionEnv.isEmpty()) {
            state.selectDetailSection(Int64.parse(detailSectionEnv))
            writeDebugLog("detail section -> ${state.detailSection.value}")
        }
        if (!options.downloadTarget.isEmpty()) {
            let parts = options.downloadTarget.split("|")
            if (parts.size >= 2) {
                let bookId = Int64.tryParse(parts[0]) ?? 0
                if (bookId > 0) {
                    if (options.login) {
                        state.setAutoDownload(bookId, parts[1])
                    } else {
                        state.downloadById(bookId, parts[1])
                    }
                }
            }
        }
}

/** release 构建里的空实现：调用点无需条件编译。 */
@When[!debug]
func applyDebugProbes(_: AppState, _: LaunchOptions, _: DesktopApp): Unit {}

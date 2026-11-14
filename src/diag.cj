/*
 * 手动测试用的帧诊断记录。
 *
 * 目的：用户自己动手点的时候，把**每一帧的真实间隔**和当时的界面状态写进
 * `%TEMP%\seline_read_debug.log`，事后可以精确定位"卡"发生在哪一帧、哪一相。
 *
 * 写盘策略（避免日志本身成为负担）：
 * - 慢帧（>18ms）：每帧都记，带完整现场；
 * - 侧栏动画期间：由 `railAdvance` 单独记 `RAIL` 行（见 sidebar_rail.cj）；
 * - 其余情况：每 60 帧（约 1 秒）记一条心跳，证明"这段时间是顺的"。
 */
package seline_read

import std.convert.*
import std.runtime.{getGCCount, getGCTime, getGCFreedSize}

/** 心跳间隔（帧）。 */
private let DIAG_HEARTBEAT_FRAMES: Int64 = 60
/** 超过这个间隔就认为"这一帧卡了"，逐帧记录。 */
private let DIAG_SLOW_MS: Float32 = 18.0

/** 当前页面名字（日志里好认）。 */
private func diagPageName(state: AppState): String {
    if (state.detailOpen.value) {
        return "detail"
    }
    if (state.booklistOpen.value) {
        return "booklist-detail"
    }
    let tab = state.tab.value
    if (tab == TAB_FAVORITES) {
        return "favorites"
    }
    if (tab == TAB_BOOKLISTS) {
        return "booklists"
    }
    if (tab == TAB_DOWNLOADS) {
        return "downloads"
    }
    if (tab == TAB_SETTINGS) {
        return "settings"
    }
    if (tab == TAB_ACCOUNT) {
        return "account"
    }
    if (!state.lastKeyword.value.isEmpty()) {
        return "search"
    }
    return "home"
}

/** 会话开始标记：日志里从这里往后就是本次手动测试。 */
public func diagSessionStart(): Unit {
    writeDebugLog("=== DIAG SESSION START ===")
}

/**
 * 每帧调用一次。
 *
 * 慢帧每帧都写；否则每 60 帧写一条心跳。行格式固定，便于事后用脚本统计：
 *   FRAME tick=<n> ms=<d> page=<name> rail=<0|1> scroll=<x> cells=<n> loading=<0|1> slow=<0|1>
 */
public func diagFrame(state: AppState, tick: Int64, deltaMs: Float32): Unit {
    let slow = deltaMs > DIAG_SLOW_MS
    if (!slow && (tick % DIAG_HEARTBEAT_FRAMES) != 0) {
        return
    }
    let page = diagPageName(state)
    let loading = state.loading.value || state.booklistsLoading.value || state.favoritesLoading.value ||
        state.searchLoadingMore.value || state.booklistLoading.value
    // GC 计数也一起记：慢帧如果伴随 GC 次数/耗时增长，就能直接坐实"GC 停顿"
    writeDebugLog("FRAME tick=${tick} ms=${Int64(deltaMs)} page=${page} rail=${state.railExpanded.value} " +
        "scroll=${Int64(state.homeScroll.value)} cells=${state.popular.value.size}/${state.booklists.value.size}/${state.favorites.value.size} " +
        "loading=${loading} slow=${slow} gcc=${getGCCount()} gct=${getGCTime()} freed=${getGCFreedSize()}")
}

/** 关键事件标记（侧栏开关、数据到达、用户操作）。 */
public func diagMark(text: String): Unit {
    writeDebugLog("MARK ${text}")
}

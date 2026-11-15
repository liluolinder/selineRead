/*
 * 站点配置（**仅前端定义**）。
 *
 * 与后端 zlibraryAPI4CJ 的分工：
 *
 * | 概念 | 定义位置 | 后端是否可见 |
 * | --- | --- | --- |
 * | 官方地址（3 个） | 本文件 `OFFICIAL_SITES` | **不可见**：后端不再内置官方域名列表 |
 * | 自定义地址（数组） | 用户配置文件 `config.json` 的 `customSites` | 只把**当前选中的那个**单值传给后端 |
 * | 种子站（单个） | 用户配置文件 `config.json` 的 `seedSite` | 单值传给后端（`seed`），禁止数组 |
 *
 * 请求侧规则（见 `AppState`）：
 * - 选的是**官方地址**：失败就直接报「网络链接失败」，**不**走种子站回退；
 * - 选的是**自定义地址**：失败时让后端用种子站换新域名，成功后把这一条自定义地址覆盖成新域名。
 */
package seline_read

import zlibraryAPI4CJ.core.*

/**
 * 官方地址：固定 3 个，只在前端存在。
 *
 * 顺序就是设置页的展示顺序（第一个是首次启动的默认站点）。
 */
let OFFICIAL_SITES: Array<String> = [
    "https://zh.z-library.sk",
    "https://zh.z-lib.sk",
    "https://zh.1lib.sk"
]

/**
 * 默认种子站（引导站）。
 *
 * 只有**自定义地址**访问失败时才会用到；官方地址失败不会回退到这里。
 */
let DEFAULT_SEED_SITE: String = "https://zh.eva101.ru"

/**
 * 规范化站点地址：去首尾空白、补 `https://`、去尾部 `/`、去掉误加的 `/eapi`。
 *
 * 空串返回空串（调用方自己决定怎么提示）。
 */
func normalizeSiteUrl(raw: String): String {
    var value = raw.trimAscii()
    if (value.isEmpty()) {
        return ""
    }
    if (!value.startsWith("http://") && !value.startsWith("https://")) {
        value = "https://" + value
    }
    if (value.endsWith("/eapi")) {
        value = value[0..(value.size - 5)]
    }
    while (value.size > 1 && value.endsWith("/")) {
        value = value[0..(value.size - 1)]
    }
    value
}

/** 是否是**官方地址**（只比较前端内置的这 3 个）。 */
func isOfficialSiteUrl(url: String): Bool {
    let target = normalizeSiteUrl(url)
    if (target.isEmpty()) {
        return false
    }
    for (site in OFFICIAL_SITES) {
        if (site == target) {
            return true
        }
    }
    false
}

/** 展示用地址：统一带尾部 `/`（设置页里官方地址就是这种写法）。 */
func displaySiteUrl(url: String): String {
    let value = normalizeSiteUrl(url)
    if (value.isEmpty()) {
        return ""
    }
    "${value}/"
}

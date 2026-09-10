/*
 * SelineRead · 主题与颜色令牌。
 *
 * 照 SelineDebugToolBox 的组织方式：所有颜色令牌集中在此，视图只引用
 * 语义名，不出现裸色值。全套深色阅读风：深夜蓝底 + 靛蓝品牌强调，
 * 侧栏/标题栏用更深的框架色，内容区面板用浅一档的深灰蓝体现层次；
 * 窗口三键为浅色图标，在深色框架上自然清晰。
 */
package SelineRead

import chui.{Color, SurfaceStyle, Theme}

/** 应用主题：深色阅读风格（传入 DesktopApp 的 theme 参数）。 */
func selineDarkTheme(): Theme {
    Theme(
        bg: Color.rgb(15, 18, 28),
        panel: Color.rgb(24, 28, 42),
        panelEdge: Color.rgb(44, 50, 68),
        text: Color.rgb(226, 232, 244),
        mutedText: Color.rgb(122, 132, 152),
        accent: Color.rgb(96, 165, 250),
        accentText: Color.rgb(15, 18, 28),
        danger: Color.rgb(248, 113, 113),
        field: Color.rgb(30, 35, 52),
        fieldActive: Color.rgb(36, 42, 62),
        panelRaised: Color.rgb(34, 39, 56),
        accentSoft: Color.rgba(96, 165, 250, 38),
        shadow: Color.rgba(0, 0, 0, 88),
        radius: 12.0,
        smallRadius: 7.0,
        controlRadius: 9.0
    )
}

/** 浅色主题：明亮阅读风格。 */
func selineLightTheme(): Theme {
    Theme(
        bg: Color.rgb(242, 245, 249),
        panel: Color.rgb(255, 255, 255),
        panelEdge: Color.rgb(210, 217, 226),
        text: Color.rgb(20, 27, 38),
        mutedText: Color.rgb(93, 105, 122),
        accent: Color.rgb(33, 114, 229),
        accentText: Color.rgb(255, 255, 255),
        danger: Color.rgb(208, 63, 67),
        field: Color.rgb(240, 243, 247),
        fieldActive: Color.rgb(230, 235, 242),
        panelRaised: Color.rgb(250, 251, 252),
        accentSoft: Color.rgba(33, 114, 229, 20),
        shadow: Color.rgba(16, 24, 40, 20),
        radius: 12.0,
        smallRadius: 7.0,
        controlRadius: 9.0
    )
}

/** 根据主题模式获取主题：0=深色(默认), 1=深色, 2=浅色 */
func selineTheme(themeMode: Int64): Theme {
    if (themeMode == 2) {
        selineLightTheme()
    } else {
        selineDarkTheme()
    }
}

// ---- 品牌与框架色 ----

/** 品牌强调色（Logo 角标文字 / 选中页签 / 搜索按钮；深底上用亮靛蓝保证对比）。 */
let BRAND_COLOR: Color = Color.rgb(96, 165, 250)

/** 品牌低透明底（选中页签背景 / 占位文字）。 */
let BRAND_SOFT_BG: Color = Color.rgba(96, 165, 250, 34)

/** 侧边导航栏背景：深色=深框架色，浅色=浅灰框架色。 */
func sidebarBg(mode: Int64): Color {
    if (mode == 2) { Color.rgb(245, 247, 250) } else { Color.rgb(11, 13, 21) }
}

/** 侧栏正文文字色：深色=浅灰，浅色=深灰。 */
func sidebarText(mode: Int64): Color {
    if (mode == 2) { Color.rgb(60, 70, 90) } else { Color.rgb(203, 213, 225) }
}

// ---- 内容区 ----

/** 封面占位底色。 */
func coverBg(mode: Int64): Color {
    if (mode == 2) { Color.rgb(230, 235, 242) } else { Color.rgb(36, 42, 62) }
}

/** 骨架屏占位块底色。 */
func skeletonBg(mode: Int64): Color {
    if (mode == 2) { Color.rgb(220, 225, 232) } else { Color.rgb(34, 40, 58) }
}

/** 详情页卡片底色。 */
func cardBg(mode: Int64): Color {
    if (mode == 2) { Color.rgb(255, 255, 255) } else { Color.rgb(24, 28, 42) }
}

/** 卡片描边色。 */
func cardEdge(mode: Int64): Color {
    if (mode == 2) { Color.rgb(210, 217, 226) } else { Color.rgb(52, 59, 80) }
}

/** 分隔线色（卡片内分组之间）。 */
func detailDivider(mode: Int64): Color {
    if (mode == 2) { Color.rgb(210, 217, 226) } else { Color.rgb(44, 50, 68) }
}

/** 详情页卡片表面样式：底色 + 细描边 + 柔和投影。 */
func panelCardStyle(mode: Int64): SurfaceStyle {
    let shadow = if (mode == 2) { Color.rgba(16, 24, 40, 12) } else { Color.rgba(0, 0, 0, 70) }
    SurfaceStyle(cardBg(mode), border: cardEdge(mode), borderWidth: 1.0, radius: 14.0,
        shadow: shadow, shadowOffsetY: 3.0)
}

/** 详情页英雄区卡片：同卡片样式但更大圆角、更重投影。 */
func heroCardStyle(mode: Int64): SurfaceStyle {
    let shadow = if (mode == 2) { Color.rgba(16, 24, 40, 12) } else { Color.rgba(0, 0, 0, 70) }
    SurfaceStyle(cardBg(mode), border: cardEdge(mode), borderWidth: 1.0, radius: 18.0,
        shadow: shadow, shadowOffsetY: 5.0)
}

/** 封面容器样式：描边 + 投影，让封面浮起。 */
func coverFrameStyle(mode: Int64): SurfaceStyle {
    let shadow = if (mode == 2) { Color.rgba(16, 24, 40, 20) } else { Color.rgba(0, 0, 0, 110) }
    SurfaceStyle(Color.rgba(0, 0, 0, 0),
        border: cardEdge(mode), borderWidth: 1.0, radius: 10.0,
        shadow: shadow, shadowOffsetY: 6.0)
}

/** 胶囊键样式（返回键）：透明底圆胶囊。 */
let PILL_BUTTON_STYLE: SurfaceStyle = SurfaceStyle(Color.rgba(0, 0, 0, 0), radius: 999.0)

/** 收藏键样式：品牌色低透明底圆胶囊。 */
let FAV_BUTTON_STYLE: SurfaceStyle = SurfaceStyle(BRAND_SOFT_BG, radius: 999.0)

/** 危险/错误提示文字色。 */
let DANGER_TEXT: Color = Color.rgb(248, 113, 113)

/** 透明表面（导航键 / 窗口控制键的底，圆角由样式给）。 */
let CLEAR_SURFACE: Color = Color.rgba(0, 0, 0, 0)

/** 透明表面样式：侧栏导航键。 */
let RAIL_BUTTON_STYLE: SurfaceStyle = SurfaceStyle(Color.rgba(0, 0, 0, 0), radius: 10.0)

/** 透明表面样式：侧栏底部动作键。 */
let ACTION_BUTTON_STYLE: SurfaceStyle = SurfaceStyle(Color.rgba(0, 0, 0, 0), radius: 9.0)

/** 透明表面样式：窗口控制三键。 */
let WINDOW_BUTTON_STYLE: SurfaceStyle = SurfaceStyle(Color.rgba(0, 0, 0, 0), radius: 6.0)

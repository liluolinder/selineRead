/*
 * 浏览器主题：清爽浅色 + 蓝色强调（文件夹图标与面包屑链接用强调色）。令牌集中于此。
 */
package chui_explorer

import chui.{Color, Theme}

// 文件夹图标色，视图直接引用。
let EXPLORER_FOLDER: Color = Color.rgb(72, 120, 224)

// 文件图标与右侧箭头的弱化色（与主题 mutedText 一致）。
let EXPLORER_MUTED: Color = Color.rgb(120, 127, 140)

func explorerTheme(): Theme {
    Theme(
        bg: Color.rgb(242, 244, 248),
        panel: Color.rgb(255, 255, 255),
        panelEdge: Color.rgb(224, 228, 234),
        text: Color.rgb(30, 35, 44),
        mutedText: Color.rgb(120, 127, 140),
        accent: Color.rgb(60, 110, 224),
        accentText: Color.rgb(255, 255, 255),
        danger: Color.rgb(206, 74, 68),
        field: Color.rgb(247, 249, 252),
        fieldActive: Color.rgb(235, 241, 250),
        panelRaised: Color.rgb(252, 253, 255),
        accentSoft: Color.rgb(224, 233, 250),
        shadow: Color.rgba(28, 40, 66, 20),
        radius: 12.0,
        controlRadius: 9.0
    )
}

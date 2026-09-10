/*
 * 文件浏览器主题：中性冷灰配色 + 青蓝强调色，贴近代码编辑器的资源管理器观感。令牌集中于此。
 */
package chui_file_explorer

import chui.{Color, Length, LengthUnits, Theme}

/** 应用主标题字号。 */
let EXPLORER_TITLE: Length = 20.fp

func explorerTheme(): Theme {
    Theme(
        bg: Color.rgb(240, 242, 245),
        panel: Color.rgb(255, 255, 255),
        panelEdge: Color.rgb(218, 223, 230),
        text: Color.rgb(30, 35, 43),
        mutedText: Color.rgb(112, 122, 136),
        accent: Color.rgb(30, 140, 170),
        accentText: Color.rgb(255, 255, 255),
        danger: Color.rgb(206, 74, 68),
        field: Color.rgb(247, 249, 251),
        fieldActive: Color.rgb(232, 244, 248),
        panelRaised: Color.rgb(255, 255, 255),
        accentSoft: Color.rgb(222, 240, 245),
        shadow: Color.rgba(24, 42, 52, 26),
        radius: 12.0,
        controlRadius: 9.0
    )
}

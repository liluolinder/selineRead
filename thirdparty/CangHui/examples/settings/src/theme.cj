/*
 * 设置主题：中性浅色 + 靛蓝强调。令牌集中于此。
 */
package chui_settings

import chui.{Color, Theme}

func settingsTheme(): Theme {
    Theme(
        bg: Color.rgb(236, 238, 243),
        panel: Color.rgb(255, 255, 255),
        panelEdge: Color.rgb(220, 224, 232),
        text: Color.rgb(30, 34, 44),
        mutedText: Color.rgb(116, 122, 138),
        accent: Color.rgb(74, 100, 208),
        accentText: Color.rgb(255, 255, 255),
        danger: Color.rgb(206, 74, 68),
        field: Color.rgb(244, 246, 250),
        fieldActive: Color.rgb(234, 238, 249),
        panelRaised: Color.rgb(255, 255, 255),
        accentSoft: Color.rgb(226, 232, 250),
        shadow: Color.rgba(30, 38, 66, 24),
        radius: 12.0,
        controlRadius: 9.0
    )
}

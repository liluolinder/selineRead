/*
 * 字体加载主题：素净的浅灰纸面 + 近墨文字 + 石青强调（选中的字体分段）。令牌集中于此。
 */
package chui_fonts

import chui.{Color, Theme}

func fontsTheme(): Theme {
    Theme(
        bg: Color.rgb(244, 245, 247),
        panel: Color.rgb(255, 255, 255),
        panelEdge: Color.rgb(226, 229, 233),
        text: Color.rgb(28, 32, 38),
        mutedText: Color.rgb(120, 128, 138),
        accent: Color.rgb(46, 116, 156), // accent（石青）
        accentText: Color.rgb(255, 255, 255),
        danger: Color.rgb(200, 78, 66),
        field: Color.rgb(242, 244, 247),
        fieldActive: Color.rgb(224, 236, 244),
        panelRaised: Color.rgb(255, 255, 255),
        accentSoft: Color.rgb(220, 234, 243),
        shadow: Color.rgba(30, 40, 54, 20),
        radius: 12.0,
        controlRadius: 9.0
    )
}

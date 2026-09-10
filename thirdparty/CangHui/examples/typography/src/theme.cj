/*
 * 字体样式主题：编辑排版风的暖白纸面 + 近墨色文字 + 靛蓝强调（选中的样式 Chip）。令牌集中于此。
 */
package chui_typography

import chui.{Color, Theme}

func typographyTheme(): Theme {
    Theme(
        bg: Color.rgb(247, 245, 240), // bg（暖白纸）
        panel: Color.rgb(255, 254, 251),
        panelEdge: Color.rgb(228, 224, 214),
        text: Color.rgb(30, 30, 34), // text（近墨）
        mutedText: Color.rgb(124, 120, 112),
        accent: Color.rgb(74, 88, 168), // accent（靛蓝）
        accentText: Color.rgb(255, 255, 255),
        danger: Color.rgb(198, 78, 66),
        field: Color.rgb(244, 242, 236),
        fieldActive: Color.rgb(232, 234, 246),
        panelRaised: Color.rgb(255, 255, 255),
        accentSoft: Color.rgb(226, 229, 244),
        shadow: Color.rgba(40, 38, 30, 22),
        radius: 12.0,
        controlRadius: 9.0
    )
}

/*
 * 追踪器主题：清爽浅色 + 靛蓝强调。语义色（成功/警告/危险）由 Badge 自带，不在此。令牌集中于此。
 */
package chui_tracker

import chui.{Color, Theme}

func trackerTheme(): Theme {
    Theme(
        bg: Color.rgb(243, 244, 247),
        panel: Color.rgb(255, 255, 255),
        panelEdge: Color.rgb(224, 227, 233),
        text: Color.rgb(30, 34, 42),
        mutedText: Color.rgb(118, 125, 138),
        accent: Color.rgb(84, 96, 220),
        accentText: Color.rgb(255, 255, 255),
        danger: Color.rgb(208, 76, 70),
        field: Color.rgb(247, 248, 251),
        fieldActive: Color.rgb(236, 238, 250),
        panelRaised: Color.rgb(252, 253, 255),
        accentSoft: Color.rgb(228, 231, 250),
        shadow: Color.rgba(28, 34, 66, 20),
        radius: 12.0,
        controlRadius: 9.0
    )
}

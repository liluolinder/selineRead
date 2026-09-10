/*
 * 目标主题：清爽浅色 + 青绿强调（进度环用强调色）。令牌集中于此。
 */
package chui_goals

import chui.{Color, Theme}

func goalsTheme(): Theme {
    Theme(
        bg: Color.rgb(242, 245, 244),
        panel: Color.rgb(255, 255, 255),
        panelEdge: Color.rgb(224, 229, 227),
        text: Color.rgb(28, 36, 34),
        mutedText: Color.rgb(116, 126, 124),
        accent: Color.rgb(22, 158, 130), // accent（青绿）
        accentText: Color.rgb(255, 255, 255),
        danger: Color.rgb(206, 74, 68),
        field: Color.rgb(246, 250, 249),
        fieldActive: Color.rgb(230, 244, 240),
        panelRaised: Color.rgb(252, 255, 254),
        accentSoft: Color.rgb(214, 240, 233),
        shadow: Color.rgba(20, 48, 42, 20),
        radius: 12.0,
        controlRadius: 9.0
    )
}

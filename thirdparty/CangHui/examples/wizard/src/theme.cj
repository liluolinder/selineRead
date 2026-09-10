/*
 * 向导主题：清爽浅色 + 靛蓝强调。令牌集中于此。
 */
package chui_wizard

import chui.{Color, Theme}

/** 校验提示的警示文字色，视图直接引用。 */
let WIZARD_DANGER: Color = Color.rgb(206, 74, 68)

func wizardTheme(): Theme {
    Theme(
        bg: Color.rgb(238, 240, 245),
        panel: Color.rgb(255, 255, 255),
        panelEdge: Color.rgb(220, 224, 232),
        text: Color.rgb(30, 34, 44),
        mutedText: Color.rgb(118, 124, 138),
        accent: Color.rgb(74, 104, 210),
        accentText: Color.rgb(255, 255, 255),
        danger: Color.rgb(206, 74, 68),
        field: Color.rgb(246, 248, 251),
        fieldActive: Color.rgb(235, 240, 250),
        panelRaised: Color.rgb(255, 255, 255),
        accentSoft: Color.rgb(226, 232, 250),
        shadow: Color.rgba(30, 38, 66, 24),
        radius: 12.0,
        controlRadius: 9.0
    )
}

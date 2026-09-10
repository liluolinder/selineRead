/*
 * 折叠问答主题：清爽浅色，卡片式问答条目。令牌集中于此。
 */
package chui_disclosure

import chui.{Color, Theme}

func disclosureTheme(): Theme {
    Theme(
        bg: Color.rgb(243, 245, 249),
        panel: Color.rgb(255, 255, 255),
        panelEdge: Color.rgb(226, 230, 237),
        text: Color.rgb(28, 34, 44),
        mutedText: Color.rgb(118, 128, 142),
        accent: Color.rgb(76, 110, 190),
        accentText: Color.rgb(255, 255, 255),
        danger: Color.rgb(204, 78, 66),
        field: Color.rgb(240, 243, 248),
        fieldActive: Color.rgb(226, 234, 248),
        panelRaised: Color.rgb(255, 255, 255),
        accentSoft: Color.rgb(224, 232, 250),
        shadow: Color.rgba(30, 42, 66, 22),
        radius: 12.0,
        controlRadius: 9.0
    )
}

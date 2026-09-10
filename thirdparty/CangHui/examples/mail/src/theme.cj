/*
 * 邮件客户端主题：冷灰底、信笺蓝强调的商务浅色。
 */
package chui_mail

import chui.{Color, Theme}

func mailTheme(): Theme {
    Theme(
        bg: Color.rgb(241, 244, 248),
        panel: Color.rgb(255, 255, 255),
        panelEdge: Color.rgb(222, 228, 236),
        text: Color.rgb(24, 32, 44),
        mutedText: Color.rgb(108, 120, 136),
        accent: Color.rgb(46, 104, 200),
        accentText: Color.rgb(255, 255, 255),
        danger: Color.rgb(200, 70, 62),
        field: Color.rgb(246, 248, 251),
        fieldActive: Color.rgb(234, 240, 248),
        panelRaised: Color.rgb(255, 255, 255),
        accentSoft: Color.rgb(226, 236, 250),
        shadow: Color.rgba(24, 40, 66, 24),
        radius: 12.0,
        controlRadius: 9.0
    )
}

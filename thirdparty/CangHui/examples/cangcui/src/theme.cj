/*
 * 画卷窗口主题：绢本底色与黛墨文字（画面自绘设色，主题只托底）。
 */
package chui_cangcui

import chui.{Color, Theme}

func cangcuiTheme(): Theme {
    Theme(
        bg: Color.rgb(238, 227, 194),
        panel: Color.rgb(243, 233, 203),
        panelEdge: Color.rgb(216, 200, 158),
        text: Color.rgb(35, 66, 58),
        mutedText: Color.rgb(118, 122, 100),
        accent: Color.rgb(53, 121, 91),
        accentText: Color.rgb(245, 240, 224),
        danger: Color.rgb(176, 58, 42),
        field: Color.rgb(233, 221, 186),
        fieldActive: Color.rgb(226, 212, 172),
        panelRaised: Color.rgb(243, 233, 203),
        accentSoft: Color.rgb(214, 226, 205),
        shadow: Color.rgba(70, 74, 48, 26),
        radius: 10.0,
        controlRadius: 8.0
    )
}

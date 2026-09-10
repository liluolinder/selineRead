/*
 * 番茄钟主题：暖白底、番茄红强调，休息用色由视图从主题派生。
 */
package chui_pomodoro

import chui.{Color, Theme}

func pomodoroTheme(): Theme {
    Theme(
        bg: Color.rgb(248, 245, 242),
        panel: Color.rgb(255, 254, 252),
        panelEdge: Color.rgb(232, 226, 219),
        text: Color.rgb(41, 34, 30),
        mutedText: Color.rgb(140, 129, 120),
        accent: Color.rgb(214, 82, 68),
        accentText: Color.rgb(255, 253, 251),
        danger: Color.rgb(196, 66, 54),
        field: Color.rgb(246, 242, 237),
        fieldActive: Color.rgb(240, 232, 224),
        panelRaised: Color.rgb(255, 254, 252),
        accentSoft: Color.rgb(248, 224, 219),
        shadow: Color.rgba(90, 62, 48, 22),
        radius: 14.0,
        controlRadius: 10.0
    )
}

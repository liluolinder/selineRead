/*
 * 缓动示例主题：深色画布，青蓝强调（轨道标记与进度）。深色更凸显运动。令牌集中于此。
 */
package chui_motion

import chui.{Color, Theme}

func motionTheme(): Theme {
    Theme(
        bg: Color.rgb(24, 27, 34),
        panel: Color.rgb(32, 36, 45),
        panelEdge: Color.rgb(48, 54, 66),
        text: Color.rgb(232, 236, 243),
        mutedText: Color.rgb(150, 158, 172),
        accent: Color.rgb(88, 166, 232), // accent（青蓝）
        accentText: Color.rgb(16, 20, 28),
        danger: Color.rgb(226, 96, 88),
        field: Color.rgb(38, 43, 54),
        fieldActive: Color.rgb(52, 74, 100),
        panelRaised: Color.rgb(40, 45, 56),
        accentSoft: Color.rgb(70, 120, 170),
        shadow: Color.rgba(0, 0, 0, 60),
        radius: 12.0,
        controlRadius: 9.0
    )
}

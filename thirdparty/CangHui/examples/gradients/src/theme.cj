/*
 * 渐变示例主题：深色画布，让明亮渐变更醒目。令牌集中于此。
 */
package chui_gradients

import chui.{Color, Theme}

func gradientsTheme(): Theme {
    Theme(
        bg: Color.rgb(22, 24, 32),
        panel: Color.rgb(31, 34, 44),
        panelEdge: Color.rgb(46, 50, 62),
        text: Color.rgb(233, 236, 243),
        mutedText: Color.rgb(150, 158, 172),
        accent: Color.rgb(126, 150, 240),
        accentText: Color.rgb(16, 18, 26),
        danger: Color.rgb(230, 96, 96),
        field: Color.rgb(38, 42, 54),
        fieldActive: Color.rgb(54, 72, 112),
        panelRaised: Color.rgb(38, 42, 54),
        accentSoft: Color.rgb(70, 92, 150),
        shadow: Color.rgba(0, 0, 0, 70),
        radius: 14.0,
        controlRadius: 9.0
    )
}

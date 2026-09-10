/*
 * 计算器的暗色主题与三类键面样式。
 */
package chui_calculator

import chui.{Color, SurfaceStyle, Theme}

func calculatorTheme(): Theme {
    Theme(
        bg: Color.rgb(23, 25, 31),
        panel: Color.rgb(31, 35, 44),
        panelEdge: Color.rgb(72, 78, 92),
        text: Color.rgb(246, 248, 252),
        mutedText: Color.rgb(159, 168, 184),
        accent: Color.rgb(106, 168, 255),
        accentText: Color.rgb(10, 20, 34),
        danger: Color.rgb(255, 117, 117),
        field: Color.rgb(40, 45, 56),
        fieldActive: Color.rgb(47, 58, 76),
        panelRaised: Color.rgb(45, 51, 64),
        accentSoft: Color.rgb(39, 66, 104),
        shadow: Color.rgba(0, 0, 0, 84),
        radius: 18.0,
        controlRadius: 14.0
    )
}

func displaySurface(): SurfaceStyle {
    SurfaceStyle(
        Color.rgb(16, 19, 25),
        border: Color.rgb(61, 70, 86),
        radius: 18.0,
        borderWidth: 1.0,
        shadow: Color.rgba(0, 0, 0, 70),
        shadowOffsetY: 3.0
    )
}

func operatorKeySurface(): SurfaceStyle {
    SurfaceStyle(
        Color.rgb(255, 159, 67),
        border: Color.rgb(255, 178, 104),
        radius: 14.0,
        borderWidth: 1.0,
        shadow: Color.rgba(255, 159, 67, 30),
        shadowOffsetY: 2.0
    )
}

func functionKeySurface(): SurfaceStyle {
    SurfaceStyle(
        Color.rgb(61, 68, 82),
        border: Color.rgb(82, 92, 110),
        radius: 14.0,
        borderWidth: 1.0,
        shadow: Color.rgba(0, 0, 0, 36),
        shadowOffsetY: 1.0
    )
}

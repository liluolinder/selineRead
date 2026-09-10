/*
 * 专注规划台的紫罗兰主题、卡片表面与共享字号令牌。
 */
package chui_planner

import chui.{Color, Length, LengthUnits, SurfaceStyle, Theme}

/** 区块小标题字号：比正文醒目、比页面标题克制。 */
let PLANNER_HEADING: Length = 17.fp

func plannerTheme(): Theme {
    Theme(
        bg: Color.rgb(244, 245, 251),
        panel: Color.rgb(255, 255, 255),
        panelEdge: Color.rgb(217, 219, 232),
        text: Color.rgb(33, 35, 48),
        mutedText: Color.rgb(103, 107, 126),
        accent: Color.rgb(91, 79, 207),
        accentText: Color.rgb(255, 255, 255),
        danger: Color.rgb(205, 67, 87),
        field: Color.rgb(249, 249, 253),
        fieldActive: Color.rgb(238, 236, 255),
        panelRaised: Color.rgb(255, 255, 255),
        accentSoft: Color.rgb(235, 232, 255),
        shadow: Color.rgba(32, 35, 55, 24),
        radius: 16.0,
        controlRadius: 11.0
    )
}

func softCard(): SurfaceStyle {
    SurfaceStyle(Color.rgb(251, 251, 254), border: Color.rgb(224, 225, 236), radius: 14.0, borderWidth: 1.0)
}

func accentCard(): SurfaceStyle {
    SurfaceStyle(
        Color.rgb(242, 240, 255),
        border: Color.rgb(196, 188, 244),
        radius: 16.0,
        borderWidth: 1.0,
        shadow: Color.rgba(91, 79, 207, 22),
        shadowOffsetY: 2.0
    )
}

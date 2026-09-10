/*
 * 骨架屏示例主题：清爽浅色；field 与 fieldActive 兼作骨架呼吸的基色与亮色。令牌集中于此。
 */
package chui_skeleton

import chui.{Color, Theme}

func skeletonTheme(): Theme {
    Theme(
        bg: Color.rgb(244, 246, 250),
        panel: Color.rgb(255, 255, 255),
        panelEdge: Color.rgb(228, 232, 239),
        text: Color.rgb(28, 34, 44),
        mutedText: Color.rgb(120, 130, 144),
        accent: Color.rgb(64, 108, 220),
        accentText: Color.rgb(255, 255, 255),
        danger: Color.rgb(204, 78, 66),
        field: Color.rgb(232, 236, 243), // field（骨架基色）
        fieldActive: Color.rgb(217, 224, 235), // fieldActive（骨架呼吸亮色）
        panelRaised: Color.rgb(255, 255, 255),
        accentSoft: Color.rgb(224, 232, 250),
        shadow: Color.rgba(30, 42, 66, 22),
        radius: 12.0,
        controlRadius: 9.0
    )
}

/*
 * 发布说明主题：纸白编辑排版风，墨色正文、蓝色链接；内联代码样式的墨色与底灰在此集中。
 */
package chui_richtext

import chui.{Color, Theme}

func richtextTheme(): Theme {
    Theme(
        bg: Color.rgb(244, 246, 250),
        panel: Color.rgb(255, 255, 255),
        panelEdge: Color.rgb(224, 229, 237),
        text: Color.rgb(24, 30, 40),
        mutedText: Color.rgb(112, 123, 140),
        accent: Color.rgb(58, 106, 214),
        accentText: Color.rgb(255, 255, 255),
        danger: Color.rgb(196, 72, 60),
        field: Color.rgb(243, 245, 249),
        fieldActive: Color.rgb(230, 236, 246),
        panelRaised: Color.rgb(255, 255, 255),
        accentSoft: Color.rgb(226, 236, 252),
        shadow: Color.rgba(24, 36, 58, 24),
        radius: 14.0,
        controlRadius: 10.0
    )
}

// 内联代码片段的墨色与底灰（等价 <code> 的视觉），以及议题链接色（同主题 accent）。
let CODE_INK = Color.rgb(52, 64, 88)
let CODE_BG = Color.rgb(238, 241, 247)
let LINK_COLOR = Color.rgb(58, 106, 214)

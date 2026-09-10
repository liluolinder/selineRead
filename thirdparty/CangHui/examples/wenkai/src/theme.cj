/*
 * 样本册主题：米白纸感底、墨色文字、朱砂点缀——衬楷体的书卷气。令牌集中于此。
 */
package chui_wenkai

import chui.{Color, Theme}

func wenkaiTheme(): Theme {
    Theme(
        bg: Color.rgb(247, 244, 237), // bg（米白纸）
        panel: Color.rgb(253, 251, 246),
        panelEdge: Color.rgb(228, 222, 208),
        text: Color.rgb(43, 38, 32), // text（墨色）
        mutedText: Color.rgb(139, 129, 114), // mutedText（淡墨）
        accent: Color.rgb(166, 77, 60), // accent（朱砂）
        accentText: Color.rgb(253, 251, 246),
        danger: Color.rgb(166, 77, 60),
        field: Color.rgb(240, 235, 224),
        fieldActive: Color.rgb(233, 226, 212),
        panelRaised: Color.rgb(253, 251, 246),
        accentSoft: Color.rgb(238, 224, 216),
        shadow: Color.rgba(84, 70, 50, 20),
        radius: 10.0,
        controlRadius: 8.0
    )
}

// 朱砂标题色。
let INK_ACCENT = Color.rgb(166, 77, 60)

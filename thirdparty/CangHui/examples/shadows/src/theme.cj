/*
 * 阴影对比示例主题：中性浅灰底——阴影在无彩底上最易读。令牌集中于此。
 */
package chui_shadows

import chui.{Color, Theme}

func shadowsTheme(): Theme {
    Theme(
        bg: Color.rgb(241, 242, 245),
        panel: Color.rgb(255, 255, 255),
        panelEdge: Color.rgb(226, 228, 233),
        text: Color.rgb(30, 33, 39),
        mutedText: Color.rgb(122, 128, 138),
        accent: Color.rgb(72, 100, 190),
        accentText: Color.rgb(255, 255, 255),
        danger: Color.rgb(200, 82, 70),
        field: Color.rgb(238, 240, 244),
        fieldActive: Color.rgb(228, 232, 240),
        panelRaised: Color.rgb(255, 255, 255),
        accentSoft: Color.rgb(224, 230, 245),
        shadow: Color.rgba(32, 38, 52, 20),
        radius: 12.0,
        controlRadius: 9.0
    )
}

let CARD_BG = Color.rgb(255, 255, 255)

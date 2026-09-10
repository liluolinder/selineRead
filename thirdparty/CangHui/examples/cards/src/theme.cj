/*
 * 样式卡片主题：柔和浅灰背景，让白卡片的阴影、圆角与边框清晰可见。令牌集中于此。
 */
package chui_cards

import chui.{Color, Theme}

func cardsTheme(): Theme {
    Theme(
        bg: Color.rgb(236, 239, 244), // bg（浅灰，凸显白卡阴影）
        panel: Color.rgb(255, 255, 255),
        panelEdge: Color.rgb(222, 227, 234),
        text: Color.rgb(30, 36, 46),
        mutedText: Color.rgb(120, 130, 144),
        accent: Color.rgb(72, 112, 196),
        accentText: Color.rgb(255, 255, 255),
        danger: Color.rgb(204, 78, 66),
        field: Color.rgb(240, 243, 248),
        fieldActive: Color.rgb(226, 234, 248),
        panelRaised: Color.rgb(255, 255, 255),
        accentSoft: Color.rgb(222, 232, 250),
        shadow: Color.rgba(30, 42, 66, 26),
        radius: 12.0,
        controlRadius: 9.0
    )
}

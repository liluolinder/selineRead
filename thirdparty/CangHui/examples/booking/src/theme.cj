/*
 * 预订主题：温暖的米色纸面 + 松绿强调色，贴近酒店预订的沉静观感。令牌集中于此。
 */
package chui_booking

import chui.{Color, Length, LengthUnits, Theme}

/** 应用主标题字号。 */
let BOOKING_TITLE: Length = 20.fp

/** 强调（成功）与警示文字色，视图直接引用，避免在视图层重复取主题。 */
let BOOKING_ACCENT: Color = Color.rgb(46, 138, 106)
let BOOKING_DANGER: Color = Color.rgb(198, 84, 66)

func bookingTheme(): Theme {
    Theme(
        bg: Color.rgb(244, 242, 236),
        panel: Color.rgb(255, 255, 255),
        panelEdge: Color.rgb(224, 220, 210),
        text: Color.rgb(34, 38, 34),
        mutedText: Color.rgb(116, 120, 112),
        accent: Color.rgb(46, 138, 106),
        accentText: Color.rgb(255, 255, 255),
        danger: Color.rgb(198, 84, 66),
        field: Color.rgb(248, 248, 244),
        fieldActive: Color.rgb(234, 244, 238),
        panelRaised: Color.rgb(255, 255, 255),
        accentSoft: Color.rgb(224, 240, 232),
        shadow: Color.rgba(40, 50, 40, 26),
        radius: 13.0,
        controlRadius: 9.0
    )
}

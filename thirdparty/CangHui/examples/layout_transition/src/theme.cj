package chui_layout_transition

import chui.{Color, Theme}

func layoutTransitionTheme(): Theme {
    Theme(
        bg: Color.rgb(14, 20, 30),
        panel: Color.rgb(23, 31, 44),
        panelEdge: Color.rgb(47, 61, 79),
        text: Color.rgb(238, 243, 250),
        mutedText: Color.rgb(151, 166, 186),
        accent: Color.rgb(112, 171, 255),
        accentText: Color.rgb(10, 22, 38),
        danger: Color.rgb(241, 106, 117),
        field: Color.rgb(18, 26, 38),
        fieldActive: Color.rgb(34, 49, 69),
        panelRaised: Color.rgb(29, 39, 54),
        accentSoft: Color.rgb(28, 52, 82),
        shadow: Color.rgba(0, 0, 0, 90),
        radius: 14.0,
        controlRadius: 10.0
    )
}

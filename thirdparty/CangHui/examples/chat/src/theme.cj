/*
 * 聊天主题：柔和的浅蓝底 + 蓝色气泡。气泡、头像与文字色作为令牌供视图直接引用。
 */
package chui_chat

import chui.{Color, Theme}

/** 气泡背景与文字色：我方（右、蓝底白字）与对方（左、白底深字）。 */
let CHAT_MINE_BG: Color = Color.rgb(64, 120, 240)
let CHAT_MINE_TEXT: Color = Color.rgb(255, 255, 255)
let CHAT_OTHER_BG: Color = Color.rgb(255, 255, 255)
let CHAT_OTHER_TEXT: Color = Color.rgb(32, 36, 46)
let CHAT_OTHER_EDGE: Color = Color.rgb(224, 228, 236)

/** 顶栏与输入栏底色（与消息区拉开一层）。 */
let CHAT_BAR_BG: Color = Color.rgb(252, 253, 255)

/** 头像底色按发送者区分，白色首字居中（群头像用强调蓝）。 */
let CHAT_GROUP_AVATAR: Color = Color.rgb(64, 120, 240)

func senderAvatarColor(sender: String): Color {
    if (sender == MY_SENDER) {
        Color.rgb(64, 120, 240)
    } else if (sender == "Ada") {
        Color.rgb(122, 104, 216)
    } else {
        Color.rgb(58, 166, 120)
    }
}

func chatTheme(): Theme {
    Theme(
        bg: Color.rgb(234, 238, 245), // bg（消息区底色）
        panel: Color.rgb(244, 246, 250),
        panelEdge: Color.rgb(220, 224, 232),
        text: Color.rgb(32, 36, 46),
        mutedText: Color.rgb(120, 126, 140),
        accent: Color.rgb(64, 120, 240),
        accentText: Color.rgb(255, 255, 255),
        danger: Color.rgb(206, 74, 68),
        field: Color.rgb(255, 255, 255),
        fieldActive: Color.rgb(238, 242, 252),
        panelRaised: Color.rgb(252, 253, 255), // 顶栏与输入栏底色
        accentSoft: Color.rgb(224, 233, 252),
        shadow: Color.rgba(30, 44, 80, 24),
        radius: 12.0,
        controlRadius: 10.0
    )
}

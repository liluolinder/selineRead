/*
 * 逐角圆角示例的类型化数据与纯造型逻辑。
 *
 * 消息只区分“我”与“对方”；纯函数 bubbleCorners 依此产出气泡的四角半径——整体圆润，唯独发送者一侧的下角
 * 收成小尾角（经典不对称聊天气泡：我的尾角在右下，对方的在左下）。造型与视图分离，故可单测。
 */
package chui_corners

import chui.Corners

// 一条消息：文本 + 是否为“我”发出。
struct Message {
    let text: String
    let fromMe: Bool

    init(text: String, fromMe!: Bool = false) {
        this.text = text
        this.fromMe = fromMe
    }
}

func seedMessages(): Array<Message> {
    [
        Message("这版气泡的四个角能分别设半径了？"),
        Message("能。三个角圆润，只有下角收窄。", fromMe: true),
        Message("所以尾角是朝着说话人那边的。"),
        Message("对，我的在右下、你的在左下——视线自然落回发送者。", fromMe: true),
        Message("底部输入条只圆上面两角。"),
        Message("那是 Corners.top(16)。调上方 Stepper 试试。", fromMe: true)
    ]
}

// 一个气泡的四角：整体取 radius，唯独发送者一侧的下角取 tail。
// 我的消息尾角在右下，对方的在左下。
func bubbleCorners(fromMe: Bool, radius: Float32, tail: Float32): Corners {
    if (fromMe) {
        Corners(topLeft: radius, topRight: radius, bottomRight: tail, bottomLeft: radius)
    } else {
        Corners(topLeft: radius, topRight: radius, bottomRight: radius, bottomLeft: tail)
    }
}

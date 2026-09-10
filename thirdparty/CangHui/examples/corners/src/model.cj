/*
 * 逐角圆角示例状态：消息列表、输入草稿、可调的圆角与尾角。
 *
 * 消息用整表替换触发更新（发送即追加一条“我”的消息）；radius/tail 由 Stepper 绑定，改动即刻反映到每个气泡的
 * 四角造型上——这正是本示例要演示的：四角各自取值。
 */
package chui_corners

import std.collection.ArrayList
import chui.{Corners, State}

class CornersModel {
    let messages: State<Array<Message>>
    let draft = State<String>("")
    // 气泡整体圆角与尾角半径（vp），由 Stepper 绑定。
    let radius = State<Int64>(16)
    let tail = State<Int64>(4)

    init() {
        this.messages = State<Array<Message>>(seedMessages())
    }

    /** 发送草稿：非空则追加一条“我”的消息并清空输入。 */
    func send(): Unit {
        let text = draft.value.trimAscii()
        if (text.isEmpty()) {
            return
        }
        let appended = ArrayList<Message>()
        for (message in messages.value) {
            appended.add(message)
        }
        appended.add(Message(text, fromMe: true))
        messages.value = appended.toArray()
        draft.value = ""
    }

    /** 当前圆角设置下，某条消息的气泡四角。 */
    func cornersFor(message: Message): Corners {
        bubbleCorners(message.fromMe, Float32(radius.value), Float32(tail.value))
    }
}

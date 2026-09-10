package chui_corners

@Test
func bubbleCornersSquaresTheSenderSideTail(): Unit {
    // 我方气泡：尾角在右下，其余三角取整体圆角。
    let mine = bubbleCorners(true, 16.0, 4.0)
    @Expect(mine.bottomRight == Float32(4.0))
    @Expect(mine.bottomLeft == Float32(16.0))
    @Expect(mine.topLeft == Float32(16.0))
    @Expect(mine.topRight == Float32(16.0))
    // 对方气泡：尾角改在左下，右下恢复圆角——两者互为镜像。
    let other = bubbleCorners(false, 16.0, 4.0)
    @Expect(other.bottomLeft == Float32(4.0))
    @Expect(other.bottomRight == Float32(16.0))
    @Expect(other.topLeft == Float32(16.0))
    @Expect(other.topRight == Float32(16.0))
}

@Test
func bubbleCornersFollowsRadiusAndTail(): Unit {
    // 尾角等于圆角时，四角一致（退化为普通圆角气泡）。
    let even = bubbleCorners(true, 10.0, 10.0)
    @Expect(even.topLeft == even.bottomRight)
    @Expect(even.bottomLeft == even.topRight)
    // 全零即直角矩形。
    let square = bubbleCorners(false, 0.0, 0.0)
    @Expect(square.topLeft == Float32(0.0))
    @Expect(square.bottomLeft == Float32(0.0))
}

@Test
func seedMessagesMixesBothSides(): Unit {
    let seeded = seedMessages()
    @Expect(seeded.size > 0)
    // 种子对话两边都有，故两种尾角朝向在首屏都能看到。
    var mine = false
    var other = false
    for (message in seeded) {
        if (message.fromMe) {
            mine = true
        } else {
            other = true
        }
    }
    @Expect(mine)
    @Expect(other)
}

@Test
func sendAppendsMyMessageAndClearsDraft(): Unit {
    let model = CornersModel()
    let before = model.messages.value.size
    model.draft.value = "  发出去  "
    model.send()
    // 追加一条“我”的消息，并清空草稿（文本已去除首尾空白）。
    @Expect(model.messages.value.size, before + 1)
    let last = model.messages.value[model.messages.value.size - 1]
    @Expect(last.fromMe)
    @Expect(last.text, "发出去")
    @Expect(model.draft.value, "")
}

@Test
func sendIgnoresBlankDraft(): Unit {
    let model = CornersModel()
    let before = model.messages.value.size
    // 纯空白不发送，消息数不变。
    model.draft.value = "   "
    model.send()
    @Expect(model.messages.value.size, before)
    model.draft.value = ""
    model.send()
    @Expect(model.messages.value.size, before)
}

package chui.core

import sdl.{MouseButton, UiEvent}

@Test
func boundedMailboxFifoOrderAndTake(): Unit {
    let mailbox = BoundedMailbox<Int64>(capacity: 4)
    mailbox.push(1)
    mailbox.push(2)
    mailbox.push(3)
    @Expect(mailbox.size(), 3)
    @Expect(mailbox.take(), Some(1))
    @Expect(mailbox.take(), Some(2))
    @Expect(mailbox.take(), Some(3))
    @Expect(mailbox.take().isNone())
}

@Test
func boundedMailboxDropsOldestWhenFull(): Unit {
    let mailbox = BoundedMailbox<String>(capacity: 2)
    mailbox.push("a")
    mailbox.push("b")
    mailbox.push("c")
    @Expect(mailbox.size(), 2)
    @Expect(mailbox.drain().size, 2)
}

@Test
func boundedMailboxDrainAndClear(): Unit {
    let mailbox = BoundedMailbox<Int64>(capacity: 8)
    mailbox.push(10)
    mailbox.push(20)
    let drained = mailbox.drain()
    @Expect(drained.size, 2)
    @Expect(drained[0], 10)
    @Expect(drained[1], 20)
    @Expect(mailbox.size(), 0)
    mailbox.push(30)
    mailbox.clear()
    @Expect(mailbox.size(), 0)
}

@Test
func boundedMailboxPeekNewestWithoutRemoving(): Unit {
    let mailbox = BoundedMailbox<Int64>(capacity: 4)
    mailbox.push(7)
    mailbox.push(8)
    @Expect(mailbox.peekNewest(), Some(8))
    @Expect(mailbox.size(), 2)
}

@Test
func pointerInputBridgeCollectsDownMoveUpInOrder(): Unit {
    let bridge = PointerInputBridge(capacity: 16)
    bridge.pushDown(10.0, 20.0)
    bridge.pushMove(15.0, 25.0)
    bridge.pushMove(20.0, 30.0)
    bridge.pushUp(20.0, 30.0)
    let events = bridge.drain()
    @Expect(events.size, 4)
    match (events[0]) {
        case UiEvent.MouseDown(MouseButton.Left, x, y) =>
            @Expect(x, 10.0)
            @Expect(y, 20.0)
        case _ => @Expect(false)
    }
    match (events[1]) {
        case UiEvent.MouseMove(x, y) =>
            @Expect(x, 15.0)
            @Expect(y, 25.0)
        case _ => @Expect(false)
    }
    match (events[2]) {
        case UiEvent.MouseMove(x, y) =>
            @Expect(x, 20.0)
            @Expect(y, 30.0)
        case _ => @Expect(false)
    }
    match (events[3]) {
        case UiEvent.MouseUp(MouseButton.Left, x, y) =>
            @Expect(x, 20.0)
            @Expect(y, 30.0)
        case _ => @Expect(false)
    }
    @Expect(bridge.size(), 0)
}

@Test
func pointerInputBridgeClickExpandsToDownUp(): Unit {
    let bridge = PointerInputBridge(capacity: 8)
    bridge.pushClick(5.0, 6.0)
    let events = bridge.drain()
    @Expect(events.size, 2)
    match (events[0]) {
        case UiEvent.MouseDown(MouseButton.Left, x, y) =>
            @Expect(x, 5.0)
            @Expect(y, 6.0)
        case _ => @Expect(false)
    }
    match (events[1]) {
        case UiEvent.MouseUp(MouseButton.Left, x, y) =>
            @Expect(x, 5.0)
            @Expect(y, 6.0)
        case _ => @Expect(false)
    }
}

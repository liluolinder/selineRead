@NonProduct
features {}
package ohos_app_cangjie_entry.model

import ohos.base.Callback0Argument
import ohos.base.Callback1Argument
import ohos.base.Callback2Argument

// ---------------------------------------------------------------------------
// 回调包装：把仓颉闭包适配成 ohos.base 的 Callback*Argument 接口，
// 用于 window/stage 的 on() 监听。用法：
//   window.on(WindowCallbackType.WindowSizeChange, cb1 { size: Size => ... })
// ---------------------------------------------------------------------------

private class Cb0Impl <: Callback0Argument {
    private let fn: () -> Unit

    public init(fn: () -> Unit) {
        this.fn = fn
    }

    public override func invoke(): Unit {
        fn()
    }
}

private class Cb1Impl<A> <: Callback1Argument<A> {
    private let fn: (A) -> Unit

    public init(fn: (A) -> Unit) {
        this.fn = fn
    }

    public override func invoke(arg: A): Unit {
        fn(arg)
    }
}

private class Cb2Impl<A, B> <: Callback2Argument<A, B> {
    private let fn: (A, B) -> Unit

    public init(fn: (A, B) -> Unit) {
        this.fn = fn
    }

    public override func invoke(arg1: A, arg2: B): Unit {
        fn(arg1, arg2)
    }
}

public func cb0(fn: () -> Unit): Callback0Argument {
    Cb0Impl(fn)
}

public func cb1<A>(fn: (A) -> Unit): Callback1Argument<A> {
    Cb1Impl<A>(fn)
}

public func cb2<A, B>(fn: (A, B) -> Unit): Callback2Argument<A, B> {
    Cb2Impl<A, B>(fn)
}



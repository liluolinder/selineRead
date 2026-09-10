package chui.controls

import std.collection.ArrayList
import sdl.{Color, FontSizes, Rect, Size, UiEvent, clampF32}
import chui.core.{UiContext, Widget, emit}

private let TOAST_MARGIN: Float32 = 16.0
private let TOAST_WIDTH: Float32 = 320.0
private let TOAST_GAP: Float32 = 10.0
private let TOAST_V_PAD: Float32 = 9.0
private let TOAST_TEXT_LEFT: Float32 = 18.0
private let TOAST_TEXT_RIGHT: Float32 = 12.0
// 消息最多排成几行；超出部分以省略号收尾（卡片高度随行数自适应）。
private let TOAST_MAX_LINES: Int64 = 4
// Entrance slide/fade and exit fade durations, in milliseconds.
private let TOAST_SLIDE_MS: Float32 = 150.0
private let TOAST_FADE_MS: Float32 = 300.0

/** The kind of a toast, which sets its accent colour. */
public enum ToastKind {
    | Info
    | Success
    | Warning
    | Error
}

// One live toast: its content and the time it has been shown / has left to live.
class ActiveToast {
    let id: Int64
    let message: String
    let kind: ToastKind
    var ageMs: UInt64
    var remainingMs: UInt64
    // 断行结果缓存（懒计算，卡片宽度变化时失效），避免存活期间逐帧重新排版。
    var fittedLines: Array<String> = []
    var fittedWidth: Float32 = -1.0

    init(id: Int64, message: String, kind: ToastKind, remainingMs: UInt64) {
        this.id = id
        this.message = message
        this.kind = kind
        this.ageMs = 0
        this.remainingMs = remainingMs
    }
}

/**
 * A controller for transient toast notifications. Create one for the app's lifetime, call `show` from
 * anywhere to post a message, and place a `ToastLayer(toaster)` in the view to render and age them. Each
 * toast slides in, waits out its duration, then fades away — the `ToastLayer` drives the clock from the
 * frame loop and requests frames while any toast is alive, so the animation runs even on an otherwise
 * idle screen.
 */
public class Toaster {
    private let items = ArrayList<ActiveToast>()
    private var nextId: Int64 = 1

    /** Posts a toast that lives `durationMs` before fading out. */
    public func show(message: String, kind!: ToastKind = ToastKind.Info, durationMs!: UInt64 = 3200): Unit {
        items.add(ActiveToast(nextId, message, kind, durationMs))
        nextId += 1
    }

    /** How many toasts are currently alive. */
    public func count(): Int64 {
        items.size
    }

    // Ages every toast by `deltaMs` and drops any whose time is up. Called by the ToastLayer per frame.
    func tick(deltaMs: UInt64): Unit {
        var i = items.size - 1
        while (i >= 0) {
            let toast = items[i]
            toast.ageMs += deltaMs
            if (toast.remainingMs <= deltaMs) {
                items.remove(at: i)
            } else {
                toast.remainingMs -= deltaMs
            }
            i -= 1
        }
    }

    func snapshot(): Array<ActiveToast> {
        items.toArray()
    }

    func isEmpty(): Bool {
        items.isEmpty()
    }
}

/**
 * Renders a `Toaster`'s toasts stacked at the bottom-right of the viewport and drives their clock. Add
 * it once near the root of the tree (e.g. as the last layer of a root `ZStack`) so it draws above the
 * content; it takes no layout space and never consumes events, so it does not disturb the app beneath.
 */
public class ToastLayer <: Widget {
    private let toaster: Toaster

    public init(toaster: Toaster) {
        this.toaster = toaster
        emit(this)
    }

    public func measure(_: UiContext, _: Size): Size {
        Size.zero()
    }

    public func layout(_: UiContext, _: Rect): Unit {}

    public func participatesInLayout(): Bool {
        false
    }

    public func draw(ctx: UiContext): Unit {
        let toasts = toaster.snapshot()
        if (toasts.isEmpty()) {
            return
        }
        let width = min(TOAST_WIDTH, max(0.0, ctx.viewportWidth - TOAST_MARGIN * 2.0))
        let x = ctx.viewportWidth - TOAST_MARGIN - width
        var bottom = ctx.viewportHeight - TOAST_MARGIN
        var i = toasts.size - 1
        while (i >= 0) {
            let toast = toasts[i]
            let enter = clampF32(Float32(toast.ageMs) / TOAST_SLIDE_MS, 0.0, 1.0)
            let exit: Float32 = if (Float32(toast.remainingMs) < TOAST_FADE_MS) {
                Float32(toast.remainingMs) / TOAST_FADE_MS
            } else {
                1.0
            }
            let alpha = min(enter, exit)
            let lines = toastFittedLines(ctx, toast, width)
            let lineHeight = ctx.renderer.textHeight(pointSize: FontSizes.CONTROL)
            // 卡片高度随断行行数自适应，长通知不再被截断。
            let cardHeight = TOAST_V_PAD * 2.0 + Float32(lines.size) * lineHeight
            // Starts one slot lower and slides up into place as it enters.
            let slide = (1.0 - enter) * (cardHeight + TOAST_GAP)
            drawToast(ctx, Rect(x, bottom - cardHeight + slide, width, cardHeight), lines, toast, alpha)
            bottom = bottom - cardHeight - TOAST_GAP
            i -= 1
        }
    }

    public func handle(ctx: UiContext, event: UiEvent): Bool {
        match (event) {
            case UiEvent.Frame(info) =>
                toaster.tick(info.deltaMs)
                // Keep frames coming while toasts animate; without this the idle loop would freeze them.
                if (!toaster.isEmpty()) {
                    ctx.requestFrame()
                }
            case _ => ()
        }
        false
    }

    private func drawToast(ctx: UiContext, rect: Rect, lines: Array<String>, toast: ActiveToast,
        alpha: Float32): Unit {
        let a = Int64(clampF32(alpha, 0.0, 1.0) * 255.0)
        let accent = toastColor(ctx, toast.kind)
        // Soft shadow, card, then a coloured accent bar and the message — all faded by `alpha`.
        ctx.renderer.fillRoundedRect(rect.shift(0.0, 3.0), ctx.theme.controlRadius,
            ctx.theme.shadow.withAlpha(Int64(clampF32(alpha, 0.0, 1.0) * 40.0)))
        ctx.renderer.fillRoundedRect(rect, ctx.theme.controlRadius, ctx.theme.panelRaised.withAlpha(a))
        ctx.renderer.fillRoundedRect(Rect(rect.x + 6.0, rect.y + 8.0, 4.0, max(0.0, rect.h - 16.0)), 2.0,
            accent.withAlpha(a))
        // 消息按断行结果逐行绘制，行距与卡片高度一致；右缘裁剪防止意外溢出。
        let pointSize = FontSizes.CONTROL
        let lineHeight = ctx.renderer.textHeight(pointSize: pointSize)
        ctx.renderer.pushClip(Rect(rect.x + TOAST_TEXT_LEFT, rect.y,
            max(0.0, rect.w - TOAST_TEXT_LEFT - TOAST_TEXT_RIGHT), rect.h))
        var ty = rect.y + TOAST_V_PAD
        for (line in lines) {
            ctx.renderer.text(line, rect.x + TOAST_TEXT_LEFT, ty, ctx.theme.text.withAlpha(a),
                pointSize: pointSize)
            ty += lineHeight
        }
        ctx.renderer.popClip()
    }
}

/** 懒断行：卡片宽度不变时复用缓存，避免 toast 存活期间逐帧重复测量排版。 */
private func toastFittedLines(ctx: UiContext, toast: ActiveToast, width: Float32): Array<String> {
    if (toast.fittedWidth != width) {
        toast.fittedLines = wrapToastText(ctx, toast.message,
            max(0.0, width - TOAST_TEXT_LEFT - TOAST_TEXT_RIGHT))
        toast.fittedWidth = width
    }
    toast.fittedLines
}

/**
 * 把 toast 消息按可用宽度贪心断成最多 TOAST_MAX_LINES 行（CJK 逐字、拉丁逐字符回退）。
 * 消息里的显式 '\n' / '\r\n' 也作为断点；内容被截断时末行以 "…" 收尾。
 */
private func wrapToastText(ctx: UiContext, message: String, availableWidth: Float32): Array<String> {
    if (message.isEmpty()) {
        return [""]
    }
    let pointSize = FontSizes.CONTROL
    let ellipsis = "…"
    let runes = message.toRuneArray()
    let out = ArrayList<String>()
    var line = ArrayList<Rune>()
    var lineWidth: Float32 = 0.0
    var index: Int64 = 0
    var truncated = false
    while (index < runes.size && out.size < TOAST_MAX_LINES) {
        let r = runes[index]
        // 显式换行（\r\n 归并成一次断点）
        if (r == r'\n' || r == r'\r') {
            if (r == r'\r' && index + 1 < runes.size && runes[index + 1] == r'\n') {
                index += 1
            }
            out.add(runeLineText(line))
            line = ArrayList<Rune>()
            lineWidth = 0.0
            index += 1
            if (out.size >= TOAST_MAX_LINES) {
                truncated = index < runes.size
                break
            }
            continue
        }
        let runeWidth = ctx.renderer.textWidth(r.toString(), pointSize: pointSize)
        if (lineWidth + runeWidth > availableWidth && line.size > 0) {
            out.add(runeLineText(line))
            line = ArrayList<Rune>()
            lineWidth = 0.0
            if (out.size >= TOAST_MAX_LINES) {
                truncated = index < runes.size
                break
            }
        }
        line.add(r)
        lineWidth += runeWidth
        index += 1
    }
    if (index >= runes.size && (line.size > 0 || out.isEmpty())) {
        out.add(runeLineText(line))
    }
    if (truncated && !out.isEmpty()) {
        let last = out.remove(at: out.size - 1)
        // 末行收尾加省略号；宽度略超时由卡片右缘裁剪兜底。
        out.add(last + ellipsis)
    }
    out.toArray()
}

/** Rune 列表拼接为字符串（当前正在排的一行）。 */
private func runeLineText(runes: ArrayList<Rune>): String {
    let sb = StringBuilder()
    for (r in runes) {
        sb.append(r.toString())
    }
    sb.toString()
}

private func toastColor(ctx: UiContext, kind: ToastKind): Color {
    match (kind) {
        case ToastKind.Info => ctx.theme.accent
        case ToastKind.Success => Color.rgb(46, 160, 92)
        case ToastKind.Warning => Color.rgb(210, 150, 40)
        case ToastKind.Error => ctx.theme.danger
    }
}

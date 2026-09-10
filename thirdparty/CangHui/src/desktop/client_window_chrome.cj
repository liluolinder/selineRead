package chui.desktop

import sdl.{Color, FontStyle, MouseButton, Pen, Rect, Renderer, UiEvent}
import sdl.input.Mouse

/** Placement of client-drawn desktop controls; Hidden suits embedded/mobile hosts. */
public enum WindowChromePlacement {
    | Leading
    | Trailing
    | Hidden
}

public enum WindowChromeControl {
    | Minimize
    | MaximizeRestore
    | Close
}

/** Overridable geometry and colors for a client-drawn title bar. */
public class ClientWindowChromeStyle {
    public let placement: WindowChromePlacement
    public let height: Float32
    public let controlSize: Float32
    public let padding: Float32
    public let gap: Float32
    public let background: Color
    public let foreground: Color
    public let border: Color
    public let hover: Color
    public let pressed: Color
    public let closeHover: Color
    public let accent: Color

    public init(
        placement!: WindowChromePlacement = WindowChromePlacement.Trailing,
        height!: Float32 = 34.0,
        controlSize!: Float32 = 28.0,
        padding!: Float32 = 5.0,
        gap!: Float32 = 2.0,
        background!: Color = Color.rgb(22, 24, 24),
        foreground!: Color = Color.rgb(226, 229, 226),
        border!: Color = Color.rgba(255, 255, 255, 36),
        hover!: Color = Color.rgba(255, 255, 255, 28),
        pressed!: Color = Color.rgba(255, 255, 255, 52),
        closeHover!: Color = Color.rgb(210, 58, 58),
        accent!: Color = Color.rgb(224, 242, 28)
    ) {
        this.placement = placement
        this.height = max(0.0, height)
        this.controlSize = max(18.0, controlSize)
        this.padding = max(0.0, padding)
        this.gap = max(0.0, gap)
        this.background = background
        this.foreground = foreground
        this.border = border
        this.hover = hover
        this.pressed = pressed
        this.closeHover = closeHover
        this.accent = accent
    }

    public func titleBar(frame: Rect): Rect {
        if (isHidden()) { Rect(frame.x, frame.y, frame.w, 0.0) }
        else { Rect(frame.x, frame.y, frame.w, min(height, frame.h)) }
    }

    public func contentFrame(frame: Rect): Rect {
        let bar = titleBar(frame)
        Rect(frame.x, frame.y + bar.h, frame.w, max(0.0, frame.h - bar.h))
    }

    public func controlRect(frame: Rect, control: WindowChromeControl): Rect {
        if (isHidden()) {
            return Rect.zero()
        }
        let order = controlOrder(control)
        let bar = titleBar(frame)
        let x = match (placement) {
            case WindowChromePlacement.Leading => bar.x + padding + Float32(order) * (controlSize + gap)
            case WindowChromePlacement.Trailing => bar.right() - padding - controlSize - Float32(order) * (controlSize + gap)
            case WindowChromePlacement.Hidden => bar.x
        }
        Rect(x, bar.y + (bar.h - controlSize) / 2.0, controlSize, controlSize)
    }

    public func controlAt(frame: Rect, x: Float32, y: Float32): ?WindowChromeControl {
        if (isHidden()) { return None }
        let controls: Array<WindowChromeControl> = [
            WindowChromeControl.Minimize,
            WindowChromeControl.MaximizeRestore,
            WindowChromeControl.Close
        ]
        for (control in controls) {
            if (controlRect(frame, control).contains(x, y)) {
                return Some(control)
            }
        }
        None
    }

    public func isDragRegion(frame: Rect, x: Float32, y: Float32): Bool {
        titleBar(frame).contains(x, y) && controlAt(frame, x, y).isNone()
    }

    private func isHidden(): Bool {
        match (placement) {
            case WindowChromePlacement.Hidden => true
            case _ => false
        }
    }

    private func controlOrder(control: WindowChromeControl): Int64 {
        match (placement) {
            case WindowChromePlacement.Leading => match (control) {
                case WindowChromeControl.Close => 0
                case WindowChromeControl.Minimize => 1
                case WindowChromeControl.MaximizeRestore => 2
            }
            case WindowChromePlacement.Trailing => match (control) {
                case WindowChromeControl.Close => 0
                case WindowChromeControl.MaximizeRestore => 1
                case WindowChromeControl.Minimize => 2
            }
            case WindowChromePlacement.Hidden => 0
        }
    }
}

/**
 * Reusable controller and renderer for borderless DesktopApp windows.
 * Applications may replace the drawing entirely while retaining the same geometry/actions.
 */
public class ClientWindowChrome {
    public let style: ClientWindowChromeStyle
    private let app: DesktopApp
    private let controlPress = ClientWindowChromePressState()
    private var dragging = false
    private var dragMouseX: Float32 = 0.0
    private var dragMouseY: Float32 = 0.0
    private var dragWindowX: Int32 = 0
    private var dragWindowY: Int32 = 0

    public init(app: DesktopApp, style!: ClientWindowChromeStyle = ClientWindowChromeStyle()) {
        this.app = app
        this.style = style
    }

    public func contentFrame(frame: Rect): Rect {
        style.contentFrame(frame)
    }

    public func draw(renderer: Renderer, frame: Rect, title: String, pointerX: Float32, pointerY: Float32): Unit {
        let bar = style.titleBar(frame)
        if (bar.h <= 0.0) { return }
        renderer.fill(bar, style.background)
        renderer.strokeLine(bar.x, bar.bottom() - 0.5, bar.right(), bar.bottom() - 0.5,
            Pen(width: 1.0, color: style.border))
        let titleInset = style.padding + (style.controlSize + style.gap) * 3.0 + 8.0
        let titleX = match (style.placement) {
            case WindowChromePlacement.Leading => bar.x + titleInset
            case _ => bar.x + 13.0
        }
        renderer.fill(Rect(titleX - 8.0, bar.y + 9.0, 3.0, max(8.0, bar.h - 18.0)), style.accent)
        renderer.text(title, titleX, bar.y + (bar.h - 13.0) / 2.0 - 1.0, style.foreground,
            pointSize: 11.0, style: FontStyle(bold: true))
        drawControl(renderer, frame, WindowChromeControl.Minimize, pointerX, pointerY)
        drawControl(renderer, frame, WindowChromeControl.MaximizeRestore, pointerX, pointerY)
        drawControl(renderer, frame, WindowChromeControl.Close, pointerX, pointerY)
    }

    public func handle(event: UiEvent, frame: Rect): Bool {
        match (event) {
            case UiEvent.MouseDown(MouseButton.Left, x, y) =>
                match (style.controlAt(frame, x, y)) {
                    case Some(control) =>
                        controlPress.begin(control)
                        Mouse.capture(true)
                        true
                    case None =>
                        if (!style.isDragRegion(frame, x, y)) { return false }
                        let mouse = Mouse.globalState()
                        let position = app.windowPosition()
                        dragMouseX = mouse.x
                        dragMouseY = mouse.y
                        dragWindowX = position.x
                        dragWindowY = position.y
                        dragging = true
                        Mouse.capture(true)
                        true
                }
            case UiEvent.MouseMove(x, y) =>
                if (dragging) {
                    let mouse = Mouse.globalState()
                    app.setWindowPosition(
                        Int32(Float32(dragWindowX) + mouse.x - dragMouseX),
                        Int32(Float32(dragWindowY) + mouse.y - dragMouseY)
                    )
                    true
                } else if (controlPress.isActive()) {
                    controlPress.move(style.controlAt(frame, x, y))
                    true
                } else {
                    style.titleBar(frame).contains(x, y)
                }
            case UiEvent.MouseUp(MouseButton.Left, x, y) =>
                let released = style.controlAt(frame, x, y)
                let hadControlPress = controlPress.isActive()
                let action = controlPress.release(released)
                if (hadControlPress) {
                    Mouse.capture(false)
                }
                if (dragging) {
                    dragging = false
                    Mouse.capture(false)
                    return true
                }
                match (action) {
                    case Some(control) => activate(control)
                    case None => ()
                }
                hadControlPress || style.titleBar(frame).contains(x, y)
            case _ => false
        }
    }

    private func activate(control: WindowChromeControl): Unit {
        match (control) {
            case WindowChromeControl.Minimize => app.minimizeWindow()
            case WindowChromeControl.MaximizeRestore => app.toggleMaximizeWindow()
            case WindowChromeControl.Close => app.requestWindowClose()
        }
    }

    private func drawControl(
        renderer: Renderer,
        frame: Rect,
        control: WindowChromeControl,
        pointerX: Float32,
        pointerY: Float32
    ): Unit {
        let rect = style.controlRect(frame, control)
        if (rect.w <= 0.0) { return }
        let hovered = rect.contains(pointerX, pointerY)
        let held = controlPress.isHeld(control)
        if (held) {
            renderer.fillRoundedRect(rect, 3.0, style.pressed)
        } else if (hovered) {
            renderer.fillRoundedRect(rect, 3.0, match (control) {
                case WindowChromeControl.Close => style.closeHover
                case _ => style.hover
            })
        }
        let color = style.foreground
        let cx = rect.centerX()
        let cy = rect.centerY()
        match (control) {
            case WindowChromeControl.Minimize =>
                renderer.strokeLine(cx - 5.0, cy + 3.0, cx + 5.0, cy + 3.0,
                    Pen(width: 1.5, color: color))
            case WindowChromeControl.MaximizeRestore =>
                if (app.windowFlags().maximized) {
                    renderer.strokeRoundedRect(Rect(cx - 4.0, cy - 3.0, 8.0, 7.0), 1.0,
                        Pen(width: 1.2, color: color))
                    renderer.strokeRoundedRect(Rect(cx - 2.0, cy - 5.0, 8.0, 7.0), 1.0,
                        Pen(width: 1.2, color: color))
                } else {
                    renderer.strokeRoundedRect(Rect(cx - 5.0, cy - 5.0, 10.0, 10.0), 1.0,
                        Pen(width: 1.3, color: color))
                }
            case WindowChromeControl.Close =>
                renderer.strokeLine(cx - 4.5, cy - 4.5, cx + 4.5, cy + 4.5,
                    Pen(width: 1.5, color: color))
                renderer.strokeLine(cx + 4.5, cy - 4.5, cx - 4.5, cy + 4.5,
                    Pen(width: 1.5, color: color))
        }
    }
}

internal class ClientWindowChromePressState {
    private var pressedControl: ?WindowChromeControl = None
    private var cancelled: Bool = false

    func begin(control: WindowChromeControl): Unit {
        pressedControl = Some(control)
        cancelled = false
    }

    func move(control: ?WindowChromeControl): Unit {
        if (pressedControl.isSome() && !sameControl(pressedControl, control)) {
            cancelled = true
        }
    }

    func release(control: ?WindowChromeControl): ?WindowChromeControl {
        let accepted = pressedControl.isSome() && !cancelled && sameControl(pressedControl, control)
        var action: ?WindowChromeControl = None
        if (accepted) {
            action = pressedControl
        }
        pressedControl = None
        cancelled = false
        action
    }

    func isActive(): Bool {
        pressedControl.isSome()
    }

    func isHeld(control: WindowChromeControl): Bool {
        !cancelled && sameControl(pressedControl, Some(control))
    }
}

private func sameControl(left: ?WindowChromeControl, right: ?WindowChromeControl): Bool {
    match (left) {
        case Some(a) => match (right) {
            case Some(b) => sameConcreteControl(a, b)
            case None => false
        }
        case None => right.isNone()
    }
}

private func sameConcreteControl(left: WindowChromeControl, right: WindowChromeControl): Bool {
    match (left) {
        case WindowChromeControl.Minimize => match (right) {
            case WindowChromeControl.Minimize => true
            case _ => false
        }
        case WindowChromeControl.MaximizeRestore => match (right) {
            case WindowChromeControl.MaximizeRestore => true
            case _ => false
        }
        case WindowChromeControl.Close => match (right) {
            case WindowChromeControl.Close => true
            case _ => false
        }
    }
}

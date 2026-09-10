/*
 * 邮件列表行：两行式自绘行（发件人 + 时间 / 主题预览），未读加粗并带强调色圆点。
 *
 * 选中行铺 accentSoft 底、悬停铺 fieldActive；整行可点选中。文本各自裁剪到自身列宽，
 * 长主题在行内截断而不挤走时间列。鼠标交互沿用 explorer 的 EntryRow 惯例。
 */
package chui_mail

import chui.{CursorShape, FontSizes, FontStyle, MouseButton, Rect, Size, UiContext, UiEvent, Widget,
    claimHoverIfInside, emit}

let MAIL_ROW_H: Float32 = 64.0
let MAIL_ROW_PAD: Float32 = 12.0
let MAIL_DOT_R: Float32 = 3.5

class MailRow <: Widget {
    private let mail: Mail
    private let unread: Bool
    private let isSelected: Bool
    private let onSelect: () -> Unit
    private let hoverId: String
    private var frame = Rect.zero()

    init(mail: Mail, unread: Bool, isSelected: Bool, onSelect: () -> Unit) {
        this.mail = mail
        this.unread = unread
        this.isSelected = isSelected
        this.onSelect = onSelect
        this.hoverId = "MailRow:${mail.id}"
        emit(this)
    }

    public func measure(_: UiContext, available: Size): Size {
        Size(available.w, MAIL_ROW_H)
    }

    public func layout(_: UiContext, rect: Rect): Unit {
        frame = rect
    }

    public func draw(ctx: UiContext): Unit {
        if (isSelected) {
            ctx.renderer.fillRoundedRect(frame, ctx.theme.smallRadius, ctx.theme.accentSoft)
        } else if (ctx.isHovered(hoverId)) {
            ctx.renderer.fillRoundedRect(frame, ctx.theme.smallRadius, ctx.theme.fieldActive)
        }
        let textX = frame.x + MAIL_ROW_PAD + 14.0
        let senderStyle = if (unread) {
            FontStyle(bold: true)
        } else {
            FontStyle.regular
        }
        if (unread) {
            ctx.renderer.fillCircle(frame.x + MAIL_ROW_PAD + 3.0, frame.y + 22.0, MAIL_DOT_R, ctx.theme.accent)
        }
        // 第一行：发件人（未读加粗）+ 右对齐时间。
        let timeW = ctx.renderer.textWidth(mail.time, pointSize: FontSizes.CAPTION)
        let timeX = frame.x + frame.w - MAIL_ROW_PAD - timeW
        ctx.renderer.text(mail.time, timeX, frame.y + 12.0, ctx.theme.mutedText, pointSize: FontSizes.CAPTION)
        ctx.renderer.pushClip(Rect(textX, frame.y, timeX - textX - 8.0, frame.h))
        ctx.renderer.text(mail.sender, textX, frame.y + 9.0, ctx.theme.text, pointSize: FontSizes.CONTROL,
            style: senderStyle)
        ctx.renderer.popClip()
        // 第二行：主题预览（未读用正文色、已读用弱化色），裁剪到行宽截断。
        let previewColor = if (unread) {
            ctx.theme.text
        } else {
            ctx.theme.mutedText
        }
        ctx.renderer.pushClip(Rect(textX, frame.y, frame.w - (textX - frame.x) - MAIL_ROW_PAD, frame.h))
        ctx.renderer.text(mail.subject, textX, frame.y + 34.0, previewColor, pointSize: FontSizes.CAPTION)
        ctx.renderer.popClip()
    }

    public func handle(ctx: UiContext, event: UiEvent): Bool {
        claimHoverIfInside(ctx, event, frame, hoverId, CursorShape.Interactive)
        match (event) {
            case UiEvent.MouseDown(MouseButton.Left, x, y) => if (frame.contains(x, y)) {
                onSelect()
                return true
            }
            case _ => ()
        }
        false
    }
}

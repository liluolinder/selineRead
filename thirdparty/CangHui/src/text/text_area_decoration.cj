package chui.text

import std.collection.ArrayList
import sdl.Color
import chui.core.Observable

/** Paint shape for a TextArea decoration underline. */
public enum TextAreaUnderlineShape {
    | Straight
    | Wave
}

/** Paint-only styling for one editable TextArea byte range. None keeps the ordinary theme value. */
public struct TextAreaDecorationStyle {
    public let foreground: ?Color
    public let background: ?Color
    public let underline: ?Color
    public let underlineShape: TextAreaUnderlineShape

    public init(
        foreground!: ?Color = None,
        background!: ?Color = None,
        underline!: ?Color = None,
        underlineShape!: TextAreaUnderlineShape = TextAreaUnderlineShape.Straight
    ) {
        this.foreground = foreground
        this.background = background
        this.underline = underline
        this.underlineShape = underlineShape
    }
}

/** A half-open UTF-8 byte range. Both offsets must be exact code-point boundaries. */
public struct TextAreaDecoration {
    public let startByte: Int64
    public let endByte: Int64
    public let style: TextAreaDecorationStyle

    public init(startByte: Int64, endByte: Int64, style: TextAreaDecorationStyle) {
        this.startByte = startByte
        this.endByte = endByte
        this.style = style
    }
}

/**
 * Immutable decoration input bound to one `Bindable<String>.revision`.
 *
 * The constructor copies the caller's array and `decorations()` returns another copy, so an
 * editor can publish this snapshot through `State`/`DerivedState` without sharing a mutable
 * range collection with TextArea. Later entries take precedence where ranges overlap.
 */
public class TextAreaDecorationSnapshot {
    public let documentRevision: UInt64
    private let storedDecorations: Array<TextAreaDecoration>

    public init(documentRevision: UInt64, decorations: Array<TextAreaDecoration>) {
        this.documentRevision = documentRevision
        this.storedDecorations = copyTextAreaDecorations(decorations)
    }

    /** Returns a defensive copy in caller order. */
    public func decorations(): Array<TextAreaDecoration> {
        copyTextAreaDecorations(storedDecorations)
    }
}

private func copyTextAreaDecorations(values: Array<TextAreaDecoration>): Array<TextAreaDecoration> {
    let copy = ArrayList<TextAreaDecoration>()
    for (value in values) {
        copy.add(value)
    }
    copy.toArray()
}

internal struct TextAreaDecorationRun {
    let lineIndex: Int64
    let lineStart: Int64
    let startByte: Int64
    let endByte: Int64
    let style: TextAreaDecorationStyle

    init(lineIndex: Int64, lineStart: Int64, startByte: Int64, endByte: Int64,
        style: TextAreaDecorationStyle) {
        this.lineIndex = lineIndex
        this.lineStart = lineStart
        this.startByte = startByte
        this.endByte = endByte
        this.style = style
    }
}

/** Normalized visible runs cached by document/decor revisions and visible logical-line window. */
class TextAreaDecorationCache {
    private var cachedTextRevision: UInt64 = UInt64(0)
    private var cachedDecorationRevision: UInt64 = UInt64(0)
    private var cachedSnapshotRevision: UInt64 = UInt64(0)
    private var cachedFirstLine: Int64 = 0
    private var cachedLastLine: Int64 = 0
    private var cachedRuns: Array<TextAreaDecorationRun> = []
    private var hasValue = false

    func visibleRuns(
        text: String,
        textRevision: UInt64,
        source: ?Observable<TextAreaDecorationSnapshot>,
        firstLine: Int64,
        lastLine: Int64
    ): Array<TextAreaDecorationRun> {
        match (source) {
            case None => return []
            case Some(observable) =>
                let snapshot = observable.get()
                if (!hasValue || cachedTextRevision != textRevision ||
                    cachedDecorationRevision != observable.revision ||
                    cachedSnapshotRevision != snapshot.documentRevision ||
                    cachedFirstLine != firstLine || cachedLastLine != lastLine) {
                    cachedRuns = if (snapshot.documentRevision == textRevision) {
                        buildVisibleTextAreaDecorationRuns(text, snapshot.decorations(), firstLine, lastLine)
                    } else {
                        []
                    }
                    cachedTextRevision = textRevision
                    cachedDecorationRevision = observable.revision
                    cachedSnapshotRevision = snapshot.documentRevision
                    cachedFirstLine = firstLine
                    cachedLastLine = lastLine
                    hasValue = true
                }
                cachedRuns
        }
    }
}

private func buildVisibleTextAreaDecorationRuns(
    text: String,
    decorations: Array<TextAreaDecoration>,
    firstLine: Int64,
    lastLine: Int64
): Array<TextAreaDecorationRun> {
    let valid = ArrayList<TextAreaDecoration>()
    for (decoration in decorations) {
        if (validTextAreaDecoration(text, decoration)) {
            valid.add(decoration)
        }
    }
    if (valid.isEmpty() || firstLine >= lastLine) {
        return []
    }
    let values = valid.toArray()
    let runs = ArrayList<TextAreaDecorationRun>()
    var lineIndex = max(Int64(0), firstLine)
    var lineStart = startOfTextLine(text, lineIndex)
    while (lineIndex < lastLine && lineStart <= text.size) {
        let lineEnd = lineEndAfterOrAt(text, lineStart)
        appendTextAreaDecorationRunsForLine(runs, values, lineIndex, lineStart, lineEnd)
        if (lineEnd >= text.size) {
            break
        }
        lineStart = nextTextBoundary(text, lineEnd)
        lineIndex += 1
    }
    runs.toArray()
}

private func appendTextAreaDecorationRunsForLine(
    output: ArrayList<TextAreaDecorationRun>,
    decorations: Array<TextAreaDecoration>,
    lineIndex: Int64,
    lineStart: Int64,
    lineEnd: Int64
): Unit {
    let boundaries = ArrayList<Int64>()
    boundaries.add(lineStart)
    boundaries.add(lineEnd)
    var intersects = false
    for (decoration in decorations) {
        let start = max(lineStart, decoration.startByte)
        let end = min(lineEnd, decoration.endByte)
        if (start < end) {
            boundaries.add(start)
            boundaries.add(end)
            intersects = true
        }
    }
    if (!intersects) {
        return
    }
    let sorted = boundaries.toArray()
    sortTextAreaDecorationBoundaries(sorted)
    let unique = ArrayList<Int64>()
    for (value in sorted) {
        if (unique.isEmpty() || unique[unique.size - 1] != value) {
            unique.add(value)
        }
    }
    let values = unique.toArray()
    var i: Int64 = 0
    while (i + 1 < values.size) {
        let start = values[i]
        let end = values[i + 1]
        if (start < end) {
            match (textAreaDecorationStyleAt(decorations, start, end)) {
                case Some(style) => output.add(TextAreaDecorationRun(lineIndex, lineStart, start, end, style))
                case None => ()
            }
        }
        i += 1
    }
}

private func textAreaDecorationStyleAt(
    decorations: Array<TextAreaDecoration>,
    start: Int64,
    end: Int64
): ?TextAreaDecorationStyle {
    var selected: ?TextAreaDecorationStyle = None
    for (decoration in decorations) {
        if (decoration.startByte <= start && decoration.endByte >= end) {
            selected = Some(decoration.style)
        }
    }
    selected
}

private func sortTextAreaDecorationBoundaries(values: Array<Int64>): Unit {
    var i: Int64 = 1
    while (i < values.size) {
        let value = values[i]
        var j = i
        while (j > 0 && values[j - 1] > value) {
            values[j] = values[j - 1]
            j -= 1
        }
        values[j] = value
        i += 1
    }
}

private func validTextAreaDecoration(text: String, decoration: TextAreaDecoration): Bool {
    decoration.startByte >= 0 && decoration.endByte > decoration.startByte &&
        decoration.endByte <= text.size && exactTextBoundary(text, decoration.startByte) &&
        exactTextBoundary(text, decoration.endByte)
}

private func exactTextBoundary(text: String, offset: Int64): Bool {
    offset >= 0 && offset <= text.size && normalizedTextCursor(text, offset) == offset
}

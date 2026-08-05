/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2023-2024. All rights reserved.
 */
package html4cj

let UntrackedPos: SrcPosition = SrcPosition(-1, -1, -1)

/*
 * A Range object tracks the character positions in the original input source where a Node starts or ends. If you want to
 * track these positions, tracking must be enabled in the Parser with
 */
public class SrcRange <: Hashable & Equatable<SrcRange> & ToString {
    private let startPosition: SrcPosition

    private let endPosition: SrcPosition

    private static let RangeKey: String = Attributes.internalKey("jsoup.sourceRange")

    private static let EndRangeKey: String = Attributes.internalKey("jsoup.endSourceRange")

    private static let Untracked: SrcRange = SrcRange(UntrackedPos, UntrackedPos)

    /*
     * Creates a new Range with start and end Positions. Called by TreeBuilder when position tracking is on.
     *
     * @param start the start position
     * @param end the end position
     */
    public init(start: SrcPosition, end: SrcPosition) {
        this.startPosition = start
        this.endPosition = end
    }

    /*
     * Get the start position of this node.
     *
     * @return the start position
     */
    public func start(): SrcPosition {
        return startPosition
    }

    /*
     * Get the end position of this node.
     *
     * @return the end position
     */
    public func end(): SrcPosition {
        return endPosition
    }

    /*
     * Test if this source range was tracked during parsing.
     *
     * @return true if this was tracked during parsing, false otherwise (and all fields will be -1).
     */
    public func isTracked(): Bool {
        return this != Untracked
    }

    /*
     * Retrieves the source range for a given Node.
     *
     * @param node the node to retrieve the position for
     * @param start if this is the starting range. false for Element end tags.
     * @return the Range, or the Untracked (-1) position if tracking is disabled.
     */
    static func of(node: Node, start: Bool): SrcRange {
        let key: String = if (start) {
            RangeKey
        } else {
            EndRangeKey
        }
        return if (!node.hasAttr(key)) {
            Untracked
        } else {
            (Validate.ensureNotNull(node.attributes().getUserData(key)) as SrcRange)()
        }
    }

    /*
     * Internal jsoup method, called by the TreeBuilder. Tracks a Range for a Node.
     *
     * @param node the node to associate this position to
     * @param start if this is the starting range. false for Element end tags.
     */
    public func track(node: Node, start: Bool): Unit {
        if (start) {
            node.attributes().putUserData(RangeKey, this)
        } else {
            node.attributes().putUserData(EndRangeKey, this)
        }
    }

    @OverflowWrapping
    public func hashCode(): Int64 {
        var result: Int64 = startPosition.hashCode()
        result = 31 * result + endPosition.hashCode()
        return result
    }

    /*
     * Gets a String presentation of this Range, in the format line,column:pos-line,column:pos.
     *
     * @return a String
     */
    public func toString(): String {
        return "${startPosition}-${endPosition}"
    }

    public operator func !=(that: SrcRange): Bool {
        return !(this == that)
    }

    public operator func ==(that: SrcRange): Bool {
        return refEq(this, that) || (startPosition == that.startPosition && endPosition == that.endPosition)
    }
}

/*
 * A Position object tracks the character position in the original input source where a Node starts or ends. If you want to
 * track these positions, tracking must be enabled in the Parser with
 */
public class SrcPosition <: Hashable & Equatable<SrcPosition> & ToString {
    private let posInt: Int64
    private let lineNumberInt: Int64
    private let columnNumberInt: Int64

    /*
     * Create a new Position object. Called by the TreeBuilder if source position tracking is on.
     *
     * @param pos position index
     * @param lineNumber line number
     * @param columnNumber column number
     */
    public init(pos: Int64, lineNumber: Int64, columnNumber: Int64) {
        this.posInt = pos
        this.lineNumberInt = lineNumber
        this.columnNumberInt = columnNumber
    }

    /*
     * Gets the position index (0-based) of the original input source that this Position was read at. This tracks the
     * total number of characters read into the source at this position, regardless of the number of preceeding lines.
     */
    public func pos(): Int64 {
        return posInt
    }

    /*
     * Gets the line number (1-based) of the original input source that this Position was read at.
     *
     * @return the line number, or -1 if untracked.
     */
    public func lineNumber(): Int64 {
        return lineNumberInt
    }

    /*
     * Gets the cursor number (1-based) of the original input source that this Position was read at. The cursor number resets to 1 on every new line.
     *
     * @return the cursor number, or -1 if untracked.
     */
    public func columnNumber(): Int64 {
        return columnNumberInt
    }

    /*
     * Test if this position was tracked during parsing.
     *
     * @return true if this was tracked during parsing, false otherwise (and all fields will be -1).
     */
    public func isTracked(): Bool {
        return this != UntrackedPos
    }

    /*
     * Gets a String presentation of this Position, in the format pos
     *
     * @return a String
     */
    public func toString(): String {
        return "${lineNumberInt},${columnNumberInt}:${posInt}"
    }

    @OverflowWrapping
    public func hashCode(): Int64 {
        var result: Int64 = posInt
        result = 31 * result + lineNumberInt
        result = 31 * result + columnNumberInt
        return result
    }

    public operator func !=(that: SrcPosition): Bool {
        return !(this == that)
    }

    public operator func ==(that: SrcPosition): Bool {
        return refEq(this, that) || (posInt == that.posInt && lineNumberInt == that.lineNumberInt && columnNumberInt == that
            .columnNumberInt)
    }
}

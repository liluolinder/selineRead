/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2023-2024. All rights reserved.
 */
package html4cj

/*
 * A Parse Error records an error in the input HTML that occurs in either the tokenisation or the tree building phase.
 */
public class ParseError <: ToString {
    private let pos: Int64
    private let cursorPos: String
    private let errorMsg: String

    init(reader: CharacterReader, errorMsg: String) {
        this.pos = reader.pos()
        this.cursorPos = reader.cursorPos()
        this.errorMsg = errorMsg
    }

    init(pos: Int64, errorMsg: String) {
        this.pos = pos
        this.cursorPos = pos.toString()
        this.errorMsg = errorMsg
    }

    /*
     * Retrieve the error message.
     * @return the error message.
     */
    public func getErrorMessage(): String {
        return errorMsg
    }

    /*
     * Retrieves the offset of the error.
     * @return error offset within input
     */
    public func getPosition(): Int64 {
        return pos
    }

    /*
       Get the formatted line:column cursor position where the error occurred.
       @return line:number cursor position
     */
    public func getCursorPos(): String {
        return cursorPos
    }

    public func toString(): String {
        return "<" + cursorPos + ">: " + errorMsg
    }
}

public class ParseErrorList <: Iterable<ParseError> {
    private static let INITIAL_CAPACITY: Int64 = 16
    private let initialCapacity: Int64
    private let maxSize: Int64
    private let arr: ArrayList<ParseError>
    public prop size: Int64 {
        get() {
            arr.size
        }
    }

    init(initialCapacity: Int64, maxSize: Int64) {
        arr = ArrayList<ParseError>(initialCapacity)
        this.initialCapacity = initialCapacity
        this.maxSize = maxSize
    }

    /*
       Create a new ParseErrorList with the same settings, but no errors in the list
       @param copy initial and max size details to copy
     */
    init(copy: ParseErrorList) {
        this(copy.initialCapacity, copy.maxSize)
    }

    func canAddError(): Bool {
        return arr.size < maxSize
    }

    func add(err: ParseError): Unit {
        arr.add(err)
    }

    func getMaxSize(): Int64 {
        return maxSize
    }

    public operator func [](index: Int64): ParseError {
        arr[index]
    }

    public static func noTracking(): ParseErrorList {
        return ParseErrorList(0, 0)
    }

    public static func tracking(maxSize: Int64): ParseErrorList {
        return ParseErrorList(INITIAL_CAPACITY, maxSize)
    }

    public func clone(): ParseErrorList {
        return ParseErrorList(this).apply<ParseErrorList> {it => it.arr.add(all: this.arr)}
    }

    public func iterator(): Iterator<ParseError> {
        return arr.iterator()
    }
}

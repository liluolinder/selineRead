package mirrors

import java.lang.*

@JavaMirror["java.util.Date"]
public open class Date <: Serializable & Cloneable & Comparable {
    public init()

    public init(date: Int64)

    public init(year: Int32, month: Int32, date: Int32)

    public init(year: Int32, month: Int32, date: Int32, hrs: Int32, min: Int32)

    public init(year: Int32, month: Int32, date: Int32, hrs: Int32, min: Int32, sec: Int32)

    public init(s: ?JString)

    public open func clone(): ?JObject

    public static func UTC(year: Int32, month: Int32, date: Int32, hrs: Int32, min: Int32, sec: Int32): Int64

    public static func parse(s: ?JString): Int64

    public open func getYear(): Int32

    public open func setYear(year: Int32): Unit

    public open func getMonth(): Int32

    public open func setMonth(month: Int32): Unit

    public open func getDate(): Int32

    public open func setDate(date: Int32): Unit

    public open func getDay(): Int32

    public open func getHours(): Int32

    public open func setHours(hours: Int32): Unit

    public open func getMinutes(): Int32

    public open func setMinutes(minutes: Int32): Unit

    public open func getSeconds(): Int32

    public open func setSeconds(seconds: Int32): Unit

    public open func getTime(): Int64

    public open func setTime(time: Int64): Unit

    public open func before(when: ?Date): Bool

    public open func after(when: ?Date): Bool

    public open func equals(obj: ?JObject): Bool

    public open func compareTo(anotherDate: ?Date): Int32

    public open func hashCode32(): Int32

    public open func toJString(): JString

    public open func toLocaleString(): ?JString

    public open func toGMTString(): ?JString

    public open func getTimezoneOffset(): Int32

    public static func `from`(instant: ?Instant): ?Date

    public open func toInstant(): ?Instant

    public open func compareTo(arg0: ?JObject): Int32
}
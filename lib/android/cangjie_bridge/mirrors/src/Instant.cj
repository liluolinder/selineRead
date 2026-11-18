package mirrors

import java.lang.*

@JavaMirror["java.time.Instant"]
public class Instant <: Comparable & Serializable {
    public static let EPOCH: ?Instant

    public static let MAX: ?Instant

    public static let MIN: ?Instant

    public static func now(): ?Instant

    public static func ofEpochSecond(epochSecond: Int64): ?Instant

    public static func ofEpochSecond(epochSecond: Int64, nanoAdjustment: Int64): ?Instant

    public static func ofEpochMilli(epochMilli: Int64): ?Instant

    public func getEpochSecond(): Int64

    public func getNano(): Int32

    public func plusSeconds(secondsToAdd: Int64): ?Instant

    public func plusMillis(millisToAdd: Int64): ?Instant

    public func plusNanos(nanosToAdd: Int64): ?Instant

    public func minusSeconds(secondsToSubtract: Int64): ?Instant

    public func minusMillis(millisToSubtract: Int64): ?Instant

    public func minusNanos(nanosToSubtract: Int64): ?Instant

    public func toEpochMilli(): Int64

    public func compareTo(otherInstant: ?Instant): Int32

    public func isAfter(otherInstant: ?Instant): Bool

    public func isBefore(otherInstant: ?Instant): Bool

    public func equals(other: ?JObject): Bool

    public func hashCode32(): Int32

    public func toJString(): JString

    public func compareTo(arg0: ?JObject): Int32
}
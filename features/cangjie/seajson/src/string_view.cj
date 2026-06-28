package seajson

// ============================================================================
// StringView - Zero-copy String Slice
// ============================================================================
//
// A lightweight view into a string that avoids copying the underlying data.
// Useful for parsing large JSON documents where only a subset of string fields
// need to be accessed.
//
// ## Features
//   - Zero-copy: holds a reference to the original string
//   - Direct byte access via get(index)
//   - Zero-copy comparison via equals(other)
//   - Lazy copy: toString() only creates a new String when called
//
// ## Usage
//   let json = "{\"name\":\"Alice\"}"
//   let view = StringView(json, 9, 5)  // view of "Alice"
//   
//   // Zero-copy operations
//   view.size()      // 5
//   view.get(0)      // 65 ('A')
//   view.equals("Alice")  // true
//   
//   // Copy only when needed
//   let str = view.toString()  // creates new String
//
// ## Thread Safety
//   StringView is immutable and safe for concurrent read access.
//   However, the underlying String must not be modified during use.
//
// ============================================================================

/// A zero-copy view into a string slice.
///
/// StringView holds a reference to the original string and tracks offset/length,
/// allowing substring operations without memory allocation.
/// Only when `toString()` is called does a new String get created.
public class StringView {
    private let source: String
    private let offset: Int64
    private let len: Int64

    /// Create a StringView for a slice of the source string.
    /// 
    /// Parameters:
    ///   - source: The original string (not copied)
    ///   - offset: Starting position in the source
    ///   - length: Number of bytes in the view
    ///
    /// Note: Does not validate bounds for performance. Caller must ensure
    /// offset + length <= source.size.
    public init(source: String, offset: Int64, length: Int64) {
        this.source = source
        this.offset = offset
        this.len = length
    }

    /// Returns the length of this view in bytes.
    public func size(): Int64 { len }

    /// Returns true if this view is empty.
    public func isEmpty(): Bool { len == 0 }

    /// Returns the byte at the given index within this view.
    /// Does not validate bounds for performance.
    public func get(index: Int64): UInt8 {
        source[offset + index]
    }

    /// Creates a new String by copying the viewed slice.
    /// This is the only operation that allocates memory.
    public func toString(): String {
        if (len == 0) { return "" }
        source[offset..(offset + len)]
    }

    /// Zero-copy comparison with a String.
    /// Compares bytes directly without creating intermediate strings.
    public func equals(other: String): Bool {
        if (len != other.size) { return false }
        var i: Int64 = 0
        while (i < len) {
            if (source[offset + i] != other[i]) { return false }
            i += 1
        }
        true
    }

    /// Zero-copy comparison with another StringView.
    /// Compares bytes directly without creating intermediate strings.
    public func equalsView(other: StringView): Bool {
        if (len != other.len) { return false }
        // Compare byte by byte
        var i: Int64 = 0
        while (i < len) {
            if (source[offset + i] != other.source[other.offset + i]) { return false }
            i += 1
        }
        true
    }

    /// Creates a substring view of this view.
    /// Still zero-copy - just adjusts offset and length.
    public func slice(start: Int64, length: Int64): StringView {
        StringView(source, offset + start, length)
    }

    /// Returns the underlying source string reference.
    /// Use with caution - exposes the entire original string.
    public func getSource(): String { source }

    /// Returns the offset into the source string.
    public func getOffset(): Int64 { offset }
}

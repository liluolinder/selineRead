package seajson

import std.collection.{ArrayList, HashMap}

// ============================================================================
// JsonBufferPool - Memory Pool for JSON Parsing Buffers
// ============================================================================
//
// A simple memory pool for reusing ArrayList buffers during JSON parsing.
// Particularly useful for high-frequency parsing scenarios where many
// short-lived buffers are created and discarded.
//
// ## Features
//   - Reuse ArrayList<UInt8> for string building
//   - Reuse ArrayList<JsonValue> for array building
//   - Reduce GC pressure in tight parsing loops
//
// ## Usage
//   let pool = JsonBufferPool()
//   
//   // Borrow a buffer
//   let buf = pool.borrowByteBuffer()
//   buf.add(65)  // use it
//   
//   // Return it when done
//   pool.returnByteBuffer(buf)
//
// ============================================================================

/// A memory pool for reusing JSON parsing buffers.
///
/// This reduces allocation overhead when parsing many JSON documents
/// by reusing ArrayList instances instead of creating new ones.
public class JsonBufferPool {
    // Pool of byte buffers for string building
    private let byteBuffers: ArrayList<ArrayList<UInt8>>
    
    // Pool of JsonValue buffers for array building
    private let valueBuffers: ArrayList<ArrayList<JsonValue>>
    
    // Pool of entry buffers for object building
    private let entryBuffers: ArrayList<ArrayList<(String, JsonValue)>>
    
    // Maximum pool size per type
    private let maxPoolSize: Int64
    
    public init() {
        this.maxPoolSize = 16
        byteBuffers = ArrayList<ArrayList<UInt8>>()
        valueBuffers = ArrayList<ArrayList<JsonValue>>()
        entryBuffers = ArrayList<ArrayList<(String, JsonValue)>>()
    }
    
    public init(maxPoolSize: Int64) {
        this.maxPoolSize = maxPoolSize
        byteBuffers = ArrayList<ArrayList<UInt8>>()
        valueBuffers = ArrayList<ArrayList<JsonValue>>()
        entryBuffers = ArrayList<ArrayList<(String, JsonValue)>>()
    }
    
    /// Borrow a byte buffer from the pool, or create a new one if pool is empty.
    public func borrowByteBuffer(): ArrayList<UInt8> {
        if (byteBuffers.size > 0) {
            let buf = byteBuffers.remove(at: byteBuffers.size - 1)
            buf
        } else {
            ArrayList<UInt8>()
        }
    }
    
    /// Return a byte buffer to the pool for reuse.
    /// The buffer is cleared before being pooled.
    public func returnByteBuffer(buf: ArrayList<UInt8>): Unit {
        if (byteBuffers.size < maxPoolSize) {
            buf.clear()
            byteBuffers.add(buf)
        }
    }
    
    /// Borrow a JsonValue buffer from the pool, or create a new one if pool is empty.
    public func borrowValueBuffer(): ArrayList<JsonValue> {
        if (valueBuffers.size > 0) {
            let buf = valueBuffers.remove(at: valueBuffers.size - 1)
            buf
        } else {
            ArrayList<JsonValue>()
        }
    }
    
    /// Return a JsonValue buffer to the pool for reuse.
    public func returnValueBuffer(buf: ArrayList<JsonValue>): Unit {
        if (valueBuffers.size < maxPoolSize) {
            buf.clear()
            valueBuffers.add(buf)
        }
    }
    
    /// Borrow an entry buffer from the pool, or create a new one if pool is empty.
    public func borrowEntryBuffer(): ArrayList<(String, JsonValue)> {
        if (entryBuffers.size > 0) {
            let buf = entryBuffers.remove(at: entryBuffers.size - 1)
            buf
        } else {
            ArrayList<(String, JsonValue)>()
        }
    }
    
    /// Return an entry buffer to the pool for reuse.
    public func returnEntryBuffer(buf: ArrayList<(String, JsonValue)>): Unit {
        if (entryBuffers.size < maxPoolSize) {
            buf.clear()
            entryBuffers.add(buf)
        }
    }
    
    /// Get the total number of buffers currently in the pool.
    public func pooledCount(): Int64 {
        byteBuffers.size + valueBuffers.size + entryBuffers.size
    }
}

/// Global default buffer pool instance.
/// Can be used for simple use cases without creating a custom pool.
public let defaultBufferPool = JsonBufferPool()

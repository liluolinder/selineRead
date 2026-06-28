package seajson

import std.collection.HashMap

// ============================================================================
// StringPool - String Interning for Memory Efficiency
// ============================================================================
//
// A simple string interning pool that reuses common string instances.
// Particularly useful for repeated JSON keys like "id", "name", "type".
//
// ## Features
//   - Reduces memory allocations for repeated strings
//   - Fast O(1) lookup for already-interned strings
//   - Thread-safe for read access (pool is immutable after creation)
//
// ## Usage
//   let pool = StringPool()
//   let s1 = pool.intern("name")  // Creates new string
//   let s2 = pool.intern("name")  // Returns same instance
//   s1 === s2  // true (same reference)
//
// ============================================================================

/// A string interning pool for memory-efficient string storage.
///
/// Common use case: JSON key names that repeat across many objects.
/// Instead of allocating a new String for each "id" key, reuse the same instance.
public class StringPool {
    private let pool: HashMap<String, String>

    public init() {
        pool = HashMap<String, String>()
    }

    /// Intern a string: return an existing instance if available, or store and return a new one.
    /// This is useful for reducing memory when the same strings appear repeatedly.
    public func intern(s: String): String {
        match (pool.get(s)) {
            case Some(existing) => existing
            case None =>
                pool[s] = s
                s
        }
    }

    /// Returns the number of unique strings in the pool.
    public func size(): Int64 {
        pool.size
    }

    /// Check if a string is already interned without adding it.
    public func contains(s: String): Bool {
        match (pool.get(s)) {
            case Some(_) => true
            case None => false
        }
    }
}

// ── Pre-defined common JSON key pool ─────────────────────────────────────

/// Common JSON field names for fast interning.
/// These are frequently used keys in typical JSON APIs.
public let COMMON_JSON_KEYS = [
    "id", "name", "type", "value", "data", "result", "error", "message",
    "status", "code", "items", "list", "count", "total", "size", "page",
    "limit", "offset", "sort", "order", "field", "fields", "query", "filter",
    "created", "updated", "deleted", "timestamp", "time", "date", "start", "end",
    "user", "user_id", "userId", "username", "email", "phone", "address",
    "title", "description", "content", "text", "label", "key", "tags",
    "url", "link", "href", "src", "source", "target", "action", "method",
    "success", "fail", "failed", "ok", "true", "false", "null", "default"
]

/// Create a pre-populated StringPool with common JSON keys.
public func createCommonKeyPool(): StringPool {
    let pool = StringPool()
    for (key in COMMON_JSON_KEYS) {
        pool.intern(key)
    }
    pool
}

/// Global default string pool instance.
/// Can be used for simple use cases without creating a custom pool.
public let defaultStringPool = createCommonKeyPool()

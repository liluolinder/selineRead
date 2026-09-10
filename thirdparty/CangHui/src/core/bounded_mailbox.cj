package chui.core

import std.collection.ArrayList
import std.sync.Mutex

/**
 * A thread-safe bounded mailbox used to carry platform events, commands or
 * state updates into the CangHui UI thread.
 *
 * This is the generalized form of the repeated mailbox classes seen in
 * Harmony consumers (input/command/presentation mailboxes). Push overwrites
 * the oldest item when full, keeping the mailbox bounded.
 */
public class BoundedMailbox<T> {
    private let capacity: Int64
    private let mutex = Mutex()
    private let items = ArrayList<T>()

    public init(capacity!: Int64 = 32) {
        this.capacity = if (capacity < 1) { Int64(1) } else { capacity }
    }

    /** Adds an item; if full, drops the oldest item to stay bounded. */
    public func push(item: T): Unit {
        synchronized(mutex) {
            if (items.size >= capacity) {
                items.remove(at: 0)
            }
            items.add(item)
        }
    }

    /** Removes and returns the oldest item, or None when empty. */
    public func take(): ?T {
        var result: ?T = None
        synchronized(mutex) {
            if (!items.isEmpty()) {
                result = Some(items.remove(at: 0))
            }
        }
        result
    }

    /** Returns the newest item without removing it, or None when empty. */
    public func peekNewest(): ?T {
        var result: ?T = None
        synchronized(mutex) {
            if (!items.isEmpty()) {
                result = Some(items[items.size - 1])
            }
        }
        result
    }

    /** Removes and returns all items in FIFO order. */
    public func drain(): Array<T> {
        let copy = ArrayList<T>()
        synchronized(mutex) {
            for (item in items) {
                copy.add(item)
            }
            items.clear()
        }
        copy.toArray()
    }

    /** Removes all items. */
    public func clear(): Unit {
        synchronized(mutex) {
            items.clear()
        }
    }

    /** Returns the current number of buffered items. */
    public func size(): Int64 {
        var count = Int64(0)
        synchronized(mutex) {
            count = items.size
        }
        count
    }
}

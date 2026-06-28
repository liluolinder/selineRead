/** @internal - Base encoding utility (Endian, SecureBytes, ByteBuffer), not a standalone product interface. Do not add contract barrier. */
package jinguissl_core.crypto.base

import std.collection.ArrayList
import jinguissl_core.crypto.error.{CryptoException, CryptoErrorCode}

public enum Endian <: Equatable<Endian> & ToString {
    | Big
    | Little

    public operator func ==(right: Endian): Bool {
        ordinalValue() == right.ordinalValue()
    }

    public operator func !=(right: Endian): Bool {
        !(this == right)
    }

    public func ordinalValue(): Int64 {
        match (this) {
            case Big => 0
            case Little => 1
        }
    }

    public func toString(): String {
        match (this) {
            case Big => "BIG"
            case Little => "LITTLE"
        }
    }
}

public class SecureBytes {
    var _bytes: Array<Byte>
    var _destroyed: Bool = false

    public init(bytes: Array<Byte>) {
        this._bytes = bytes.clone()
    }

    public static func withSize(size: Int64): SecureBytes {
        if (size < 0) {
            throw CryptoException(InvalidArgument, "size must be non-negative")
        }
        SecureBytes(Array<Byte>(size, repeat: 0))
    }

    public prop size: Int64 {
        get() {
            _bytes.size
        }
    }

    public prop isDestroyed: Bool {
        get() {
            _destroyed
        }
    }

    public func bytes(): Array<Byte> {
        ensureAlive()
        _bytes.clone()
    }

    /**
 * setAt.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func setAt(index: Int64, value: Byte): Unit {
        ensureAlive()
        if (index < 0 || index >= _bytes.size) {
            throw CryptoException(OutOfBounds, "index out of range")
        }
        _bytes[index] = value
    }

    public func clear(): Unit {
        ensureAlive()
        var i = 0
        while (i < _bytes.size) {
            _bytes[i] = 0
            i += 1
        }
    }

    public func destroy(): Unit {
        if (_destroyed) {
            return
        }
        var i = 0
        while (i < _bytes.size) {
            _bytes[i] = 0
            i += 1
        }
        _destroyed = true
    }

    private func ensureAlive(): Unit {
        if (_destroyed) {
            throw CryptoException(InvalidArgument, "SecureBytes is destroyed")
        }
    }
}

public class ByteBuffer {
    let _list: ArrayList<Byte> = ArrayList<Byte>()

    public init() {}

    public init(bytes: Array<Byte>) {
        append(bytes)
    }

    public prop size: Int64 {
        get() {
            _list.size
        }
    }

    public func append(value: Byte): Unit {
        _list.add(value)
    }

    public func append(bytes: Array<Byte>): Unit {
        for (b in bytes) {
            _list.add(b)
        }
    }

    public func clear(): Unit {
        _list.clear()
    }

    public func toArray(): Array<Byte> {
        _list.toArray()
    }
}

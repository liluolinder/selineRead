package ignite

import std.collection.ArrayList
import std.io.{InputStream, OutputStream}
import std.sync.Mutex

private let JSON_WRITER_INPUT_STREAM_DEFAULT_BUFFER_LIMIT: Int64 = 8192
private let JSON_WRITER_INPUT_STREAM_POLL_INTERVAL_MS: Int64 = 1

/// Public bridge that lets a JSON writer callback be consumed as an `InputStream`.
///
/// Callers can pair this seam with `ctx.sendStream(...)` when they want to reuse
/// the already-proven InputStream response path instead of the current direct
/// `ctx.jsonWrite(...)` writer seam.
public class JsonWriterInputStream <: InputStream & Resource {
    let _producerFn: (OutputStream) -> Unit
    let _bufferLimit: Int64
    let _mtx = Mutex()
    var _buffer = ArrayList<Byte>()
    var _readCursor: Int64 = 0
    var _producerStarted: Bool = false
    var _producerFinished: Bool = false
    var _producerFailed: Bool = false
    var _producerFailureMessage: String = ""
    var _closed: Bool = false

    public init(
        writerFn: (JsonWriter) -> Unit,
        bufferLimit!: Int64 = JSON_WRITER_INPUT_STREAM_DEFAULT_BUFFER_LIMIT
    ) {
        _producerFn = { out =>
            writeJsonCallbackThroughSeaJsonBridge(out, writerFn)
        }
        _bufferLimit = if (bufferLimit > 0) {
            bufferLimit
        } else {
            JSON_WRITER_INPUT_STREAM_DEFAULT_BUFFER_LIMIT
        }
    }

    // Internal producer escape hatch for sibling streamed JSON surfaces that
    // already own an OutputStream writer path and only need the accepted
    // InputStream bridge.
    init(
        outputProducer!: (OutputStream) -> Unit,
        bufferLimit!: Int64 = JSON_WRITER_INPUT_STREAM_DEFAULT_BUFFER_LIMIT
    ) {
        _producerFn = outputProducer
        _bufferLimit = if (bufferLimit > 0) {
            bufferLimit
        } else {
            JSON_WRITER_INPUT_STREAM_DEFAULT_BUFFER_LIMIT
        }
    }

    public override func read(outBuf: Array<Byte>): Int64 {
        if (outBuf.size == 0) {
            return 0
        }
        ensureProducerStarted()
        while (true) {
            var readLen: Int64 = 0
            var failed: Bool = false
            var failureMessage = ""
            var finished: Bool = false
            synchronized(_mtx) {
                readLen = copyBufferedBytesLocked(outBuf)
                failed = _producerFailed
                failureMessage = _producerFailureMessage
                finished = _producerFinished
            }
            if (readLen > 0) {
                return readLen
            }
            if (failed) {
                close()
                throw Exception("JsonWriterInputStream producer failed: ${failureMessage}")
            }
            if (finished || _closed) {
                close()
                return 0
            }
            sleep(Duration.millisecond * JSON_WRITER_INPUT_STREAM_POLL_INTERVAL_MS)
        }
        0
    }

    public func close(): Unit {
        synchronized(_mtx) {
            _closed = true
        }
    }

    public func isClosed(): Bool {
        synchronized(_mtx) {
            _closed
        }
    }

    public func hasStartedProducer(): Bool {
        synchronized(_mtx) {
            _producerStarted
        }
    }

    func ensureProducerStarted(): Unit {
        var shouldStart = false
        synchronized(_mtx) {
            if (!_producerStarted && !_closed) {
                _producerStarted = true
                shouldStart = true
            }
        }
        if (!shouldStart) {
            return
        }
        let current = this
        spawn {
            current.runProducer()
        }
    }

    func runProducer(): Unit {
        let out = JsonWriterInputBridgeOutputStream(this)
        try {
            _producerFn(out)
            markProducerFinished()
        } catch (e: Exception) {
            markProducerFailed(e.message)
        } finally {
            out.close()
        }
    }

    func writeBytesFromProducer(data: Array<Byte>): Unit {
        if (data.size == 0) {
            return
        }
        var cursor: Int64 = 0
        while (cursor < data.size) {
            var writeLen: Int64 = 0
            synchronized(_mtx) {
                if (_closed) {
                    throw Exception("JsonWriterInputStream is closed")
                }
                compactBufferLocked()
                let remainingCapacity = _bufferLimit - bufferedByteCountLocked()
                if (remainingCapacity > 0) {
                    writeLen = if (remainingCapacity < data.size - cursor) {
                        remainingCapacity
                    } else {
                        data.size - cursor
                    }
                    var i: Int64 = 0
                    while (i < writeLen) {
                        _buffer.add(data[cursor + i])
                        i += 1
                    }
                }
            }
            if (writeLen > 0) {
                cursor += writeLen
                continue
            }
            sleep(Duration.millisecond * JSON_WRITER_INPUT_STREAM_POLL_INTERVAL_MS)
        }
    }

    func markProducerFinished(): Unit {
        synchronized(_mtx) {
            _producerFinished = true
        }
    }

    func markProducerFailed(message: String): Unit {
        synchronized(_mtx) {
            _producerFailed = true
            _producerFinished = true
            _producerFailureMessage = if (message.size > 0) {
                message
            } else {
                "unknown producer failure"
            }
        }
    }

    func copyBufferedBytesLocked(outBuf: Array<Byte>): Int64 {
        compactBufferLocked()
        let buffered = bufferedByteCountLocked()
        if (buffered <= 0) {
            return 0
        }
        let readLen = if (buffered < outBuf.size) {
            buffered
        } else {
            outBuf.size
        }
        var i: Int64 = 0
        while (i < readLen) {
            outBuf[i] = _buffer[_readCursor + i]
            i += 1
        }
        _readCursor += readLen
        compactBufferLocked()
        readLen
    }

    func bufferedByteCountLocked(): Int64 {
        _buffer.size - _readCursor
    }

    func compactBufferLocked(): Unit {
        if (_readCursor <= 0) {
            return
        }
        if (_readCursor >= _buffer.size) {
            _buffer = ArrayList<Byte>()
            _readCursor = 0
            return
        }
        let next = ArrayList<Byte>()
        var i = _readCursor
        while (i < _buffer.size) {
            next.add(_buffer[i])
            i += 1
        }
        _buffer = next
        _readCursor = 0
    }
}

class JsonWriterInputBridgeOutputStream <: OutputStream & Resource {
    let _owner: JsonWriterInputStream
    var _closed: Bool = false

    init(owner: JsonWriterInputStream) {
        _owner = owner
    }

    public override func write(data: Array<Byte>): Unit {
        _owner.writeBytesFromProducer(data)
    }

    public override func flush(): Unit {}

    public func close(): Unit {
        _closed = true
    }

    public func isClosed(): Bool {
        _closed
    }
}

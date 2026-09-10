package chui.core

import sdl.Rect

private let SHARED_FRAME_HARD_MAX_BYTES: Int64 = 268435456

/** Internal, handle-free scheduling fact emitted by a native child-surface widget during layout. */
protected struct NativeChildFrameSurface {
    public let identity: String
    public let generation: Int64
    public let bounds: Rect

    public init(identity: String, generation: Int64, bounds: Rect) {
        this.identity = identity
        this.generation = generation
        this.bounds = bounds
    }
}

/**
 * Handle-free pixels acquired from an offscreen/native Scene3D provider for one frame.
 *
 * UiContext owns the immutable software snapshot and its finish callback until frame commit,
 * rollback, or fallback. No native handle or provider object enters graph metadata or trace output;
 * a platform GPU executor may resolve the same stable identity through a private binding.
 */
protected class SharedFrameSurface {
    public let identity: String
    public let generation: Int64
    public let frameId: Int64
    public let bounds: Rect
    public let pixelWidth: Int64
    public let pixelHeight: Int64
    public let rowBytes: Int64
    public let colorSpace: String
    public let alphaMode: String
    public let dynamicRange: String
    public let syncEpoch: Int64
    public let contentCode: Int64
    /** Provider-target posture. Pixels are already rendered for this layout; the compositor does not rotate them. */
    public let rotationCode: String
    private let pixelBytes: Array<UInt8>
    private let finishAction: (String) -> Bool
    private var finished = false
    private var finishOutcomeValue = "pending"
    private var finishOkValue = false
    private var compositionAttempts: Int64 = 0
    private var compositionSucceededValue = true
    private var compositionCodeValue = "not-attempted"

    public init(
        identity: String,
        generation: Int64,
        frameId: Int64,
        bounds: Rect,
        pixelWidth: Int64,
        pixelHeight: Int64,
        rowBytes: Int64,
        colorSpace: String,
        alphaMode: String,
        dynamicRange: String,
        syncEpoch: Int64,
        contentCode: Int64,
        rotationCode: String,
        pixels: Array<UInt8>,
        onFinish!: (String) -> Bool = {_ => true}
    ) {
        if (identity.isEmpty() || generation <= 0 || frameId < 0 ||
            bounds.w <= 0.0 || bounds.h <= 0.0 || pixelWidth <= 0 || pixelHeight <= 0 ||
            pixelWidth > Int64.Max / 4 || colorSpace.isEmpty() || alphaMode.isEmpty() ||
            dynamicRange.isEmpty() || syncEpoch < 0 || contentCode <= 0 || rotationCode.isEmpty()) {
            throw IllegalArgumentException("shared frame surface metadata is invalid")
        }
        let minimumRowBytes = pixelWidth * 4
        if (rowBytes < minimumRowBytes || rowBytes <= 0 ||
            pixelHeight > Int64.Max / rowBytes) {
            throw IllegalArgumentException("shared frame surface geometry overflows")
        }
        let payloadBytes = pixelHeight * rowBytes
        if (payloadBytes > SHARED_FRAME_HARD_MAX_BYTES || pixels.size != payloadBytes) {
            throw IllegalArgumentException("shared frame surface pixel payload does not match its geometry")
        }
        this.identity = identity
        this.generation = generation
        this.frameId = frameId
        this.bounds = bounds
        this.pixelWidth = pixelWidth
        this.pixelHeight = pixelHeight
        this.rowBytes = rowBytes
        this.colorSpace = colorSpace
        this.alphaMode = alphaMode
        this.dynamicRange = dynamicRange
        this.syncEpoch = syncEpoch
        this.contentCode = contentCode
        this.rotationCode = rotationCode
        this.pixelBytes = pixels.clone()
        this.finishAction = onFinish
    }

    /** Returns an owned copy; callers cannot mutate the frame snapshot retained by the shell. */
    public func pixels(): Array<UInt8> {
        if (finished) { throw IllegalStateException("shared frame surface is already finished") }
        pixelBytes.clone()
    }

    /** Starts a new renderer attempt without changing provider ownership. */
    public func beginCompositionAttempt(): Unit {
        if (finished) { return }
        compositionAttempts = 0
        compositionSucceededValue = true
        compositionCodeValue = "not-attempted"
    }

    /** Records the real sampling result. One failed sample keeps the whole attempt failed. */
    public func recordComposition(ok: Bool, code: String): Unit {
        if (finished) { return }
        compositionAttempts += 1
        if (!ok) { compositionSucceededValue = false }
        compositionCodeValue = code
    }

    public func compositionAttempted(): Bool { compositionAttempts > 0 }

    public func compositionSucceeded(): Bool {
        !finished && compositionAttempts > 0 && compositionSucceededValue
    }

    public func compositionCode(): String { compositionCodeValue }

    /** Completes provider ownership exactly once. Callback failures are contained in the receipt. */
    public func finish(outcome: String): Bool {
        if (!sharedFrameFinishOutcomeValid(outcome)) {
            throw IllegalArgumentException("shared frame finish outcome is invalid")
        }
        if (finished) { return finishOkValue }
        finished = true
        finishOutcomeValue = outcome
        finishOkValue = try {
            finishAction(outcome)
        } catch (_: Exception) {
            false
        }
        finishOkValue
    }

    public func isFinished(): Bool { finished }
    public func finishOutcome(): String { finishOutcomeValue }
    public func finishSucceeded(): Bool { finishOkValue }
}

private func sharedFrameFinishOutcomeValid(value: String): Bool {
    value == "presented" || value == "rejected" || value == "fallback" ||
        value == "executor-failed" || value == "replaced" || value == "abandoned"
}

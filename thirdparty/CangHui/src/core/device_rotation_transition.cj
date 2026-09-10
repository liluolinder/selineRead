package chui.core

import std.math.{abs, cos, sin}
import sdl.{Color, DeviceRotation, Rect, Renderer, Texture, deviceRotationDeltaDegrees}

private let ROTATION_PI: Float64 = 3.141592653589793

/**
 * Host-level whole-frame transition between two normalized device postures.
 *
 * The source and target frames are frozen independently. The source rotates toward the
 * signed posture delta while fading out; the target begins at the opposite signed delta
 * and rotates upright while fading in. Because capture happens above the widget tree,
 * overlays and all rendered descendants rotate together instead of merely switching layout.
 */
public class DeviceRotationTransition {
    private let degrees: Float32
    private let durationMs: Float32
    private let delayMs: Float32
    private let easing: Easing
    private var elapsedMs: Float32 = 0.0
    private var sourceFrame: ?Texture = None
    private var targetFrame: ?Texture = None
    private var sourceWidth: Float32 = 0.0
    private var sourceHeight: Float32 = 0.0
    private var targetWidth: Float32 = 0.0
    private var targetHeight: Float32 = 0.0

    public init(from: DeviceRotation, to: DeviceRotation, animation: AnimationSpec, theme: Theme) {
        this.degrees = deviceRotationDeltaDegrees(from, to)
        this.durationMs = Float32(Int64(animation.resolvedDuration(theme.motionLevel, theme.reduceMotion)))
        this.delayMs = Float32(Int64(animation.delay))
        this.easing = animation.easing
    }

    /** Signed physical turn represented by this transition. */
    public func deltaDegrees(): Float32 { degrees }

    public func progress(): Float32 {
        if (elapsedMs <= delayMs) { return 0.0 }
        min(1.0, (elapsedMs - delayMs) / max(1.0, durationMs))
    }

    public func easedProgress(): Float32 { easing.ease(progress()) }

    public func advance(deltaMs: UInt64): Unit {
        elapsedMs = min(delayMs + durationMs, elapsedMs + Float32(Int64(deltaMs)))
    }

    public func isComplete(): Bool { elapsedMs >= delayMs + durationMs }
    public func snapshotsReady(): Bool { sourceFrame.isSome() && targetFrame.isSome() }

    /**
     * Captures the source on the event frame and the rebuilt target on the following frame.
     * This two-frame contract is what preserves a real responsive re-layout underneath the
     * rotation rather than rotating one stale bitmap and snapping afterward.
     */
    public func prepareNextSnapshot(
        renderer: Renderer,
        width: Float32,
        height: Float32,
        clearColor: Color,
        render: () -> Unit
    ): Bool {
        if (sourceFrame.isNone()) {
            let texture = renderer.createTargetTexture(width, height)
            try {
                renderer.renderToTexture(texture, width, height, clearColor, render)
                sourceFrame = Some(texture)
                sourceWidth = width
                sourceHeight = height
            } catch (error: Exception) {
                texture.close()
                throw error
            }
            return false
        }
        if (targetFrame.isNone()) {
            let texture = renderer.createTargetTexture(width, height)
            try {
                renderer.renderToTexture(texture, width, height, clearColor, render)
                targetFrame = Some(texture)
                targetWidth = width
                targetHeight = height
            } catch (error: Exception) {
                texture.close()
                throw error
            }
        }
        snapshotsReady()
    }

    /** Draws both complete interface snapshots through one signed rotation. */
    public func draw(renderer: Renderer, width: Float32, height: Float32): Unit {
        let p = easedProgress()
        match (sourceFrame) {
            case Some(texture) => drawSnapshot(renderer, texture, sourceWidth, sourceHeight, width, height,
                degrees * p, 1.0 - p)
            case None => ()
        }
        match (targetFrame) {
            case Some(texture) => drawSnapshot(renderer, texture, targetWidth, targetHeight, width, height,
                -degrees * (1.0 - p), p)
            case None => ()
        }
    }

    public func close(): Unit {
        match (sourceFrame) {
            case Some(texture) => texture.close()
            case None => ()
        }
        match (targetFrame) {
            case Some(texture) => texture.close()
            case None => ()
        }
        sourceFrame = None
        targetFrame = None
    }
}

private func drawSnapshot(
    renderer: Renderer,
    texture: Texture,
    sourceWidth: Float32,
    sourceHeight: Float32,
    targetWidth: Float32,
    targetHeight: Float32,
    angleDegrees: Float32,
    opacity: Float32
): Unit {
    if (opacity <= 0.001 || sourceWidth <= 0.0 || sourceHeight <= 0.0) { return }
    let destination = rotatedFitRect(sourceWidth, sourceHeight, targetWidth, targetHeight, angleDegrees)
    texture.setAlpha(Int64(max(0.0, min(255.0, opacity * 255.0))))
    renderer.textureRotated(texture, destination, Float64(angleDegrees))
}

/** Centered destination whose rotated bounds remain inside the target frame. */
protected func rotatedFitRect(
    sourceWidth: Float32,
    sourceHeight: Float32,
    targetWidth: Float32,
    targetHeight: Float32,
    angleDegrees: Float32
): Rect {
    let radians = Float64(angleDegrees) * ROTATION_PI / 180.0
    let c = Float32(abs(cos(radians)))
    let s = Float32(abs(sin(radians)))
    let boundsWidth = max(0.001, sourceWidth * c + sourceHeight * s)
    let boundsHeight = max(0.001, sourceWidth * s + sourceHeight * c)
    let scale = min(targetWidth / boundsWidth, targetHeight / boundsHeight)
    let width = sourceWidth * scale
    let height = sourceHeight * scale
    Rect((targetWidth - width) * 0.5, (targetHeight - height) * 0.5, width, height)
}

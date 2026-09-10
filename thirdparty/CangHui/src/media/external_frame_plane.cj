package chui.media

import sdl.{Rect, Renderer}

/**
 * A snapshot of external video/frame plane state, generalized from the
 * Harmony consumer's external frame adapter.
 */
public struct ExternalFrameSnapshot {
    public let generation: UInt64
    public let width: UInt32
    public let height: UInt32
    public let currentTimeMs: Int64
    public let durationMs: Int64
    public let state: Int32
    public let playing: Bool
    public let prepared: Bool

    public init(
        generation: UInt64,
        width: UInt32,
        height: UInt32,
        currentTimeMs: Int64,
        durationMs: Int64,
        state: Int32,
        playing: Bool,
        prepared: Bool
    ) {
        this.generation = generation
        this.width = width
        this.height = height
        this.currentTimeMs = currentTimeMs
        this.durationMs = durationMs
        this.state = state
        this.playing = playing
        this.prepared = prepared
    }
}

/**
 * Platform-neutral external frame plane. A video/ camera/ external surface
 * provider can render its latest frame into a CangHui Renderer rectangle and
 * expose playback/seek state without CangHui knowing the provider.
 *
 * Harmony providers implement this over their platform bridge and the
 * `CangHUI_ExternalFrame*`
 * C ABI; desktop/media consumers can implement it over their own surface.
 */
public interface ExternalFramePlane {
    /** Renders the current external frame into `frame`; returns true on success. */
    func render(target: Renderer, frame: Rect): Bool

    /** Returns the latest external frame snapshot, or None when unavailable. */
    func snapshot(): ?ExternalFrameSnapshot

    func play(): Bool
    func pause(): Bool
    func seek(positionMs: Int64): Bool
    func close(): Unit
}

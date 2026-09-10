package chui.desktop

// Dirty-frame skipping still polls SDL and the UI-owner queue. A one-millisecond
// idle yield turns that inexpensive poll into a 1000 Hz loop on Harmony devices,
// where SDL_Delay(1) is too fine-grained to keep the renderer thread asleep.
// One display interval keeps input and posted owner work responsive without
// spending a core when the last presented frame is unchanged.
private let IDLE_FRAME_POLL_MS = UInt32(16)

/** Controls how the desktop loop waits between rendered frames. */
public enum FramePacing {
    /** Follow the display through renderer VSync. */
    | Device
    /** Disable VSync and target a fixed number of frames per second. */
    | Fixed(UInt32)
    /** Disable VSync and add no frame-loop delay. */
    | Unbounded
}

/** Stable diagnostic spelling for a public frame-pacing option. */
public func framePacingName(value: FramePacing): String {
    match (value) {
        case FramePacing.Device => "device"
        case FramePacing.Fixed(fps) => "fixed-${fps}fps"
        case FramePacing.Unbounded => "unbounded"
    }
}

internal enum ResolvedFramePacing {
    | Device
    | Fixed(UInt32, UInt32)
    | Unbounded
    | LegacyDelay(UInt32)
}

internal func resolveFramePacing(
    requested: ?FramePacing,
    specVsync: Bool,
    legacyDelay: UInt32,
    kmode: Bool
): ResolvedFramePacing {
    match (requested) {
        case Some(FramePacing.Device) => ResolvedFramePacing.Device
        case Some(FramePacing.Unbounded) => ResolvedFramePacing.Unbounded
        case Some(FramePacing.Fixed(fps)) =>
            if (fps == UInt32(0) || fps > UInt32(1000)) {
                throw IllegalArgumentException("fixed frame pacing must be between 1 and 1000 fps")
            }
            let budget = max(UInt32(1), (UInt32(1000) + fps / UInt32(2)) / fps)
            ResolvedFramePacing.Fixed(fps, budget)
        case None =>
            if (kmode) {
                ResolvedFramePacing.Unbounded
            } else if (specVsync) {
                ResolvedFramePacing.Device
            } else if (legacyDelay > UInt32(0)) {
                ResolvedFramePacing.LegacyDelay(legacyDelay)
            } else {
                ResolvedFramePacing.Unbounded
            }
    }
}

internal func resolvedFramePacingName(value: ResolvedFramePacing): String {
    match (value) {
        case ResolvedFramePacing.Device => "device"
        case ResolvedFramePacing.Fixed(fps, _) => "fixed-${fps}fps"
        case ResolvedFramePacing.Unbounded => "unbounded"
        case ResolvedFramePacing.LegacyDelay(delay) => "legacy-delay-${delay}ms"
    }
}

internal func framePacingUsesVSync(value: ResolvedFramePacing): Bool {
    match (value) {
        case ResolvedFramePacing.Device => true
        case _ => false
    }
}

internal func framePacingDelay(
    value: ResolvedFramePacing,
    elapsedMs: UInt64,
    rendered: Bool
): UInt32 {
    match (value) {
        // A rendered device-paced frame already waited inside present(). An idle loop has no
        // present call, so keep input polling responsive without spinning a full CPU core.
        case ResolvedFramePacing.Device => if (rendered) { UInt32(0) } else { IDLE_FRAME_POLL_MS }
        case ResolvedFramePacing.Fixed(_, budget) =>
            if (elapsedMs >= UInt64(budget)) {
                UInt32(0)
            } else {
                UInt32(UInt64(budget) - elapsedMs)
            }
        // Unbounded applies to rendered frames. An idle dirty-frame loop still yields briefly so
        // kMode does not burn a full core while no frame has been requested.
        case ResolvedFramePacing.Unbounded => if (rendered) { UInt32(0) } else { IDLE_FRAME_POLL_MS }
        case ResolvedFramePacing.LegacyDelay(delay) => delay
    }
}

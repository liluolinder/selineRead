package probe_option_collision_fixture

import chui.*
import sdl.TextureFlip

main(): Int64 {
    // Keep the conflicting SDL constructor visible while all public no-semantics
    // overloads force the framework dependency through a clean/incremental build.
    let _ = TextureFlip.None
    VStack {
        Label("Default").probe("probe-default")
        Label("Typed").probe("probe-typed", "Label")
        Label("Properties").probe("probe-properties", "Label", [
            ProbeProperty("label", "Properties")
        ])
    }
    0
}

# Liquid Glass renderer effects

This framework-owned acceptance scene keeps composition in stock `Surface` and
lets the optional `sdl-readback` renderer-effect adapter sample the colour bands
already painted behind a moving and reshaping card. It also exercises theme,
reduced-transparency and device-rotation fallbacks, then settles so a debug frame
trace can prove idle-pass culling.

Run semantic and trace evidence before the pixel capture, using a source-built
debug CUIC:

```bash
cuic pview . liquid-glass-effects --columns 96 --rows 32
cuic frame trace . --scenario framegraph.rev1
cuic frame replay target/cuic/frame-traces/framegraph.rev1.json --executor null
cuic prnt macos . --output liquid-glass-effects.bmp
```

The first adapter uses bounded synchronous SDL readback and a strict per-frame
pixel/effect budget. It proves the provider-neutral lifecycle on the current
macOS SDL renderer; it does not claim native Apple material identity, private
APIs, shape union, or Metal/Vulkan/D3D/GLES/WebGPU backend completeness.

The fake-host Scene3D preview opts into `PreferSharedFrame`. Its bounded CPU
RGBA8 lease is uploaded into the same SDL target at the widget's ordinary draw
position, so neighboring 2D content, rounded clipping, z-order and resize remain
under CangHui. The lease is reported as `presented` only after the compositor
really sampled it; upload failure finishes it as fallback/executor failure.
This proves the portable software composition path, not native GPU texture/fence
interop or a production 3D renderer. The rev1 Desktop bridge promotes unknown
UI changes to full damage. A debug trace first observes one complete stable
frame, then replays one bounded retained region before later frames prove
whole-root idle culling. SDL reports a full present even for that bounded
redraw, and no present for the culled frames; the trace keeps those facts
separate.

When the adapter is absent, rejects a stale frame, exceeds its budget, or the
user requests reduced transparency, `canghui_style_liquid_glass` keeps the same
content/layout and paints its deterministic SDR/opaque fallback.

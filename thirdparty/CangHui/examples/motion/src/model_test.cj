package chui_motion

private func approxEq(a: Float32, b: Float32): Bool {
    let d = a - b
    (if (d < 0.0) {
        -d
    } else {
        d
    }) < 0.001
}

@Test
func markerXMapsValueToTrack(): Unit {
    @Expect(approxEq(markerX(0.0, 100.0, 500.0), 100.0)) // start
    @Expect(approxEq(markerX(1.0, 100.0, 500.0), 500.0)) // end
    @Expect(approxEq(markerX(0.5, 100.0, 500.0), 300.0)) // midpoint
    // Overshoot (>1, from back easing) travels past the end.
    @Expect(markerX(1.1, 100.0, 500.0) > 500.0)
}

@Test
func tracksCoverTheCurveFamilies(): Unit {
    let tracks = buildTracks()
    @Expect(tracks.size, 7)
    @Expect(tracks[0].label, "Linear")
    // Each track's animator starts at rest at 0.
    for (track in tracks) {
        @Expect(track.animator.settled())
        @Expect(approxEq(track.animator.value, 0.0))
    }
}

@Test
func modelToggleFlipsPlayingAndLabel(): Unit {
    let model = MotionModel()
    @Expect(!model.playing.value)
    @Expect(model.playLabel(), "播放")
    model.toggle()
    @Expect(model.playing.value)
    @Expect(model.playLabel(), "复位")
}

@Test
func playingDrivesTrackAnimatorToOne(): Unit {
    let model = MotionModel()
    model.toggle() // now "playing"
    // Drive one track's animator as the widget would. animate() sets the target itself (a fresh
    // animator starts settled at 0), so drive a fixed number of frames past the 900ms duration.
    let track = model.tracks[0]
    var v: Float32 = 0.0
    for (_ in 0..100) { // 100 * 16ms = 1600ms > 900ms
        v = track.animator.animate(target: 1.0, deltaMs: UInt64(16))
    }
    @Expect(track.animator.settled())
    @Expect(approxEq(v, 1.0))
    @Expect(approxEq(track.animator.value, 1.0))
}

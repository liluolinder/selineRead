package chui_fonts

@Test
func firstExistingPicksFirstPresent(): Unit {
    // Existence is injected, so the pick is deterministic and machine-independent.
    let present = {p: String => p == "/b" || p == "/c"}
    @Expect(firstExisting(["/a", "/b", "/c"], present).getOrThrow(), "/b")
    // None present -> None.
    @Expect(firstExisting(["/a", "/x"], present).isNone())
    // Empty candidates -> None.
    @Expect(firstExisting(Array<String>(), {_ => true}).isNone())
}

@Test
func faceNameMapsSelectionToFamily(): Unit {
    let faces = TYPEFACES
    // The shipped list leads with the system default (no family), then named faces.
    @Expect(faceName(faces, 0).isNone())
    @Expect(faceName(faces, 1).getOrThrow(), "demo-serif")
    @Expect(faceName(faces, 2).getOrThrow(), "demo-mono")
    // Out-of-range selections fall back to the system default (None).
    @Expect(faceName(faces, -1).isNone())
    @Expect(faceName(faces, 99).isNone())
}

@Test
func typefacesCoverSystemSerifMono(): Unit {
    @Expect(TYPEFACES.size, 3)
    @Expect(TYPEFACES[0].family.isNone())
    // Named faces list at least one candidate font file per platform role.
    @Expect(TYPEFACES[1].candidates.size > 0)
    @Expect(TYPEFACES[2].candidates.size > 0)
}

@Test
func modelSelectionDrivesCurrentFace(): Unit {
    let model = FontsModel()
    // Ships selecting the serif face.
    @Expect(model.currentFace().getOrThrow(), "demo-serif")
    @Expect(model.labels().size, 3)
    // Switching selection flows through to the current face.
    model.selected.value = 0
    @Expect(model.currentFace().isNone())
    model.selected.value = 2
    @Expect(model.currentFace().getOrThrow(), "demo-mono")
}

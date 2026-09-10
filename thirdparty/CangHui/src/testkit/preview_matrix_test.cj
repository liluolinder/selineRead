package chui.testkit

import chui.component.{ViewportClass, ViewportSpec, classifyViewport}
import chui.host.HostPlatform

@Test
func viewportClassificationUsesStableCommonBreakpoints(): Unit {
    @Expect(classifyViewport(599.0) == ViewportClass.Compact)
    @Expect(classifyViewport(600.0) == ViewportClass.Medium)
    @Expect(classifyViewport(1023.0) == ViewportClass.Medium)
    @Expect(classifyViewport(1024.0) == ViewportClass.Expanded)
}

@Test
func commonPreviewMatrixCoversCurrentAndPlannedTargets(): Unit {
    let cases = commonPreviewMatrix()
    @Expect(cases.size, 5)
    @Expect(cases[0].targetHost.platform == HostPlatform.Android)
    @Expect(cases[1].targetHost.platform == HostPlatform.HarmonyOS)
    @Expect(cases[3].targetHost.platform == HostPlatform.Desktop)
    @Expect(cases[4].targetHost.platform == HostPlatform.IOS)
    @Expect(cases[0].viewport.widthClass() == ViewportClass.Compact)
    @Expect(cases[2].viewport.widthClass() == ViewportClass.Medium)
    @Expect(cases[3].viewport.widthClass() == ViewportClass.Expanded)
}

@Test
func viewportRejectsInvalidDimensions(): Unit {
    var rejected = false
    try {
        let _ = ViewportSpec("bad", "Bad", 0.0, 800.0)
    } catch (_: IllegalArgumentException) {
        rejected = true
    }
    @Expect(rejected)
}

package chui.host

@Test
func mobileHostNamesStayStableForPlatformAdapters(): Unit {
    @Expect(appLifecycleStateName(AppLifecycleState.Active), "active")
    @Expect(appLifecycleStateName(AppLifecycleState.Background), "background")
    @Expect(systemThemePreferenceName(SystemThemePreference.Unspecified), "unspecified")
    @Expect(touchPhaseName(TouchPhase.Cancelled), "cancelled")
}

@Test
func viewportMetricsApplySafeAreaWithoutGoingNegative(): Unit {
    let metrics = HostViewportMetrics(
        393.0,
        852.0,
        scale: 3.0,
        safeArea: SafeAreaInsets(top: 59.0, right: 0.0, bottom: 34.0, left: 0.0)
    )
    @Expect(metrics.contentWidth(), 393.0)
    @Expect(metrics.contentHeight(), 759.0)

    let exhausted = HostViewportMetrics(
        20.0,
        20.0,
        safeArea: SafeAreaInsets(top: 15.0, right: 15.0, bottom: 15.0, left: 15.0)
    )
    @Expect(exhausted.contentWidth(), 0.0)
    @Expect(exhausted.contentHeight(), 0.0)
}

@Test
func mobileBoundaryValuesRemainPlatformNeutral(): Unit {
    let touch = TouchEvent(TouchPhase.Began, [TouchPoint(7, 120.0, 240.0)], 1234)
    @Expect(touch.points.size, 1)
    @Expect(touch.points[0].id, 7)

    let resource = PlatformResourceRef("picked-1", "photo.jpg", "opaque-bookmark-token")
    let request = FilePickerRequest(FilePickerMode.OpenFile, allowedContentTypes: ["public.image"])
    @Expect(resource.displayName, "photo.jpg")
    @Expect(request.allowedContentTypes.size, 1)
}

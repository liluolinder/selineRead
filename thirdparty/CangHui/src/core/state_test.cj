package chui.core

import sdl.{Rect, Renderer, Size, UiEvent}

private class ClearRememberedStateDuringHandle <: Widget {
    private let store: StateStore

    init(store: StateStore) { this.store = store }

    public func measure(_: UiContext, available: Size): Size { available }
    public func layout(_: UiContext, _: Rect): Unit {}
    public func draw(_: UiContext): Unit {}
    public func handle(_: UiContext, _: UiEvent): Bool {
        store.clear()
        true
    }
}

@Test
func stateTracksRevisionAndCancellableObservers(): Unit {
    let state = State<Int64>(2)
    let observedTotal = State<Int64>(0)
    let observation = state.observe({previous, current => observedTotal.value += previous + current})

    state.update({value => value + 3})

    @Expect(state.value, Int64(5))
    @Expect(state.revision, UInt64(1))
    @Expect(observedTotal.value, Int64(7))

    observation.close()
    state.value = 9
    @Expect(observedTotal.value, Int64(7))
    @Expect(observation.isClosed())
}

@Test
func rememberedStateSurvivesRebuildAndResetsAfterUnmount(): Unit {
    let store = StateStore()
    let captured = State<?State<Int64>>(None)

    let _ = buildRoot(
        {
            =>
                let local = rememberState<Int64>("count") {1}
                captured.value = Some(local)
                Spacer()
        },
        store
    )
    let first = captured.value.getOrThrow()
    first.value = 42

    let _ = buildRoot(
        {
            =>
                captured.value = Some(rememberState<Int64>("count") {1})
                Spacer()
        },
        store
    )
    let second = captured.value.getOrThrow()
    @Expect(refEq((first as Object).getOrThrow(), (second as Object).getOrThrow()))
    @Expect(second.value, Int64(42))

    let _ = buildRoot({=> Spacer()}, store)
    let _ = buildRoot(
        {
            =>
                captured.value = Some(rememberState<Int64>("count") {7})
                Spacer()
        },
        store
    )
    let third = captured.value.getOrThrow()
    @Expect(!refEq((first as Object).getOrThrow(), (third as Object).getOrThrow()))
    @Expect(third.value, Int64(7))
}

@Test
func keyedScopesIsolateRepeatedLocalStateNames(): Unit {
    let store = StateStore()
    let first = State<?State<Int64>>(None)
    let second = State<?State<Int64>>(None)

    let _ = buildRoot({
        => VStack {
            Keyed("first") {
                first.value = Some(rememberState<Int64>("selected") {1})
                Spacer()
            }
            Keyed("second") {
                second.value = Some(rememberState<Int64>("selected") {2})
                Spacer()
            }
        }
    }, store)

    @Expect(first.value.getOrThrow().value, Int64(1))
    @Expect(second.value.getOrThrow().value, Int64(2))
}

@Test
func duplicateRememberedStateKeyFailsFast(): Unit {
    let store = StateStore()
    var didThrow = false

    try {
        let _ = buildRoot(
            {
                =>
                    let _ = rememberState<Int64>("duplicate") {1}
                    let _ = rememberState<Int64>("duplicate") {2}
                    Spacer()
            },
            store
        )
    } catch (_: IllegalStateException) {
        didThrow = true
    }

    @Expect(didThrow)
}

@Test
func forEachKeyedStateFollowsItemAcrossReorder(): Unit {
    let store = StateStore()
    let first = State<?State<Int64>>(None)
    let second = State<?State<Int64>>(None)
    let build = {
        items: Array<String> =>
            let _ = buildRoot({
                => VStack {
                    ForEach(items, key: {item => item}) {
                        item =>
                            let local = rememberState<Int64>("count") {0}
                            if (item == "a") {
                                first.value = Some(local)
                            } else {
                                second.value = Some(local)
                            }
                            Spacer()
                    }
                }
            }, store)
    }

    build(["a", "b"])
    first.value.getOrThrow().value = 11
    second.value.getOrThrow().value = 22

    // After a reorder each item still sees its own state, keyed by identity not position.
    build(["b", "a"])
    @Expect(first.value.getOrThrow().value, Int64(11))
    @Expect(second.value.getOrThrow().value, Int64(22))
}

@Test
func retainedRememberedStatePruneCommitsOnlyWithPresentedFrame(): Unit {
    let store = StateStore()
    let captured = State<?State<Int64>>(None)
    let _ = buildRoot({=>
        captured.value = Some(rememberState<Int64>("kept") {1})
        Spacer()
    }, store)
    let first = captured.value.getOrThrow()
    first.value = 41

    // Omitting the state only stages its unmount. A frame that never presents restores it.
    let _ = buildRetainedRoot({=> Spacer()}, store, 1)
    store.cancelRetainedFrame()
    let _ = buildRoot({=>
        captured.value = Some(rememberState<Int64>("kept") {7})
        Spacer()
    }, store)
    let restored = captured.value.getOrThrow()
    @Expect(refEq((first as Object).getOrThrow(), (restored as Object).getOrThrow()))
    @Expect(restored.value, Int64(41))

    // Once the retained frame commits, the same omission becomes an actual unmount.
    let _ = buildRetainedRoot({=> Spacer()}, store, 1)
    let _ = store.finishRetainedFrame()
    let _ = buildRoot({=>
        captured.value = Some(rememberState<Int64>("kept") {9})
        Spacer()
    }, store)
    let replaced = captured.value.getOrThrow()
    @Expect(!refEq((first as Object).getOrThrow(), (replaced as Object).getOrThrow()))
    @Expect(replaced.value, Int64(9))
}

@Test
func retainedCancelledFrameRollsBackNewRememberedState(): Unit {
    let store = StateStore()
    let cancelled = State<?State<Int64>>(None)
    let _ = buildRetainedRoot({=>
        cancelled.value = Some(rememberState<Int64>("ephemeral") {3})
        Spacer()
    }, store, 1)
    let abandoned = cancelled.value.getOrThrow()
    store.cancelRetainedFrame()

    let _ = buildRoot({=>
        cancelled.value = Some(rememberState<Int64>("ephemeral") {8})
        Spacer()
    }, store)
    let rebuilt = cancelled.value.getOrThrow()
    @Expect(!refEq((abandoned as Object).getOrThrow(), (rebuilt as Object).getOrThrow()))
    @Expect(rebuilt.value, Int64(8))
}

@Test
func clearRememberedStateDuringRetainedHitTestDefersToSafeBoundary(): Unit {
    let store = StateStore()
    let captured = State<?State<Int64>>(None)
    let _ = buildRoot({=>
        captured.value = Some(rememberState<Int64>("value") {4})
        Spacer()
    }, store)
    let previous = captured.value.getOrThrow()

    let root = buildRetainedRoot({=> emit(ClearRememberedStateDuringHandle(store))}, store, 1)
    let ctx = UiContext(Renderer.headless(), Theme.light())
    root.layout(ctx, Rect(0.0, 0.0, 40.0, 20.0))
    @Expect(root.handle(ctx, UiEvent.Quit))
    // The callback did not cancel the active HitTest phase; reset happens after this frame settles.
    @Expect(store.retainedFrameActive())
    let _ = store.finishRetainedFrame()
    @Expect(!store.retainedFrameActive())

    let _ = buildRoot({=>
        captured.value = Some(rememberState<Int64>("value") {12})
        Spacer()
    }, store)
    let reset = captured.value.getOrThrow()
    @Expect(!refEq((previous as Object).getOrThrow(), (reset as Object).getOrThrow()))
    @Expect(reset.value, Int64(12))
}

@Test
func retainedBuildSetupFailureRestoresGlobalBuildScopeWithoutCancellingPriorFrame(): Unit {
    let store = StateStore()
    store.beginRetainedFrame(1)
    var didThrow = false
    try {
        let _ = buildRetainedRoot({=> Spacer()}, store, 2)
    } catch (_: IllegalStateException) {
        didThrow = true
    }
    @Expect(didThrow)
    @Expect(store.retainedFrameActive())

    var leakedBuildScope = false
    try {
        let _ = rememberState<Int64>("outside") {1}
        leakedBuildScope = true
    } catch (_: IllegalStateException) {}
    @Expect(!leakedBuildScope)
    store.cancelRetainedFrame()
}

// `.enabled(false)` takes a control out of Tab traversal for the frame: a stop that ignores
// Enter/Space would be a dead end. Re-enabling (or `.enabled(true)`) keeps the stop.

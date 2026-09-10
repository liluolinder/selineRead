package chui.controls

import chui.core.{Widget, buildChild, focusableCountNow, focusablesSince, unregisterFocusable}

/** Builds decorative control content while keeping the outer control as the only focus owner. */
protected func buildDecorativeControlChild(body: () -> Unit): Widget {
    let focusStart = focusableCountNow()
    let child = buildChild(body)
    for (id in focusablesSince(focusStart)) {
        unregisterFocusable(id)
    }
    child
}

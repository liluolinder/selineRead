package chui_layout_transition

import chui.State

class LayoutTransitionModel {
    let reversed = State<Bool>(false)
    let columns = State<Int64>(3)

    func items(): Array<String> {
        if (reversed.value) {
            ["signal", "route", "station", "vehicle", "energy", "crew"]
        } else {
            ["crew", "energy", "vehicle", "station", "route", "signal"]
        }
    }

    func reorder(): Unit { reversed.value = !reversed.value }

    func toggleColumns(): Unit {
        columns.value = if (columns.value == 3) { 2 } else { 3 }
    }

    func layoutText(): String {
        "${columns.value} columns · ${if (reversed.value) { "reverse" } else { "forward" }}"
    }
}

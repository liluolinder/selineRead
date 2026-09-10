package chui_layout_transition

import chui.*

func layoutTransitionView(model: LayoutTransitionModel): Unit {
    VStack {
        VStack {
            Label("Keyed layout continuity").fontSize(26.fp).bold()
            Label("The parent switches order and column count immediately; each stable key carries its visible geometry to the new cell.")
                .fontSize(13.fp).muted().wrap()
        }.spacing(5.vp).crossAxisAlignment(CrossAxisAlignment.Start).hug()

        HStack {
            Button("Reverse order", probedAction("layout.reorder", {=> model.reorder()}),
                role: ButtonRole.Primary).key("layout-reorder")
            Button("${if (model.columns.value == 3) { "Use 2 columns" } else { "Use 3 columns" }}",
                probedAction("layout.columns", {=> model.toggleColumns()})).key("layout-columns")
            Spacer()
            Label(model.layoutText()).fontSize(13.fp).muted()
        }.spacing(10.vp).crossAxisAlignment(CrossAxisAlignment.Center).hug()

        Divider()

        Grid(model.columns.value) {
            for (item in model.items()) {
                KeyedLayoutTransition(
                    item,
                    animation: AnimationSpec(duration: UInt64(360), easing: Easing.EaseOutCubic),
                    clip: LayoutTransitionClip.AnimatedBounds
                ) {
                    transitionCard(item)
                }
            }
        }.spacing(12.vp).flex()

        Panel {
            HStack {
                Icon(IconName.Process).iconSize(16.vp)
                Label("Focus and hit testing already belong to the target cells while pixels are still travelling.")
                    .fontSize(12.fp).muted().wrap()
            }.spacing(8.vp).crossAxisAlignment(CrossAxisAlignment.Center)
        }.contentPadding(12.vp).hug()
    }.spacing(16.vp).padding(22.vp)
}

private func transitionCard(id: String): Unit {
    Panel {
        VStack {
            HStack {
                Icon(cardIcon(id)).foregroundColor(cardColor(id)).iconSize(20.vp)
                Spacer()
                Label(id).fontSize(10.fp).muted()
            }.crossAxisAlignment(CrossAxisAlignment.Center).hug()
            Spacer()
            Label(cardTitle(id)).fontSize(17.fp).bold()
            Label(cardDetail(id)).fontSize(12.fp).muted().wrap().maxLines(2)
        }.spacing(4.vp)
    }.contentPadding(14.vp).height(126.vp).probe(
        "layout-card-${id}",
        "KeyedLayoutTransition",
        [
            ProbeProperty("label", cardTitle(id)),
            ProbeProperty("key", id),
            ProbeProperty("role", "reorderable-card")
        ]
    )
}

private func cardTitle(id: String): String {
    match (id) {
        case "crew" => "Crew"
        case "energy" => "Energy"
        case "vehicle" => "Vehicle"
        case "station" => "Station"
        case "route" => "Route"
        case _ => "Signal"
    }
}

private func cardDetail(id: String): String {
    match (id) {
        case "crew" => "Shift and readiness"
        case "energy" => "Traction power"
        case "vehicle" => "Fleet telemetry"
        case "station" => "Platform state"
        case "route" => "Path continuity"
        case _ => "Interlocking health"
    }
}

private func cardIcon(id: String): IconName {
    match (id) {
        case "crew" => IconName.Process
        case "energy" => IconName.Refresh
        case "vehicle" => IconName.ChevronRight
        case "station" => IconName.OpenFolder
        case "route" => IconName.Calendar
        case _ => IconName.Save
    }
}

private func cardColor(id: String): Color {
    match (id) {
        case "crew" => Color(112, 171, 255)
        case "energy" => Color(255, 198, 88)
        case "vehicle" => Color(102, 213, 171)
        case "station" => Color(193, 143, 255)
        case "route" => Color(255, 137, 164)
        case _ => Color(116, 211, 236)
    }
}

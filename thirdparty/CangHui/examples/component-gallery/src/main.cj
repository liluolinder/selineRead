package canghui_component_gallery

import std.env.getCommandLine
import std.convert.*
import chui.*
import chui.kmode.macros.*
import canghui_gallery_components.*

@KModeLink["gallery.api.version"]
func galleryApiVersion(_: String): String {
    componentApiVersion()
}

@KModeLink["gallery.viewport.class"]
func galleryViewportClass(value: String): String {
    match (classifyViewport(Float32.parse(value))) {
        case ViewportClass.Compact => "compact"
        case ViewportClass.Medium => "medium"
        case ViewportClass.Expanded => "expanded"
    }
}

@CuiProbe["gallery.primary-button"]
func galleryPrimaryButtonProbe(script: String): String {
    let clicks = State<Int64>(0)
    ComponentProbe("gallery.primary-button", width: 320.0, height: 120.0).run(script) {
        ProbeNode("gallery-root", widgetType: "VStack",
            properties: [ProbeProperty("role", "fixture")]) {
            VStack(padding: LengthInsets(16.vp)) {
                Button("Run probe", probedAction("primary-button.click", { => clicks.value += 1 }),
                    role: ButtonRole.Primary)
                    .key("primary-button")
                    .probe(
                        "primary-button",
                        "Button",
                        [ProbeProperty("label", "Run probe")],
                        { => [
                            ProbeProperty("clicks", clicks.value.toString()),
                            ProbeProperty("disabled", "false"),
                            ProbeProperty("selected", (clicks.value > 0).toString())
                        ] }
                    )
            }
        }
    }
}

private func previewLabels(): Array<String> {
    ["Android", "Harmony", "Tablet", "Desktop", "iOS layout"]
}

private func previewHeight(viewport: ViewportSpec): Float32 {
    if (viewport.height > 790.0) {
        790.0
    } else {
        viewport.height
    }
}

private func initialPreviewIndex(): Int64 {
    let args = getCommandLine()
    var i = 0
    while (i < args.size - 1) {
        if (args[i] == "--preview") {
            return previewIndex(args[i + 1])
        }
        i += 1
    }
    1
}

private func initialDarkMode(): Bool {
    let args = getCommandLine()
    var i = 0
    while (i < args.size - 1) {
        if (args[i] == "--theme") {
            return args[i + 1] != "light"
        }
        i += 1
    }
    true
}

private func initialMotionIndex(): Int64 {
    let args = getCommandLine()
    var i = 0
    while (i < args.size - 1) {
        if (args[i] == "--motion") {
            return match (args[i + 1]) {
                case "basic" => 0
                case "full" => 2
                case _ => 1
            }
        }
        i += 1
    }
    1
}

private func motionLevel(index: Int64): MotionLevel {
    match (index) {
        case 0 => MotionLevel.Basic
        case 2 => MotionLevel.Full
        case _ => MotionLevel.Standard
    }
}

private func galleryTheme(dark: Bool, motionIndex: Int64): Theme {
    if (dark) {
        Theme.dark(motionLevel: motionLevel(motionIndex))
    } else {
        Theme.light(motionLevel: motionLevel(motionIndex))
    }
}

private func transitionThemeArgument(): ?Bool {
    let args = getCommandLine()
    var i = 0
    while (i < args.size - 1) {
        if (args[i] == "--transition-theme") {
            return Some(args[i + 1] == "dark")
        }
        i += 1
    }
    None
}

private func initialGallerySection(): Int64 {
    let args = getCommandLine()
    var i = 0
    while (i < args.size - 1) {
        if (args[i] == "--section") {
            return match (args[i + 1]) {
                case "selection" => 1
                case "navigation" => 2
                case "feedback" => 3
                case "symbol" | "symbols" => 4
                case _ => 0
            }
        }
        i += 1
    }
    0
}

private func previewIndex(value: String): Int64 {
    match (value) {
        case "android" => 0
        case "harmony" => 1
        case "tablet" => 2
        case "desktop" => 3
        case "ios" => 4
        case _ => 1
    }
}

main(): Int64 {
    if (runKModeStdioIfRequested()) {
        return 0
    }
    registerCangHuiSymbols()
    let previews = commonPreviewMatrix()
    let selectedPreview = State<Int64>(initialPreviewIndex())
    let transitionTarget = transitionThemeArgument()
    let startsDark = match (transitionTarget) {
        case Some(targetDark) => !targetDark
        case None => initialDarkMode()
    }
    let darkMode = State<Bool>(startsDark)
    let motionIndex = State<Int64>(initialMotionIndex())
    let galleryState = GallerySurfaceState()
    galleryState.selectedSection.value = initialGallerySection()
    let app = DesktopApp(
        WindowSpec("CangHui Component Gallery", 1500, 980, scale: 1.0),
        theme: galleryTheme(darkMode.value, motionIndex.value)
    )
    match (transitionTarget) {
        case Some(_) =>
            // Drive the real IconButton route so the proof includes its local InkWell.
            app.queuePointerClick(1338.0, 52.0)
        case None => ()
    }
    app.setMinimumSize(1000, 760)
    app.run {
        let active = previews[selectedPreview.value]
        VStack {
            HStack {
                VStack {
                    Label("Component Gallery", fontSize: 24.fp)
                    Label("${active.label} / common-layout preview", muted: true)
                }.spacing(2.vp).hug()
                Spacer()
                Label("Motion", muted: true)
                Button("Basic", {=>
                    motionIndex.value = 0
                    app.setTheme(galleryTheme(darkMode.value, motionIndex.value))
                }, role: if (motionIndex.value == 0) { ButtonRole.Primary } else { ButtonRole.Normal })
                    .key("gallery-motion-basic")
                Button("Standard", {=>
                    motionIndex.value = 1
                    app.setTheme(galleryTheme(darkMode.value, motionIndex.value))
                }, role: if (motionIndex.value == 1) { ButtonRole.Primary } else { ButtonRole.Normal })
                    .key("gallery-motion-standard")
                Button("Full", {=>
                    motionIndex.value = 2
                    app.setTheme(galleryTheme(darkMode.value, motionIndex.value))
                }, role: if (motionIndex.value == 2) { ButtonRole.Primary } else { ButtonRole.Normal })
                    .key("gallery-motion-full")
                Tooltip(text: if (darkMode.value) { "切换到浅色" } else { "切换到深色" }) {
                    IconButton(if (darkMode.value) { IconName.Sun } else { IconName.Moon }) {
                        darkMode.value = !darkMode.value
                        app.transitionTheme(galleryTheme(darkMode.value, motionIndex.value))
                    }.key("gallery-theme-toggle")
                }
                Label("CangHui API ${componentApiVersion()}", muted: true)
            }.hug()
            SegmentedControl(previewLabels(), selectedPreview, key: "preview-target")
            Divider()
            HStack {
                Spacer()
                Panel(flexible: false) {
                    galleryCommonSurface(active.componentContext(), galleryState)
                }.width(active.viewport.width).height(previewHeight(active.viewport))
                Spacer()
            }
        }.spacing(16.vp).padding(20.vp)
    }
    return 0
}

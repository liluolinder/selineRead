package canghui_gallery_components

import chui.*

public class GalleryComponentPackage <: ComponentPackage {
    public func descriptor(): ComponentPackageDescriptor {
        galleryPackageDescriptor()
    }
}

public func galleryPackageDescriptor(): ComponentPackageDescriptor {
    ComponentPackageDescriptor(
        "canghui.gallery.common",
        "CangHui Gallery Common Components",
        "0.3.0"
    )
}

/** State owned by the consumer and retained while viewport or theme settings change. */
public class GallerySurfaceState {
    public let selectedSection = State<Int64>(0)
    public let notificationsEnabled = State<Bool>(true)
    public let checkboxEnabled = State<Bool>(true)
    public let selectedChoice = State<Int64>(1)
    public let sliderValue = State<Float32>(0.62)
    public let stepperValue = State<Int64>(3)
    public let pickerValue = State<Int64>(1)
    public let fieldText = State<String>("CangHui")
    public let dropdownValue = State<Int64>(1)
    public let overviewProgress = State<Float32>(0.68)
    public let architectureChip = State<Bool>(true)
    public let toolingChip = State<Bool>(false)
    public let rating = State<Int64>(4)
    public let page = State<Int64>(2)
    public let step = State<Int64>(1)
    public let breadcrumbIndex = State<Int64>(2)
}

/** One named component catalogue rendered unchanged for compact, medium and expanded hosts. */
public func galleryCommonSurface(context: ComponentContext, state: GallerySurfaceState): Unit {
    match (context.viewport.widthClass()) {
        case ViewportClass.Compact => compactSurface(context, state)
        case ViewportClass.Medium => mediumSurface(context, state)
        case ViewportClass.Expanded => expandedSurface(context, state)
    }
}

private func compactSurface(context: ComponentContext, state: GallerySurfaceState): Unit {
    VStack {
        surfaceHeader(context)
        SegmentedControl(["Actions", "Selection", "Navigation", "Feedback", "Symbols"], state.selectedSection,
            key: "gallery-compact-sections")
        Divider()
        galleryScroll(context, state, "gallery-compact-scroll")
    }.spacing(12.vp).padding(16.vp)
}

private func mediumSurface(context: ComponentContext, state: GallerySurfaceState): Unit {
    VStack {
        surfaceHeader(context)
        SegmentedControl(["Actions", "Selection", "Navigation", "Feedback", "Symbols"], state.selectedSection,
            key: "gallery-medium-sections")
        Divider()
        galleryScroll(context, state, "gallery-medium-scroll")
    }.spacing(14.vp).padding(20.vp)
}

private func expandedSurface(context: ComponentContext, state: GallerySurfaceState): Unit {
    HStack {
        VStack {
            Label("CangHui", fontSize: 20.fp)
            Label("Component catalogue", muted: true)
            Divider()
            sectionButton("Actions", 0, state)
            sectionButton("Selection", 1, state)
            sectionButton("Navigation", 2, state)
            sectionButton("Feedback", 3, state)
            sectionButton("Symbols", 4, state)
            Spacer()
            Label("Common package 0.3.0", muted: true)
        }.spacing(8.vp).hug().padding(18.vp).width(220.vp)
        Divider()
        VStack {
            surfaceHeader(context)
            Divider()
            galleryScroll(context, state, "gallery-expanded-scroll")
        }.spacing(14.vp).padding(22.vp)
    }.spacing(0.vp)
}

private func sectionButton(title: String, index: Int64, state: GallerySurfaceState): Unit {
    Button(title, {=> state.selectedSection.value = index},
        role: if (state.selectedSection.value == index) { ButtonRole.Primary } else { ButtonRole.Normal })
        .key("gallery-section-${index}")
}

private func surfaceHeader(context: ComponentContext): Unit {
    match (context.viewport.widthClass()) {
        case ViewportClass.Compact => VStack {
            Label(sectionTitle(context.viewport.widthClass()), fontSize: 22.fp)
            Label("${context.viewport.label} / ${hostPlatformName(context.host.platform)}", muted: true)
        }.spacing(2.vp).hug()
        case _ => HStack {
            VStack {
                Label(sectionTitle(context.viewport.widthClass()), fontSize: 22.fp)
                Label("${context.viewport.label} / ${hostPlatformName(context.host.platform)}", muted: true)
            }.spacing(2.vp).hug()
            Spacer()
            Badge("named specimens", kind: BadgeKind.Info)
        }.hug()
    }
}

private func galleryScroll(context: ComponentContext, state: GallerySurfaceState, key: String): Unit {
    ScrollView(key: key) {
        match (state.selectedSection.value) {
            case 1 => selectionComponents(state)
            case 2 => navigationComponents(state)
            case 3 => feedbackComponents(state)
            case 4 => symbolComponents()
            case _ => actionComponents(context.viewport.widthClass(), state)
        }
    }
}

private func actionComponents(viewportClass: ViewportClass, state: GallerySurfaceState): Unit {
    VStack {
        categoryHeader("Actions", "Unified press, hover, cancellation and automatic motion")
        specimen("Button", "chui.Button") {
            buttonSpecimen(viewportClass)
        }
        specimen("IconButton", "chui.IconButton") {
            FlowRow {
                IconButton(IconName.Save) {=> ()}
                IconButton(IconName.Refresh, label: Some("Refresh")) {=> ()}
                IconButton(IconName.Trash, label: Some("Delete"), role: ButtonRole.Danger) {=> ()}
            }.spacing(10.vp)
        }
        specimen("Chip", "chui.Chip") {
            FlowRow {
                Chip("Architecture", state.architectureChip, key: "gallery-chip-architecture")
                Chip("Tooling", state.toolingChip, key: "gallery-chip-tooling")
            }.spacing(10.vp)
        }
        specimen("Badge", "chui.Badge") {
            FlowRow {
                Badge("stable", kind: BadgeKind.Success)
                Badge("interactive", kind: BadgeKind.Accent)
                Badge("attention", kind: BadgeKind.Warning)
                Badge("blocked", kind: BadgeKind.Danger)
            }.spacing(8.vp)
        }
    }.spacing(14.vp).padding(2.vp)
}

private func buttonSpecimen(viewportClass: ViewportClass): Unit {
    match (viewportClass) {
        case ViewportClass.Compact => VStack {
            HStack {
                Button("Normal", {=> ()})
                Button("Primary", {=> ()}, role: ButtonRole.Primary)
                Button("Danger", {=> ()}, role: ButtonRole.Danger)
            }.spacing(10.vp).hug()
            HStack {
                Button("Custom 320ms", {=> ()}, role: ButtonRole.Primary)
                    .animation(UInt64(320), easing: Easing.EaseOutBack)
            }.hug()
        }.spacing(16.vp).hug()
        case _ => FlowRow {
            Button("Normal", {=> ()})
            Button("Primary", {=> ()}, role: ButtonRole.Primary)
            Button("Danger", {=> ()}, role: ButtonRole.Danger)
            Button("Custom 320ms", {=> ()}, role: ButtonRole.Primary)
                .animation(UInt64(320), easing: Easing.EaseOutBack)
        }.spacing(10.vp)
    }
}

private func selectionComponents(state: GallerySurfaceState): Unit {
    VStack {
        categoryHeader("Selection", "Bound state, keyboard focus and animated value changes")
        specimen("Checkbox / Switch", "chui.Checkbox + chui.Switch") {
            FlowRow {
                Checkbox("Build checks", state.checkboxEnabled).key("gallery-checkbox")
                Switch("Notifications", state.notificationsEnabled).key("gallery-switch")
            }.spacing(18.vp)
        }
        specimen("RadioButton", "chui.RadioButton") {
            FlowRow {
                RadioButton("Basic", state.selectedChoice, 0).key("gallery-radio-basic")
                RadioButton("Standard", state.selectedChoice, 1).key("gallery-radio-standard")
                RadioButton("Full", state.selectedChoice, 2).key("gallery-radio-full")
            }.spacing(14.vp)
        }
        specimen("Slider / Stepper", "chui.Slider + chui.Stepper") {
            HStack {
                Slider(state.sliderValue, key: "gallery-slider").width(260.vp)
                Stepper(state.stepperValue, key: "gallery-stepper", lower: 0, upper: 9)
            }.spacing(18.vp).hug()
        }
        specimen("Picker / Rating", "chui.Picker + chui.Rating") {
            FlowRow {
                Picker(["Basic", "Standard", "Full"], state.pickerValue, key: "gallery-picker")
                Rating(state.rating, key: "gallery-rating")
            }.spacing(18.vp)
        }
    }.spacing(14.vp).padding(2.vp)
}

private func navigationComponents(state: GallerySurfaceState): Unit {
    VStack {
        categoryHeader("Navigation", "Location, progress and disclosure components")
        specimen("Breadcrumb", "chui.Breadcrumb") {
            Breadcrumb(["CangHui", "Navigation", "Motion", "Current"], maxItems: 4,
                clickable: true, historyShow: true, history: Some(state.breadcrumbIndex),
                onSelect: {_ => ()}, key: "gallery-breadcrumb")
        }
        specimen("Pagination", "chui.Pagination") {
            Pagination(8, state.page, key: "gallery-pagination")
        }
        specimen("StepIndicator", "chui.StepIndicator") {
            VStack {
                StepIndicator(["Pull", "Merge", "Prove", "Ship"], state.step.value,
                    onSelect: {index => state.step.value = index}, key: "gallery-steps")
                    .animation(AnimationSpec.automatic(duration: Motion.slow, easing: Motion.standard))
                HStack {
                    Button("Previous", {=> state.step.value = max(0, state.step.value - 1)})
                        .key("gallery-steps-previous")
                    Button("Next", {=> state.step.value = min(3, state.step.value + 1)}, role: ButtonRole.Primary)
                        .key("gallery-steps-next")
                }.spacing(10.vp).hug()
            }.spacing(10.vp).hug()
        }
        specimen("Accordion", "chui.Accordion") {
            Accordion([
                AccordionSection("Interaction contract") {=>
                    Label("Press inside, move-out cancellation, and release-inside activation share one route.",
                        muted: true).wrap()
                },
                AccordionSection("Motion contract") {=>
                    Label("Basic, Standard and Full select automatic expression while explicit timings remain exact.",
                        muted: true).wrap()
                },
                AccordionSection("Platform boundary") {=>
                    Label("Native rendering and host services remain adapter-owned.", muted: true).wrap()
                }
            ], single: true, initiallyExpanded: [0], key: "gallery-accordion")
        }
    }.spacing(14.vp).padding(2.vp)
}

private func feedbackComponents(state: GallerySurfaceState): Unit {
    VStack {
        categoryHeader("Feedback", "Status, progress and editable value specimens")
        specimen("ProgressBar / ProgressRing", "chui.ProgressBar + chui.ProgressRing") {
            HStack {
                ProgressRing(state.overviewProgress.value, diameter: 68.0, thickness: 7.0)
                VStack {
                    Label("Coverage ${Int64(state.overviewProgress.value * 100.0)}%")
                    ProgressBar(state.overviewProgress)
                }.spacing(8.vp)
            }.spacing(18.vp).hug()
        }
        specimen("TextField", "chui.TextField") {
            TextField(state.fieldText, key: "gallery-text-field").width(320.vp)
        }
        specimen("Dropdown", "chui.Dropdown") {
            Dropdown(["Basic motion", "Standard motion", "Full motion"], state.dropdownValue,
                key: "gallery-dropdown")
        }
        specimen("Divider / Label", "chui.Divider + chui.Label") {
            VStack {
                Label("Primary label")
                Divider()
                Label("Muted supporting label", muted: true)
            }.spacing(8.vp)
        }
    }.spacing(14.vp).padding(2.vp)
}

private func symbolComponents(): Unit {
    VStack {
        categoryHeader("Symbols", "Provider-neutral names, declared subsets and deterministic fallback")
        specimen("Symbol", "chui.Symbol") {
            FlowRow {
                symbolSpecimen("Built-in", SymbolName("save", provider: "builtin"))
                symbolSpecimen("Material", material_add, variant: SymbolVariant.Filled)
                symbolSpecimen("Ant Design", ant_check)
                symbolSpecimen("Arco RTL", arco_right, direction: SymbolDirection.RightToLeft)
                symbolSpecimen("Fallback", SymbolName("not-present", provider: "material"),
                    detail: "missing -> builtin")
            }.spacing(14.vp)
        }
        specimen("Icon compatibility", "chui.Icon + chui.IconButton") {
            FlowRow {
                Icon(material_add, size: 24.vp)
                Icon(ant_check, size: 24.vp)
                IconButton(arco_right, label: Some("Continue")) {=> ()}
            }.spacing(12.vp)
        }
    }.spacing(14.vp).padding(2.vp)
}

private func symbolSpecimen(label: String, name: SymbolName,
    variant!: SymbolVariant = SymbolVariant.Outlined,
    direction!: SymbolDirection = SymbolDirection.Inherit,
    detail!: String = ""): Unit {
    VStack {
        Symbol(name, size: 30.vp, weight: 520.0, variant: variant,
            direction: direction, accessibilityLabel: label)
        Label(label)
        Label(if (detail.isEmpty()) { name.qualified() } else { detail }, muted: true).wrap()
    }.spacing(4.vp).hug().width(128.vp)
}

private func categoryHeader(title: String, description: String): Unit {
    VStack {
        Label(title, fontSize: 19.fp)
        Label(description, muted: true).wrap()
    }.spacing(3.vp).hug()
}

private func specimen(title: String, api: String, body: () -> Unit): Unit {
    VStack {
        HStack {
            Label(title, fontSize: 16.fp)
            Spacer()
            Badge(api, kind: BadgeKind.Info)
        }.hug()
        body()
        Divider()
    }.spacing(9.vp).hug()
}

private func sectionTitle(viewportClass: ViewportClass): String {
    match (viewportClass) {
        case ViewportClass.Compact => "Compact catalogue"
        case ViewportClass.Medium => "Medium catalogue"
        case ViewportClass.Expanded => "Expanded catalogue"
    }
}

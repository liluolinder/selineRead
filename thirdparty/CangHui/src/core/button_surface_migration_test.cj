package chui.core

import sdl.{Color, IconName, SurfaceStyle}

private func migrationButtonStyle(radius: Float32, fill: Color, ink: Color): ButtonStyle {
    ButtonStyle(resolve: {_, _, _ =>
        ButtonAppearance(
            surface: SurfaceStyle(fill, radius: radius),
            foreground: Color.rgb(245, 246, 247),
            ink: ink,
            focusRadius: radius
        )
    })
}

@Test
func migratedButtonKeepsLegacySemanticsAndButtonStyleInkGeometry(): Unit {
    let report = ComponentProbe("test.migrated-button", width: 180.0, height: 70.0).run(
        "press 40 30\nrelease 40 30\nassert activation migrated.button 1"
    ) {
        Button("Migrate", probedAction("migrated.button", {=> ()}))
            .key("migrated-button")
            .buttonStyle(migrationButtonStyle(
                13.0,
                Color.rgb(21, 42, 63),
                Color.rgb(111, 122, 133)
            ))
    }
    @Expect(report.contains("\"id\":\"control-semantic:migrated-button\""))
    @Expect(report.contains("\"type\":\"Button\""))
    @Expect(report.contains("Button.activate()"))
    @Expect(!report.contains("InteractionSurface.activate()"))
    @Expect(report.contains("\"kind\":\"paint.ripple\""))
    @Expect(report.contains("\"cornerRadius\":12.000000"))
}

@Test
func migratedIconButtonKeepsLegacySemanticsAndButtonStyleInkGeometry(): Unit {
    let report = ComponentProbe("test.migrated-icon-button", width: 90.0, height: 60.0).run(
        "press 20 20\nrelease 20 20\nassert activation migrated.icon 1"
    ) {
        IconButton(IconName.Save, onClick: probedAction("migrated.icon", {=> ()}))
            .key("migrated-icon")
            .accessibilityLabel("Save copy")
            .buttonStyle(migrationButtonStyle(
                9.0,
                Color.rgb(63, 42, 21),
                Color.rgb(133, 122, 111)
            ))
    }
    @Expect(report.contains("\"id\":\"control-semantic:migrated-icon\""))
    @Expect(report.contains("\"type\":\"IconButton\""))
    @Expect(report.contains("IconButton.activate()"))
    @Expect(!report.contains("InteractionSurface.activate()"))
    @Expect(report.contains("\"kind\":\"paint.ripple\""))
    @Expect(report.contains("\"cornerRadius\":8.000000"))
}

@Test
func migratedButtonRecipesContributeOnlyTheirPublicFocusOwners(): Unit {
    let store = StateStore()
    let _ = buildRoot({=>
        HStack {
            Button("First", {=> ()}).key("first")
            IconButton(IconName.Save, onClick: {=> ()}).key("save")
        }
    }, store)
    let ring = store.focusRing()
    @Expect(ring.size, Int64(2))
    @Expect(ring[0], "first")
    @Expect(ring[1], "save")
}

@Test
func buildingMigratedButtonRecipesDoesNotPublishAFakeStateWrite(): Unit {
    let before = currentStateGeneration()
    let _ = Button("Static", {=> ()})
    let _ = IconButton(IconName.Save, onClick: {=> ()})
    @Expect(currentStateGeneration(), before)
}

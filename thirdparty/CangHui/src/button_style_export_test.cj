package chui

@Test
func umbrellaExportsComponentThemeAndButtonStyle(): Unit {
    let quiet = ButtonStyle.quiet()
    let chrome = TextAreaChrome.None
    let style = ButtonStyle(resolve: {
        theme, role, state => ButtonAppearance(
            surface: theme.buttonSurface(role),
            foreground: theme.text,
            ink: theme.inkColor(role: role),
            focusRadius: if (state.focused) { 12.0 } else { 8.0 }
        )
    })
    let controlStyle = ComponentControlStyle(resolve: {
        theme, _, state => ComponentControlAppearance(
            surface: theme.fieldSurface(state.focused),
            foreground: theme.text,
            indicator: theme.accent,
            ink: theme.inkColor(),
            focusRadius: if (state.expanded) { 12.0 } else { 8.0 }
        )
    })
    let theme = Theme.light().withComponents(ComponentTheme(
        buttonStyle: Some(style),
        controlStyle: Some(controlStyle),
        typography: ComponentTypography(control: 16.fp),
        spacing: ComponentSpacing(controlMinHeight: 44.0),
        shape: ComponentShape(controlRadius: Some(12.0))
    ))
    @Expect(theme.components.buttonStyle.isSome())
    @Expect(theme.components.controlStyle.isSome())
    @Expect(theme.components.buttonLayout.minHeight, Float32(38.0))
    @Expect(theme.components.spacing.controlMinHeight, Float32(44.0))
    @Expect(theme.components.shape.resolvedControl(theme), Float32(12.0))
    @Expect(quiet.resolve(theme, ButtonRole.Normal, ButtonVisualState()).surface.borderWidth, Float32(0.0))
    @Expect(match (chrome) {
        case TextAreaChrome.None => true
        case TextAreaChrome.Field => false
    })
}

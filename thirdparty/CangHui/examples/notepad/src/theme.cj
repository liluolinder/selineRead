/*
 * 记事本的应用元数据、SDL 提示项、青绿主题与表面样式。
 * 集中在一个文件里，视图层只管取用，不关心具体色值。
 */
package chui_notepad

import chui.{AppMetadata, AppMetadataType, Color, SdlHint, SdlHintSetting, SurfaceStyle, Theme}

func notepadMetadata(): AppMetadata {
    var metadata = AppMetadata(
        name: Some("CangHui Notepad"),
        version: Some("0.1.0"),
        identifier: Some("dev.cui.examples.notepad")
    )
    metadata.creator = Some("CangHui Examples")
    metadata.appType = Some(AppMetadataType.Application)
    metadata
}

func notepadHints(): Array<SdlHintSetting> {
    [
        SdlHintSetting(SdlHint.AppName, "CangHui Notepad"),
        SdlHintSetting(SdlHint.AppId, "dev.cui.examples.notepad"),
        SdlHintSetting(SdlHint.WindowsCloseOnAltF4, "1")
    ]
}

func notepadTheme(): Theme {
    Theme(
        bg: Color.rgb(238, 244, 248),
        panel: Color.rgb(255, 255, 255),
        panelEdge: Color.rgb(201, 213, 222),
        text: Color.rgb(25, 34, 43),
        mutedText: Color.rgb(92, 106, 119),
        accent: Color.rgb(34, 132, 127),
        accentText: Color.rgb(255, 255, 255),
        danger: Color.rgb(196, 59, 76),
        field: Color.rgb(250, 252, 253),
        fieldActive: Color.rgb(229, 245, 243),
        panelRaised: Color.rgb(255, 255, 255),
        accentSoft: Color.rgb(214, 241, 238),
        shadow: Color.rgba(11, 31, 45, 26),
        radius: 16.0,
        controlRadius: 11.0
    )
}

func toolbarSurface(): SurfaceStyle {
    SurfaceStyle(
        Color.rgb(255, 255, 255),
        border: Color.rgb(205, 218, 226),
        radius: 16.0,
        borderWidth: 1.0,
        shadow: Color.rgba(20, 44, 56, 24),
        shadowOffsetY: 2.0
    )
}

/**
 * “新建”确认条的暖色警示表面：与常规白色面板拉开视觉差，
 * 提醒用户接下来的操作会丢弃未保存内容。
 */
func confirmBarSurface(): SurfaceStyle {
    SurfaceStyle(
        Color.rgb(255, 248, 236),
        border: Color.rgb(238, 205, 160),
        radius: 12.0,
        borderWidth: 1.0
    )
}

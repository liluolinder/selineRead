/*
 * 桌面集成层：深色主题、应用元数据与 SDL 提示。
 * 视觉与桌面壳设置集中在一处，与业务逻辑完全解耦。
 */
package chui_process_manager

import chui.{AppMetadata, AppMetadataType, Color, SdlHint, SdlHintSetting, Theme}

// 深石板底 + 薄荷绿强调：监控类工具的低刺激配色，长时间盯着也不刺眼。
func processTheme(): Theme {
    Theme(
        bg: Color.rgb(17, 24, 39),
        panel: Color.rgb(24, 32, 46),
        panelEdge: Color.rgb(54, 68, 89),
        text: Color.rgb(236, 253, 245),
        mutedText: Color.rgb(148, 163, 184),
        accent: Color.rgb(52, 211, 153),
        accentText: Color.rgb(6, 32, 24),
        danger: Color.rgb(251, 113, 133),
        field: Color.rgb(31, 41, 55),
        fieldActive: Color.rgb(36, 61, 55),
        panelRaised: Color.rgb(30, 41, 59),
        accentSoft: Color.rgb(26, 77, 66),
        shadow: Color.rgba(0, 0, 0, 82),
        radius: 16.0,
        controlRadius: 11.0
    )
}

// 元数据供操作系统展示（任务栏、关于对话框等），与窗口标题相互独立。
func processMetadata(): AppMetadata {
    var metadata = AppMetadata(
        name: Some("CangHui Process Manager"),
        version: Some("0.1.0"),
        identifier: Some("dev.cui.examples.process-manager")
    )
    metadata.creator = Some("CangHui Examples")
    metadata.appType = Some(AppMetadataType.Application)
    metadata
}

func processHints(): Array<SdlHintSetting> {
    [
        SdlHintSetting(SdlHint.AppName, "CangHui Process Manager"),
        SdlHintSetting(SdlHint.AppId, "dev.cui.examples.process-manager"),
        SdlHintSetting(SdlHint.RenderVSync, "1")
    ]
}

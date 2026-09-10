/*
 * 设计令牌样式指南的类型化数据。
 *
 * 把各令牌尺度（间距/圆角/字号/动效时长/高度）列成可迭代的数据；毫秒文案是纯函数，便于单测。
 */
package chui_styleguide

import chui.{FontSizes, Length, LengthUnit, Motion, Radii, Spacing}

// 间距尺度的一档：名称 + Length。
struct SpacingStep {
    let name: String
    let length: Length

    init(name: String, length: Length) {
        this.name = name
        this.length = length
    }
}

let SPACING_STEPS: Array<SpacingStep> = [
    SpacingStep("xs", Spacing.xs),
    SpacingStep("sm", Spacing.sm),
    SpacingStep("md", Spacing.md),
    SpacingStep("lg", Spacing.lg),
    SpacingStep("xl", Spacing.xl),
    SpacingStep("xxl", Spacing.xxl)
]

// 圆角尺度的一档：名称 + 半径（vp）。
struct RadiusStep {
    let name: String
    let radius: Float32

    init(name: String, radius: Float32) {
        this.name = name
        this.radius = radius
    }
}

let RADIUS_STEPS: Array<RadiusStep> = [
    RadiusStep("sm", Radii.sm),
    RadiusStep("md", Radii.md),
    RadiusStep("lg", Radii.lg),
    RadiusStep("xl", Radii.xl),
    RadiusStep("pill", Radii.pill)
]

// 字号尺度的一档：名称 + 字号（fp）。
struct TypeStep {
    let name: String
    let size: Float32

    init(name: String, size: Float32) {
        this.name = name
        this.size = size
    }
}

let TYPE_STEPS: Array<TypeStep> = [
    TypeStep("Caption", FontSizes.CAPTION),
    TypeStep("Body", FontSizes.BODY),
    TypeStep("Title", FontSizes.TITLE),
    TypeStep("Display", FontSizes.DISPLAY)
]

// 动效时长的一档：名称 + 毫秒。
struct MotionStep {
    let name: String
    let ms: UInt64

    init(name: String, ms: UInt64) {
        this.name = name
        this.ms = ms
    }
}

let MOTION_STEPS: Array<MotionStep> = [
    MotionStep("fast", Motion.fast),
    MotionStep("normal", Motion.normal),
    MotionStep("slow", Motion.slow)
]

// 高度（elevation）参考展示的层级。
let ELEVATION_LEVELS: Array<Int64> = [1, 2, 3, 4]

// 毫秒文案，如「220ms」。
func formatMs(ms: UInt64): String {
    "${ms}ms"
}

// 动效时长对应的示意条宽度（vp）：时长越长条越宽，便于目视对比。
func msBarWidth(ms: UInt64): Length {
    Length(Float32(Int64(ms)) * 0.45, LengthUnit.Vp)
}

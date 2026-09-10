package chui_shadows

import chui.Shadow

@Test
func clampLevelStaysInPresetDomain(): Unit {
    @Expect(clampLevel(3), 3)
    @Expect(clampLevel(0), 1)
    @Expect(clampLevel(-5), 1)
    @Expect(clampLevel(7), 6)
}

@Test
func modelCurrentFollowsStepperAndClamps(): Unit {
    let model = ShadowsModel()
    @Expect(model.current(), 3)
    model.level.value = 6
    @Expect(model.current(), 6)
    model.level.value = 99
    @Expect(model.current(), 6)
    @Expect(model.statusText().contains("e6"))
}

@Test
func keyAmbientPairIsUsableFromApplications(): Unit {
    // Shadow 字段是公开的，应用侧可直接检视双层预设的结构：宽而淡的环境层在前、窄而深的方向层在后。
    let layers = Shadow.keyAmbient(4)
    @Expect(layers.size, 2)
    @Expect(layers[0].blur > layers[1].blur)
    @Expect(Int64(layers[0].color.a) < Int64(layers[1].color.a))
}

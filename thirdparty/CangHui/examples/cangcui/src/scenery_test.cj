package chui_cangcui

// 山水几何为纯函数：同尺寸永远同画，快照因此可回归；这里钉住确定性、层次关系与
// 「江水穿山」构图成立的结构条件。

@Test
func ridgeIsDeterministicAndSane(): Unit {
    let w: Float32 = 1200.0
    let h: Float32 = 400.0
    for (layer in 0..MOUNTAINS.size) {
        var x: Float32 = 0.0
        while (x <= w) {
            let y = ridgeY(layer, x, w, h)
            // 同参重算逐位一致（确定性）。
            @Expect(ridgeY(layer, x, w, h), y)
            // 不出画顶；允许沉到画底之下（近山低谷没入江中），但有界。
            @Expect(y > 0.0)
            @Expect(y < h * 1.3)
            x += 37.0
        }
    }
}

@Test
func layersStackFarToNear(): Unit {
    // 基线与振幅由远及近单调增长——近山更高大、山脚更低，构图纵深成立。
    for (i in 1..MOUNTAINS.size) {
        @Expect(MOUNTAINS[i].baseFrac > MOUNTAINS[i - 1].baseFrac)
        @Expect(MOUNTAINS[i].ampFrac > MOUNTAINS[i - 1].ampFrac)
        // 透明度渐实、峰形渐锐：越近越不透明、越峭拔。
        @Expect(Int64(MOUNTAINS[i].base.a) >= Int64(MOUNTAINS[i - 1].base.a))
        @Expect(MOUNTAINS[i].sharpExp <= MOUNTAINS[i - 1].sharpExp)
    }
    // 主峰只设在带 peakAmp 的近层，且近景主峰落在黄金分割附近。
    @Expect(MOUNTAINS[4].peakAmp > MOUNTAINS[3].peakAmp)
    @Expect(MOUNTAINS[4].peakT > 0.30 && MOUNTAINS[4].peakT < 0.45)
}

@Test
func waterThreadsThroughNearLayers(): Unit {
    // 「江水穿过群山」的结构条件：近两重山既有高出水线的峰（成岛），
    // 又有沉到水线之下的谷（露出江面）。
    let w: Float32 = 1200.0
    let h: Float32 = 400.0
    let waterTop = Float32(WATER_FRAC) * h
    for (layer in 3..MOUNTAINS.size) {
        var above = 0
        var below = 0
        var x: Float32 = 0.0
        while (x <= w) {
            let y = ridgeY(layer, x, w, h)
            if (y < waterTop - 8.0) {
                above += 1
            }
            if (y > waterTop + 8.0) {
                below += 1
            }
            x += 11.0
        }
        @Expect(above > 8)
        @Expect(below > 8)
    }
    // 至少两处舟位落在开阔江面（两重近山都沉于水下），画上得见「野渡舟横」。
    var open = 0
    for (tb in BOAT_SPOTS) {
        let bx = Float32(tb) * 1200.0
        if (ridgeY(3, bx, 1200.0, 400.0) >= waterTop + 4.0 && ridgeY(4, bx, 1200.0, 400.0) >= waterTop + 4.0) {
            open += 1
        }
    }
    @Expect(open >= 2)
    // 松是点缀而非密林：两表合计仅少数几处立于水线之上的山脊（山谷沉水处自动让位），
    // 近景至少两簇、中景至少一簇。
    var mid = 0
    for (tp in PINE_SPOTS) {
        if (ridgeY(3, Float32(tp) * 1200.0, 1200.0, 400.0) < waterTop - 400.0 * 0.052 * 1.3) {
            mid += 1
        }
    }
    var near = 0
    for (tp in PINE_SPOTS_NEAR) {
        if (ridgeY(4, Float32(tp) * 1200.0, 1200.0, 400.0) < waterTop - 400.0 * 0.066 * 1.3) {
            near += 1
        }
    }
    @Expect(mid >= 1)
    @Expect(near >= 2)
    @Expect(mid + near <= 6)
}

@Test
func spotTablesStayInsideTheCanvas(): Unit {
    for (t in PINE_SPOTS) {
        @Expect(t > 0.0 && t < 1.0)
    }
    for (t in PINE_SPOTS_NEAR) {
        @Expect(t > 0.0 && t < 1.0)
    }
    for (t in BOAT_SPOTS) {
        @Expect(t > 0.0 && t < 1.0)
    }
    for ((tx, ty) in BIRD_SPOTS) {
        @Expect(tx > 0.0 && tx < 1.0)
        // 飞鸟在天际——远山基线之上。
        @Expect(ty < MOUNTAINS[0].baseFrac)
    }
    for ((tx, row) in RIPPLE_SPOTS) {
        @Expect(tx > 0.0 && tx < 1.0)
        @Expect(row >= 0 && row < 4)
    }
    for ((tx, row) in STREAM_SPOTS) {
        // 流水长曲横跨约 0.09 画宽，起点须留出尾部空间。
        @Expect(tx > 0.0 && tx < 0.90)
        @Expect(row >= 0 && row < 3)
    }
}

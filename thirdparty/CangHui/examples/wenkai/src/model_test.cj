package chui_wenkai

import std.collection.ArrayList

@Test
func resolveFontsDirPicksFirstExisting(): Unit {
    // 依候选顺序取第一个存在的目录。
    let hit = resolveFontsDir(["a", "b", "c"], {p => p == "b" || p == "c"})
    @Expect(hit.getOrThrow(), "b")
    // 全部缺失返回 None（示例照常运行、回退系统字体）。
    @Expect(resolveFontsDir(["a", "b"], {_ => false}).isNone())
    // 空候选安全返回 None。
    @Expect(resolveFontsDir([], {_ => true}).isNone())
}

@Test
func registerWeightsRegistersEachWeightAndMono(): Unit {
    let seen = ArrayList<String>()
    let count = registerWeights(Some("D:\\fonts"), {name, path =>
        seen.add("${name}=${path}")
    })
    // 三个比例字重 + 一个等宽变体。
    @Expect(count, 4)
    @Expect(seen.size, 4)
    // 路径由目录与文件名拼出，注册名与数据表一致。
    @Expect(seen[0], "wenkai-light=D:\\fonts\\LXGWWenKai-Light.ttf")
    @Expect(seen[3], "wenkai-mono=D:\\fonts\\LXGWWenKaiMono-Regular.ttf")
}

@Test
func registerWeightsSkipsWhenDirMissing(): Unit {
    let calls = ArrayList<String>()
    let count = registerWeights(None, {name, _ => calls.add(name)})
    @Expect(count, 0)
    @Expect(calls.isEmpty())
}

@Test
func modelFamilyFollowsSelectionAndClamps(): Unit {
    let model = WenkaiModel(4)
    // 默认 Regular。
    @Expect(model.family(), "wenkai")
    model.selected.value = 0
    @Expect(model.family(), "wenkai-light")
    model.selected.value = 2
    @Expect(model.family(), "wenkai-medium")
    // 越界钳回 Regular，不抛异常。
    model.selected.value = 99
    @Expect(model.family(), "wenkai")
}

@Test
func statusTextReflectsAvailability(): Unit {
    // 已登记：报字重数与授权说明。
    let loaded = WenkaiModel(4)
    @Expect(loaded.available())
    @Expect(loaded.statusText().contains("4 个字重"))
    // 缺失：给出回退与获取指引。
    let missing = WenkaiModel(0)
    @Expect(!missing.available())
    @Expect(missing.statusText().contains("回退"))
}

@Test
func weightLabelsMatchWeightTable(): Unit {
    let labels = weightLabels()
    @Expect(labels.size, WEIGHTS.size)
    @Expect(labels[1].contains("Regular"))
}

/*
 * 样本册的类型化数据与纯解析逻辑。
 *
 * 字体文件位于仓库的 .todo/testfonts/（机器本地素材，不入库），resolveFontsDir 以注入的存在性谓词从候选
 * 相对路径中挑出第一个可用目录，registerWeights 把各字重登记进注入的注册函数——两者都是纯函数，可单测。
 * 找不到目录时示例仍可运行，正文回退系统字体并显示获取指引。
 */
package chui_wenkai

// 一个字重：注册名、界面标签、文件名。
struct Weight {
    let family: String
    let label: String
    let file: String

    init(family: String, label: String, file: String) {
        this.family = family
        this.label = label
        this.file = file
    }
}

// 比例字重（正文样张切换用），按由细到粗排列。
let WEIGHTS: Array<Weight> = [
    Weight("wenkai-light", "Light 细", "LXGWWenKai-Light.ttf"),
    Weight("wenkai", "Regular 常规", "LXGWWenKai-Regular.ttf"),
    Weight("wenkai-medium", "Medium 中", "LXGWWenKai-Medium.ttf")
]

// 等宽变体（代码样张用）。
let MONO: Weight = Weight("wenkai-mono", "Mono 等宽", "LXGWWenKaiMono-Regular.ttf")

// 字体目录的候选相对路径（示例的工作目录是 examples/wenkai，也兼容从仓库根运行）。
let FONT_DIR_CANDIDATES: Array<String> = ["..\\..\\.todo\\testfonts", ".todo\\testfonts", "..\\.todo\\testfonts"]

// 样张文案：苏轼《定风波》上阕（公版），另配拉丁与数字行验证混排。
let SPECIMEN_TITLE: String = "霞鹜文楷"
let SPECIMEN_POEM: String = "莫听穿林打叶声，何妨吟啸且徐行。竹杖芒鞋轻胜马，谁怕？一蓑烟雨任平生。"
let SPECIMEN_LATIN: String = "The quick brown fox jumps over the lazy dog — 0123456789"
let MONO_LINES: Array<String> = [
    "let width = renderer.textWidth(text, font: \"wenkai\")",
    "Fonts.register(\"wenkai\", \"LXGWWenKai-Regular.ttf\")",
    "0O 1lI 2Z 5S 8B —— 等宽字形区分度一览"
]

// 从候选里挑第一个存在的字体目录；exists 由调用方注入（真实现用 FileSystem.exists，测试用假谓词）。
func resolveFontsDir(candidates: Array<String>, exists: (String) -> Bool): ?String {
    for (dir in candidates) {
        if (exists(dir)) {
            return Some(dir)
        }
    }
    None
}

// 把目录下的各字重（含等宽）登记进 register(name, path)，返回登记数。目录为 None 时不登记。
func registerWeights(dir: ?String, register: (String, String) -> Unit): Int64 {
    let base = match (dir) {
        case Some(value) => value
        case None => return 0
    }
    var count: Int64 = 0
    for (weight in WEIGHTS) {
        register(weight.family, "${base}\\${weight.file}")
        count += 1
    }
    register(MONO.family, "${base}\\${MONO.file}")
    count + 1
}

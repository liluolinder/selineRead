/*
 * 字体加载示例的类型化数据与纯逻辑。
 *
 * 每种字体列出跨平台的字体文件候选；解析（挑第一个存在的文件）与选中项到字体名的映射是纯函数，
 * 便于单测且与视图、文件系统无关（存在性判定以谓词注入）。
 */
package chui_fonts

// 一种要加载的字体：显示名、注册名（None 表示 CangHui 默认链，不走 fontFamily）、跨平台字体文件候选。
struct TypeFace {
    let label: String
    let family: ?String
    let candidates: Array<String>

    init(label: String, family: ?String, candidates: Array<String>) {
        this.label = label
        this.family = family
        this.candidates = candidates
    }
}

// 本示例尝试加载的字体：CangHui 默认（随包 HarmonyOS Sans）+ 一款衬线 + 一款等宽。
// 候选覆盖 Windows/macOS/Linux 常见路径，取第一个存在者；找不到或缺字则走默认回退链。
let TYPEFACES: Array<TypeFace> = [
    TypeFace("CangHui 默认", None, []),
    TypeFace(
        "衬线 Serif",
        "demo-serif",
        [
            "C:\\Windows\\Fonts\\georgia.ttf",
            "C:\\Windows\\Fonts\\times.ttf",
            "C:\\Windows\\Fonts\\constan.ttf",
            "/System/Library/Fonts/Supplemental/Georgia.ttf",
            "/System/Library/Fonts/Times.ttc",
            "/usr/share/fonts/truetype/dejavu/DejaVuSerif.ttf",
            "/usr/share/fonts/truetype/liberation/LiberationSerif-Regular.ttf"
        ]
    ),
    TypeFace(
        "等宽 Monospace",
        "demo-mono",
        [
            "C:\\Windows\\Fonts\\consola.ttf",
            "C:\\Windows\\Fonts\\cour.ttf",
            "C:\\Windows\\Fonts\\lucon.ttf",
            "/System/Library/Fonts/Menlo.ttc",
            "/System/Library/Fonts/Monaco.ttf",
            "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf",
            "/usr/share/fonts/truetype/liberation/LiberationMono-Regular.ttf"
        ]
    )
]

// 样张：拉丁字母 + 数字 + 标点。用拉丁文而非中西混排，因为示例加载的 Georgia/Consolas 等拉丁字体
// 不含 CJK 字形（会显示为缺字方块），CJK 覆盖仍由系统字体承担；此处专注对比衬线、等宽与无衬线的字形。
let SPECIMEN = "Hamburgefonstiv — the quick brown fox 0123456789"

// 候选中第一个存在的文件路径；存在性以谓词注入，便于单测。None 表示都不存在。
func firstExisting(candidates: Array<String>, exists: (String) -> Bool): ?String {
    for (path in candidates) {
        if (exists(path)) {
            return path
        }
    }
    None
}

// 选中下标对应的字体注册名（越界或默认项返回 None，即不套用 fontFamily）。
func faceName(faces: Array<TypeFace>, index: Int64): ?String {
    if (index < 0 || index >= faces.size) {
        return None
    }
    faces[index].family
}

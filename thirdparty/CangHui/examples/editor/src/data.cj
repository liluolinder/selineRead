/*
 * 编辑器示例的种子文本与纯统计函数。
 */
package chui_editor

func seedText(): String {
    let l1 = "# CangHui 菜单栏示例"
    let l2 = "用顶部菜单操作本文档：新建、追加日期、追加分隔线、清空。"
    let l3 = "菜单项带快捷键提示与分隔线；文档为空时，文件菜单里的保存会自动禁用。"
    let l4 = "let longSourceLine = \"ASCII、中文与你看到的逻辑行号始终保持一行；横向滚轮或底部滑块查看右侧内容\""
    "${l1}\n\n${l2}\n${l3}\n${l4}"
}

/** 字符数（Unicode 码点），不计换行与回车。 */
func charCount(text: String): Int64 {
    var count = 0
    for (rune in text.toRuneArray()) {
        if (rune != r'\n' && rune != r'\r') {
            count += 1
        }
    }
    count
}

/** 行数：空文本记 0，否则按换行切分计数。 */
func lineCount(text: String): Int64 {
    if (text.isEmpty()) {
        0
    } else {
        text.split("\n").size
    }
}

/** 与文档逻辑行一一对应的单独 gutter 文本；空文档仍显示第 1 行。 */
func lineNumberText(text: String): String {
    let count = max(Int64(1), lineCount(text))
    let output = StringBuilder()
    var line: Int64 = 1
    while (line <= count) {
        if (line > 1) {
            output.append("\n")
        }
        output.append(line.toString())
        line += 1
    }
    output.toString()
}

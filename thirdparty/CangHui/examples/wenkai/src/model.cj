/*
 * 样本册状态：字体是否已登记、当前选中的字重。
 *
 * registered 在启动时由 main 依据目录探测结果写定；selected 由字重切换器绑定。字体缺失时页面仍可渲染
 * （正文回退系统字体），状态条给出获取指引。
 */
package chui_wenkai

import chui.State

class WenkaiModel {
    // 已登记的字体数（0 表示目录缺失，全部回退系统字体）。
    let registered: Int64
    let selected = State<Int64>(1) // 默认 Regular

    init(registered: Int64) {
        this.registered = registered
    }

    func available(): Bool {
        registered > 0
    }

    // 当前样张所用的字体名；未登记时仍返回名字（渲染层按未注册名回退系统字体）。
    func family(): String {
        let index = selected.value
        if (index < 0 || index >= WEIGHTS.size) {
            return WEIGHTS[1].family
        }
        WEIGHTS[index].family
    }

    // 状态条文案。
    func statusText(): String {
        if (available()) {
            return "已登记 ${registered} 个字重（LXGW WenKai，SIL OFL）· 切换上方字重观察同一段文字的笔画变化"
        }
        "未找到 .todo/testfonts/ 下的霞鹜文楷字体文件，正文以系统字体回退渲染；获取方式见 README"
    }
}

// 字重标签数组（切换器用）。
func weightLabels(): Array<String> {
    Array<String>(WEIGHTS.size) {
        i => WEIGHTS[i].label
    }
}

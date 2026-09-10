/*
 * 折叠问答示例的类型化数据：每条问答是不可变数据。
 */
package chui_disclosure

// 一条问答：问题与答案。
struct FaqItem {
    let question: String
    let answer: String

    init(question: String, answer: String) {
        this.question = question
        this.answer = answer
    }
}

let FAQ: Array<FaqItem> = [
    FaqItem(
        "CangHui 是什么？",
        "CangHui 是基于仓颉与 SDL3 的声明式桌面 GUI 框架：尾随闭包 + 链式修饰符描述界面，响应式状态驱动更新，自渲染管线负责布局与绘制。"
    ),
    FaqItem(
        "如何加载自定义字体？",
        "用 Fonts.register(名称, 字体文件路径) 登记一个本地字体文件，再由 Label.fontFamily(名称) 按名套用；名称未注册或文件打不开时自动回退系统字体。"
    ),
    FaqItem(
        "动画是怎么工作的？",
        "渲染循环本身即动画时钟：Spring 物理弹簧或 Animator 时长补间在控件的 draw 里逐帧推进，未静止时主动请求下一帧，静止后零开销。"
    ),
    FaqItem(
        "这个展开动画是怎么实现的？",
        "本页每条答案都由 Reveal 容器包裹：切换时它用 Animator 缓动自身高度在 0 与内容高度之间，内容裁剪着从顶部滑入或滑出，父布局随之平滑回流。"
    ),
    FaqItem(
        "样式属性支持哪些？",
        "圆角填充 background(color, radius)、圆角描边 border、可配 offset/blur/spread 的软阴影 shadow（含 Material 式 elevation 预设），链式叠加即成卡片。"
    ),
    FaqItem(
        "如何编写自定义控件？",
        "实现 Widget 的 measure/layout/draw/handle 四个方法即可；focusableControlIdentity 让控件进入 Tab 焦点序，claimHoverIfInside 认领悬停光标，drawFocusRing 画标准焦点环。本页的问题标题行就是一个示例内定义的自定义控件。"
    )
]

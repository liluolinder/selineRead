# layout_transition：键控布局连续性

这个示例演示同一批带稳定 key 的卡片在重排和 `3 ↔ 2` 列响应式重排时，如何从旧可见矩形连续过渡到
父布局的新矩形。业务层仍然只声明普通 `Grid`；`KeyedLayoutTransition` 是包住单个可移动子树的通用能力。

```cangjie
Grid(model.columns.value) {
    for (item in model.items()) {
        KeyedLayoutTransition(item, clip: LayoutTransitionClip.AnimatedBounds) {
            card(item)
        }
    }
}
```

关键语义：

- `key` 必须表示同一个逻辑对象，不能用当前数组下标；
- 父布局、焦点与命中测试立即采用目标矩形，只有绘制矩形在过渡；
- 动画中再次重排会从当前可见矩形重新定向，不跳回最初位置；
- 首次出现和卸载后重新挂载默认静止；删除项不隐含退出动画；
- `AnimationSpec.automatic` 会服从主题的减少动态效果设置。

运行与验证：

```bash
cd examples/layout_transition
cjpm run

cuic pview . layout-transition.grid --columns 120 --rows 42
cuic pview . layout-transition.grid \
  --events $'focus layout-reorder\nkey Enter\nadvance 90\ndraw' \
  --columns 120 --rows 42
cuic prnt . --output layout-transition.bmp
```

CUIC 的 ASCII/JSON 探针会报告稳定卡片 key、最终结构和控件动作；像素证据再用于观察过渡中的视觉连续性。

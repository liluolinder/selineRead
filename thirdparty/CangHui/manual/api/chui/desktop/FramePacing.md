[chui](../../index.md) › [chui.desktop](index.md) › FramePacing

# FramePacing

`chui.desktop` 包中的 public enum

控制桌面循环如何等待下一次实际渲染。它不强制每轮都渲染；脏帧机制仍会跳过没有输入、状态变化或续帧请求的空闲帧。

## 声明

```cangjie
public enum FramePacing {
    | Device
    | Fixed(UInt32)
    | Unbounded
}
```

## 成员

| 成员 | 说明 |
|---|---|
| `Device` | 使用渲染器 VSync 跟随显示设备；`present()` 后不再叠加固定等待。 |
| `Fixed(fps)` | 关闭 VSync，并从每帧已耗时间中扣除后按剩余预算等待；`fps` 必须为 1..1000。 |
| `Unbounded` | 实际渲染帧不加等待；没有帧请求的空闲轮询仍短暂让出执行权。 |

## 示例

```cangjie
let app = DesktopApp(
    WindowSpec("Profiler", 960, 640),
    framePacing: Some(FramePacing.Fixed(120))
)
```

未显式给出策略时，普通 VSync 窗口采用 `Device`；kMode 采用 `Unbounded`。显式策略优先于
`WindowSpec.vsync` 和兼容参数 `frameDelay`。

## 另请参阅

- [DesktopApp](DesktopApp.md) — 帧循环所有者与构造参数。

[chui](../../index.md) › [chui.desktop](index.md) › DesktopCaptureRequest

# DesktopCaptureRequest

`chui.desktop` 包中的 public class。

框架拥有的一次稳定渲染采集请求。请求以 BMP 为当前公共输出格式；`cuic prnt` 会在构建后直接启动应用可执行文件，并通过宿主环境注入同一请求。这样应用参数仍由操作系统直接交给应用，不依赖 `cjpm run` 的参数转发实现。

## 声明

```cangjie
public class DesktopCaptureRequest
```

## 构造函数

```cangjie
public init(path: String, settleFrames!: UInt64 = UInt64(48))
```

- `path`: 渲染器写入的 BMP 路径，不能为空。
- `settleFrames!`: 完成首帧后等待的渲染帧数，`0` 会收窄为 `1`，默认 `48`。

## 属性

| 属性 | 类型 | 说明 |
|---|---|---|
| `path` | `String` | BMP 输出路径。 |
| `settleFrames` | `UInt64` | 采集前的稳定帧预算。 |

## 函数

```cangjie
public static func fromEnvironment(): ?DesktopCaptureRequest
```

读取宿主注入的请求。没有 `CANGHUI_CAPTURE_PATH` 时返回 `None`；非法或缺失的帧预算使用默认值 `48`。

## 宿主协议

| 环境变量 | 说明 |
|---|---|
| `CANGHUI_CAPTURE_PATH` | 必填，BMP 输出路径。 |
| `CANGHUI_CAPTURE_FRAMES` | 可选，正整数稳定帧预算。 |

应用不需要手工读取这些变量。`DesktopApp` 创建时会自动消费请求，渲染完成后写出 BMP 并按正常关闭路径退出。已有应用传入 `--snapshot` 仍可运行，但该形式只保留作兼容迁移。

自定义宿主也可显式传入请求：

```cangjie
let app = DesktopApp(
    WindowSpec("capture", 640, 480),
    capture: Some(DesktopCaptureRequest("artifacts/capture.bmp", settleFrames: UInt64(24)))
)
```

显式请求优先于环境注入与旧参数兼容输入。

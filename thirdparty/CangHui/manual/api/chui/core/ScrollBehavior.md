[chui](../../index.md) › [chui.core](index.md) › ScrollBehavior

# ScrollBehavior

`chui.core` 包中的 public enum

定义滚轮输入是立即改变偏移，还是沿保留式动画逐帧到达目标。

## 声明

```cangjie
public enum ScrollBehavior {
    | Immediate
    | Smooth
}
```

## 成员

| 成员 | 说明 |
|---|---|
| `Immediate` | 同一事件内把偏移直接写到钳位后的目标。 |
| `Smooth` | 保留目标偏移，连续滚轮输入继续累计，并按 `ScrollOptions.animation` 自动请求后续帧。 |

## 另请参阅

- [ScrollOptions](ScrollOptions.md) — 行为、步长与动画配置。
- [ScrollView](ScrollView.md) — 消费该策略的基础滚动视口。

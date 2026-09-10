[chui](../../index.md) › [chui.media](index.md) › 函数

# 函数 — chui.media

`chui.media` 的包级函数：图像纹理缓存的刷新入口。缓存按文件路径键控、进程级共享、只在 UI 线程使用；加载失败也会被缓存（不每帧重试磁盘）。

### invalidateImage

丢弃 `path` 的缓存纹理（并关闭它）；下一次绘制从磁盘重载。覆盖写过图像文件后调用——包括先前加载失败的文件。

```cangjie
public func invalidateImage(path: String): Unit
```

**参数**

- `path`: `String` — 图像文件路径（缓存键）。

### clearImageCache

清空图像缓存并关闭每个缓存纹理；图像在下一次绘制时重载。

```cangjie
public func clearImageCache(): Unit
```

## 另请参阅

- [`ImageView`](ImageView.md) — 缓存的消费者。

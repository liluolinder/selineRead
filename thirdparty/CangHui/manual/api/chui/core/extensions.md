[chui](../../index.md) › [chui.core](index.md) › 扩展成员

# 扩展成员 — chui.core

`chui.core` 对外部类型的扩展：`Int64` 与 `Float64` 均实现 [`LengthUnits`](LengthUnits.md)，让整数与浮点字面量获得 `.px`/`.vp`/`.fp` 长度后缀。写 `48.vp` 或 `1.5.vp` 即得到对应单位的 [`Length`](Length.md)；后缀随 `LengthUnits` 一起导入（`chui` 根包已再导出）。

## 示例

```cangjie verify
package docexample

import chui.*

main(): Unit {
    let toolbarHeight = 48.vp // Int64 后缀
    let titleSize = 16.5.fp // Float64 后缀
    println("${Int64(toolbarHeight.value)}${toolbarHeight.unit.symbol()} 与 ${titleSize.unit.symbol()} 字号")
    // 输出: 48vp 与 fp 字号
}
```

## Int64 的 LengthUnits 实现

整数字面量与 `Int64` 值的长度后缀，数值经 `Float32` 转换后携带对应单位。

```cangjie
extend Int64 <: LengthUnits
```

### px

该整数作为物理设备像素的长度。

```cangjie
public prop px: Length
```

**返回值** [`Length`](Length.md) — `Length(Float32(this), LengthUnit.Px)`，只读。

### vp

该整数作为虚拟（密度无关）像素的长度，尺寸 API 的常规写法。

```cangjie
public prop vp: Length
```

**返回值** [`Length`](Length.md) — `Length(Float32(this), LengthUnit.Vp)`，只读。

### fp

该整数作为字体像素的长度，随用户字体缩放。

```cangjie
public prop fp: Length
```

**返回值** [`Length`](Length.md) — `Length(Float32(this), LengthUnit.Fp)`，只读。

## Float64 的 LengthUnits 实现

浮点字面量与 `Float64` 值的长度后缀，支持 `1.5.vp` 这样的非整数尺寸；数值经 `Float32` 转换后携带对应单位。

```cangjie
extend Float64 <: LengthUnits
```

### px

该浮点数作为物理设备像素的长度。

```cangjie
public prop px: Length
```

**返回值** [`Length`](Length.md) — `Length(Float32(this), LengthUnit.Px)`，只读。

### vp

该浮点数作为虚拟（密度无关）像素的长度。

```cangjie
public prop vp: Length
```

**返回值** [`Length`](Length.md) — `Length(Float32(this), LengthUnit.Vp)`，只读。

### fp

该浮点数作为字体像素的长度，随用户字体缩放。

```cangjie
public prop fp: Length
```

**返回值** [`Length`](Length.md) — `Length(Float32(this), LengthUnit.Fp)`，只读。

## 另请参阅

- [LengthUnits](LengthUnits.md) — 两个扩展共同实现的接口。
- [Length](Length.md) — 后缀产出的类型。

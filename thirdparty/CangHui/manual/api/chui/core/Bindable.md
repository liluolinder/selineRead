[chui](../../index.md) › [chui.core](index.md) › Bindable

# Bindable

`chui.core` 包中的 public interface

可读、可写并能通知变化的值。交互控件通过它接收状态，因此既可以直接传 [`State`](State.md)，也可以传指向大对象中某个字段的 [`Binding`](Binding.md)。`project` 会从整个模型中取出一个字段，并把对该字段的修改写回原模型；文本框（[`TextField`](../text/TextField.md)）等编辑控件通常用它绑定模型字段。

## 声明

```cangjie
public interface Bindable<T> <: Observable<T>
```

## 继承

- 父接口：[`Observable`](Observable.md)`<T>`。
- 已文档化实现：[`State`](State.md)、[`Binding`](Binding.md)。

## 示例

```cangjie verify
package docexample

import chui.*

struct Profile {
    let name: String
    let subscribed: Bool
    init(name: String, subscribed: Bool) {
        this.name = name
        this.subscribed = subscribed
    }
}

// 控件式写法：按 Bindable 抽象接收，State 与 Binding 都能传入
func toggle(flag: Bindable<Bool>): Unit {
    flag.value = !flag.value
}

main(): Unit {
    let form = State<Profile>(Profile("林", true))
    let subscribed = form.project(get: {p => p.subscribed}, set: {p, v => Profile(p.name, v)})
    toggle(subscribed) // 修改字段绑定时会重建整个 Profile
    println("${form.value.name} ${form.value.subscribed}")
    // 输出: 林 false
}
```

## 成员概览

**属性**

| 成员 | 说明 |
|---|---|
| [`value`](#value) | 读取或替换当前值。 |

**方法**

| 成员 | 说明 |
|---|---|
| [`get()`](#get) | 读取当前值。 |
| [`project<U>(get!, set!)`](#project) | 返回指向本值中某个成分的双向绑定。 |

## 属性

### value

读取或替换当前值。可读写；这是 `Bindable` 相对 [`Observable`](Observable.md) 追加的能力。

```cangjie
mut prop value: T
```

## 方法

### get

读取当前值。接口默认实现，返回 `value`。

```cangjie
func get(): T
```

**返回值** `T` — 当前值。

### project

返回指向本值中某个成分的双向绑定。`get` 抽取成分，`set` 围绕改动后的成分重建整个值——读写始终落在同一个数据源上。接口默认实现。

```cangjie
func project<U>(get!: (T) -> U, set!: (T, U) -> T): Binding<U>
```

**参数**

- `get!`: `(T) -> U` — 从整体值中抽取成分。
- `set!`: `(T, U) -> T` — 接收 `(整体旧值, 成分新值)`，返回重建后的整体值。

**返回值** [`Binding`](Binding.md)`<U>` — 指向该成分的双向绑定。

```cangjie
let form = State<Profile>(Profile("林", true))
let name = form.project(get: {p => p.name}, set: {p, v => Profile(v, p.subscribed)})
TextField(name)   // 编辑控件直接读写选中的成分
```

## 另请参阅

- [Observable](Observable.md) — 只读父接口。
- [Binding](Binding.md) — `project` 返回的字段绑定类型。

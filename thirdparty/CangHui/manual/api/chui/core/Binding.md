[chui](../../index.md) › [chui.core](index.md) › Binding

# Binding

`chui.core` 包中的 public class

指向另一个可绑定值中某个字段的双向绑定，用 [`Bindable.project`](Bindable.md#project) 创建。读取时从原值取出该字段；写入时用新字段值重建原值并写回，因此数据源始终只有一个。没有公开构造函数。

## 声明

```cangjie
public class Binding<T> <: Bindable<T>
```

## 继承

- 实现 [`Bindable`](Bindable.md)`<T>`，并经由它实现 [`Observable`](Observable.md)`<T>`——因此字段绑定本身还能继续 `project` 或 `map`。

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

main(): Unit {
    let form = State<Profile>(Profile("林", true))
    let name: Binding<String> = form.project(get: {p => p.name}, set: {p, v => Profile(v, p.subscribed)})
    name.value = "苏" // 写入重建整个 Profile 并赋回源
    println("${form.value.name} ${form.value.subscribed}")
    // 输出: 苏 true
}
```

## 成员概览

**属性**

| 成员 | 说明 |
|---|---|
| [`value`](#value) | 读取或替换绑定到的字段。 |
| [`revision`](#revision) | 源的修订号。 |

**方法**

| 成员 | 说明 |
|---|---|
| [`observe(callback: (T, T) -> Unit)`](#observe) | 观察后续变化并返回可取消的订阅。 |

## 属性

### value

读取或替换绑定到的字段。读取时通过 `get` 从原值取出字段；写入时通过 `set` 重建整个原值并写回，因此观察原值的代码也会收到通知。

```cangjie
public mut prop value: T
```

### revision

源的修订号。只读；源的任何赋值（包括其它成分的变化）都会推进它。

```cangjie
public prop revision: UInt64
```

**返回值** `UInt64` — 与源同步的修订号。

## 方法

### observe

观察后续变化并返回可取消的订阅。回调收到字段的 `(旧值, 新值)`；原值每次被赋值都会触发回调，即使这个字段没有变化。只关心字段真正变化时，请在回调中比较两个值。

```cangjie
public func observe(callback: (T, T) -> Unit): StateObservation<T>
```

**参数**

- `callback`: `(T, T) -> Unit` — 原始值变化后执行，参数为字段更新前后的值。

**返回值** [`StateObservation`](StateObservation.md)`<T>` — 调用其 `close()` 停止后续回调。

## 另请参阅

- [Bindable.project](Bindable.md#project) — 创建字段绑定的入口。
- [State](State.md) — 最常见的原始状态。

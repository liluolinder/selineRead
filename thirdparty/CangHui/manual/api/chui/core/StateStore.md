[chui](../../index.md) › [chui.core](index.md) › StateStore

# StateStore

`chui.core` 包中的 public class

跨声明式重建保留显式键控局部状态的容器：一次完整构建未访问的条目会被移除，与视图卸载语义一致。应用代码通常不直接持有它，而是在 [`DesktopApp`](../desktop/DesktopApp.md) 构建中经 [`rememberState`](functions.md#rememberstate) 使用。

## 声明

```cangjie
public class StateStore
```

## 说明

键在当前 [`Keyed`](Keyed.md) 作用域内解析，因此重复的组件可以使用相同的内部状态名而互不串扰。同一构建内重复使用同一键、或键对应的值类型改变，都会立即抛出异常而不是悄悄返回错误的状态。构建期的作用域与访问簿记由桌面应用对象在每帧构建前后维护。

## 示例

```cangjie verify
package docexample

import chui.*

main(): Unit {
    let store = StateStore()
    let draft = store.remember<String>("draft") {"晨会纪要"}
    let dirty = store.remember<Bool>("dirty") {false}
    draft.value = "晨会纪要 v2"
    dirty.value = true
    println("${draft.value} ${dirty.value}")
    store.clear() // 移除全部保留值
    // 输出: 晨会纪要 v2 true
}
```

## 成员概览

**构造函数**

| 成员 | 说明 |
|---|---|
| [`init()`](#init) | 创建一个空的状态存储容器。 |

**方法**

| 成员 | 说明 |
|---|---|
| [`remember<T>(key: String, initial: () -> T)`](#remember) | 返回当前作用域下键 `key` 对应的状态，首次使用时以 `initial` 创建。 |
| [`clear()`](#clear) | 移除全部保留的状态值。 |

## 构造函数

### init

**由编译器生成：** 仓颉会为所有实例字段均有初值且未声明构造函数的类提供该无参构造函数。

创建一个空的状态存储容器。新容器没有已保留的状态或活动作用域。

```cangjie
public init()
```

## 方法

### remember

返回当前作用域下键 `key` 对应的状态，首次使用时以 `initial` 创建。后续构建以同一键调用会取回同一个 [`State`](State.md) 实例，`initial` 不再执行。

```cangjie
public func remember<T>(key: String, initial: () -> T): State<T>
```

**参数**

- `key`: `String` — 状态标识键，不得为空；实际存储键还带上当前 `Keyed` 作用域前缀。
- `initial`: `() -> T` — 首次使用时的初值工厂。

**返回值** [`State`](State.md)`<T>` — 保留的状态实例。

**异常**

- `IllegalArgumentException` — 键为空。
- `IllegalStateException` — 同一作用域同一构建内键重复，或键对应的值类型改变。

### clear

移除全部保留的状态值。下一次 `remember` 将重新以 `initial` 创建。

```cangjie
public func clear(): Unit
```

## 另请参阅

- [rememberState](functions.md#rememberstate) — 活动构建中访问本容器的包级入口。
- [Keyed](Keyed.md) — 为键提供稳定作用域的组件。

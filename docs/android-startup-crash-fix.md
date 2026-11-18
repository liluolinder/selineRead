# Android 冷启动崩溃修复记录（2026-11-16）

## 结论

SelineRead Android 端冷启动崩溃由**两个叠加问题**造成：

1. **旧工具链归档残留**：`build/` 中 `zlibraryAPI4CJ`、`linderHttp` 的 `.a` 是用 Cangjie `1.3.0-alpha` 编译的，而 keels 当前调用 `cangjie-android` 的 `1.2.0` 工具链；增量构建复用了旧归档，运行时 `dlopen` 找不到 1.3.0 才有的符号。
2. **工作线程调用 JNI 触发 ART abort**：清掉旧归档后，`spawn` 工作线程在站点重定向时写 SharedPreferences，ART 在 `AttachCurrentThread` 中校验仓颉线程栈失败，进程 SIGABRT。

修复方式：全量清理 Android 构建产物；把 SharedPreferences 的所有 JNI 访问集中到 UI 线程，工作线程只操作内存缓存。

- 修复提交：`93f72d4 fix(android): keep SharedPreferences JNI on UI thread`
- 验证截图：`docs/screenshots/android_startup_fixed.png`（该目录未入库，仅本地留档）

## 环境

| 项 | 值 |
| --- | --- |
| 工程 | `SelineRead`（CJMP / Keels `0.8.0`） |
| 应用包名 | `seline.book.read` |
| 构建命令 | `cd SelineRead && keels build apk --debug` |
| Android Cangjie 工具链 | `cangjie-android` `1.2.0`（`cjmp-tools/third_party/cangjie-android`） |
| 主机 Cangjie | `1.3.0-alpha.20261114001016`（`C:\Program\SDK\Cangjie`） |
| 设备 | Redmi `alioth`，Android 13（`TKQ1.220829.002`），arm64 |

> 构建时 `build.bat` 会 `call cangjie-android\envsetup.bat`，把 `CANGJIE_HOME`/`PATH` 指到 1.2.0；主机 PATH 上的 1.3.0 只用于其它仓颉任务。

## 问题一：`cannot locate symbol`（dlopen 失败）

### 现象

安装后点击图标立即退出，logcat：

```
java.lang.UnsatisfiedLinkError: dlopen failed: cannot locate symbol
"_CNat8ToString8toStringHWlEv" referenced by
".../lib/arm64/libohos_app_cangjie_entry.model.so"
```

### 定位

- `llvm-nm -D --undefined-only`：`model.so` / `viewmodel.so` 引用该符号，但 APK 内所有 `.so` 都没有定义它。
- `llvm-strings` 检查 `build/aarch64-linux-android26/debug/` 下的依赖归档：
  - `zlibraryAPI4CJ/*.a`、`linderHttp/*.a` → `1.3.0-alpha.20261114001016`
  - 应用自身 `.cjo` → `1.2.0`
- `findstr` 确认该符号只存在于主机 1.3.0 的 `libcangjie-std-core.a`，Android 1.2.0 运行时库没有。

结论：增量构建没有检测到工具链版本变化，直接复用了 1.3.0-alpha 编译的依赖归档。

### 处理

```bat
cd SelineRead
keels clean --platform android --deep
keels build apk --debug
```

清理后重新编译，依赖归档变为 `1.2.0`，`model.so` / `viewmodel.so` 不再引用该符号。

## 问题二：冷启动 SIGABRT（JNI 工作线程 attach）

### 现象

修复问题一后，App 能渲染首帧，但约 1 秒后进程被 `signal 6 (SIGABRT)` 杀死。

- `adb shell dumpsys activity exit-info seline.book.read`：`reason=2 (SIGNALED) status=11`
- `adb logcat -b crash` 能抓到 tombstone（本次是在 `-b main,crash` 抓流时出现）：

```
signal 6 (SIGABRT)
Abort message: 'Check failed: FindStackTop() >
  reinterpret_cast<void*>(tlsPtr_.stack_end)'

#04 art::Thread::InitStackHwm()
#06 art::Thread::Attach()
#07 art::Runtime::AttachCurrentThread()
#09 ...::AttachCurrentThreadAsDaemon()
#10 libcangjie-runtime.so (CJ_MCC_C2NStub)
#11 libjava.internal.so (Java_CFFI_get_env)
#12 libjava.lang.so (JString.<init>)
#13 libohos_app_cangjie_entry.model.so (PreferencesUtil.putValue)
#14 libohos_app_cangjie_entry.model.so (SelineSettings.setBaseUrl)
#15 libohos_app_cangjie_entry.viewmodel.so (ZlibService.ensureSite)
#17 libcangjie-std-core.so (Future.execute)
#20 libcangjie-runtime.so (CJ_CJThreadEntry)
```

### 触发链路

1. `SelineViewModel.start()` → `home.loadRecommendations()` 在 `spawn` 线程请求推荐。
2. `ZlibService.ensureSite()` 探测默认站 `https://zh.eva101.ru`，得到 301/302 指向 `https://zh.black101.ru/`。
3. 在同一工作线程里调用 `SelineSettings.setBaseUrl(target)` → `PreferencesUtil.putValue` → `JString.<init>` → `Java_CFFI_get_env` → `AttachCurrentThreadAsDaemon`。
4. ART 的 `Thread::InitStackHwm` 按自身假设校验仓颉线程栈，检查失败后 abort。

因此这是**确定性崩溃**：只要设置过默认域名且首次启动需要重定向，就必崩。历史版本里若已持久化过 `black101`（不再重定向），则会掩盖该问题。

### 根因

Cangjie `spawn` 线程不满足 ART 的线程栈假设，**任何**从 `spawn` 工作线程发起的 Java 互操作（JNI）都会 abort，而不仅是 SharedPreferences。

### 修复

文件：`lib/android/model/preferences_android.cj`

- `putValue` / `clear` / `deleteValue`：
  - 只更新内存缓存，并把操作（`Put` / `Remove` / `Clear`）加入队列；
  - 通过 `launch { flushPending() }` 把真正写 SharedPreferences 的 JNI 调用投递到 UI 线程；
  - 多个线程并发写时用 `Mutex` 保护缓存与队列。
- `getValue`：
  - 优先读内存缓存；
  - 启动时 UI 线程已读取过全部设置键，工作线程的后续读取都会命中缓存。
- `hasValue`：先查缓存，未命中再走 Java（调用点均在 UI 线程）。

关键约束（新增代码必须遵守）：**`spawn` 线程内不得直接调用 Java 互操作；需要 JNI 时通过 `launch` 切到 UI 线程。**

## 验证

| 检查项 | 结果 |
| --- | --- |
| `keels build apk --debug` | 成功 |
| 安装、冷启动 | 首页正常渲染，无 FATAL / tombstone |
| 推荐数据 | 正常加载（`docs/screenshots/android_startup_fixed.png`） |
| 站点持久化 | `shared_prefs/seline_prefs.xml` 中 `seline.base_url=https://zh.black101.ru/` |
| 二次冷启动 | `force-stop` 后重启仍正常，不重复重定向 |
| 进程存活 | 启动后持续运行，无异常退出 |

## 排查命令备忘

```bat
:: 设备与包
adb shell pidof seline.book.read
adb shell dumpsys activity exit-info seline.book.read

:: 实时抓主/崩溃缓冲
adb logcat -b main,crash -v threadtime > capture.log

:: 查看持久化设置
adb shell run-as seline.book.read cat shared_prefs/seline_prefs.xml

:: 检查未定义符号 / 归档编译器版本
llvm-nm -D --undefined-only app\libs\arm64-v8a\libohos_app_cangjie_entry.model.so
llvm-strings build\aarch64-linux-android26\debug\zlibraryAPI4CJ\libzlibraryAPI4CJ.core.a ^
  | findstr "1.2.0 1.3.0-alpha"
```

## 防回归清单

- 再次出现 `cannot locate symbol ...`：先 `keels clean --platform android --deep`，再全量构建（不要只靠增量构建）。
- 新增后台任务（`spawn`）：只做纯仓颉/网络/文件操作；任何 `PrefsBridge`、`WindowBridge`、`toast`、`Activity` 等 Java 互操作都必须经 `launch` 回到 UI 线程。
- 排查原生崩溃时优先抓 tombstone：`Abort message` + `backtrace` 比 Java 异常栈更直接。

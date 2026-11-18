# SelineRead

`C:\Project\Cangjie\zlibraryAPI4CJ` 的 Android / HarmonyOS 客户端，使用 **CJMP (Keels 0.8.0)** 与仓颉实现。

- 包名：`seline.book.read`
- 产物：
  - Android：`SelineRead/android/app/build/outputs/apk/debug/app-debug.apk`（约 37.5 MB）
  - HarmonyOS：`SelineRead/hos/entry/build/default/outputs/default/entry-default-unsigned.hap`（约 32.0 MB）
- 运行验证：Android 13（Redmi M2012K11AC）已安装并启动，`keels test` 3/3 通过（报告与截图见下）。

---

## 1. 功能

- **5 个 Tab**：首页 / 书单 / 收藏 / 下载 / 设置。
- **首页推荐**：默认调用 `/eapi/book/most-popular` 展示热门书籍；加载失败显示错误并可切换站点。
- **悬浮搜索栏**：搜索栏覆盖在首页内容上方；输入关键词后进入搜索结果页，**清空搜索框或按返回手势会回到推荐页**。
- **书单**：公开书单列表，点开可加载书单内的书。
- **收藏 / 下载**：登录后同步收藏、分页；下载到应用私有目录并记录历史。
- **设置**：Z-Library 登录/退出、自定义站点与种子站、恢复默认、账号状态。
- **全屏 UI**：Android edge-to-edge + WindowInsets；HarmonyOS `setWindowLayoutFullScreen` + `getWindowAvoidArea`。
- **宽窄屏**：窄屏自定义悬浮底部 Tab；宽屏（>= 700vp）左侧侧边栏。

---

## 2. MVVM 目录结构

```text
SelineRead/lib/
├── common/
│   ├── main.cj                  # View（@Entry @Component，唯一组件）
│   ├── bindings.cj              # App 层：把平台实现注入 Model
│   ├── prefs.cj / window.cj / tls.cj  # 平台能力 common 声明
│   ├── ability_mainability_entry.cj
│   ├── model/                   # Model
│   │   ├── service.cj           # ZlibService：网络、登录、搜索、下载
│   │   ├── settings.cj          # SelineSettings：站点/账号/下载记录
│   │   ├── prefs.cj             # KeyValueStore / SelinePrefs（合并自 SelineKit）
│   │   └── session.cj           # SelineSession 门面（合并自 SelineKit）
│   └── viewmodel/               # ViewModel
│       └── viewmodel.cj         # @Observed SelineViewModel：状态 + 用例 + toast/错误文案
├── android/                     # Android specific：prefs/window/tls 实现
├── hos/                         # HarmonyOS specific
└── ios/                         # iOS 兜底
```

依赖方向：`View -> ViewModel -> Model -> PrefsBackend/CA Provider`，平台实现由 `bindings.cj` 注入，避免包循环。

> **为什么 View 仍在 `common` 根目录**：CJMP 的页面路由只解析根包里的 `@Entry`。把 `EntryView` 放进 `view/` 子包后，运行时出现
> `Run CJ Page fail: EntryView`（已验证）；同时 CJMP 的 platform source set 要求所有平台实现与根包同名。
> 因此 View 保持根包，Model/ViewModel 使用独立子包。

---

## 3. OpenSSL / TLS（Android）

`zlibraryAPI4CJ` 的 `stdx.net.tls` 需要 OpenSSL 3。Android 系统只有 BoringSSL，因此本项目：

- 在 `android/app/src/main/jniLibs/arm64-v8a/` 内置 `libcrypto.so`、`libssl.so`；
- 这两个库来自 AArch64 OpenSSL 3.6.5 构建，引用 `__errno_location` 等 musl/glibc 符号；
  通过 `libx.so`（`errno_shim.c` 编译）提供兼容符号，并把 `libcrypto.so` / `libssl.so` 的 `DT_NEEDED libc.so`
  改为 `libx.so`，让 shim 作为依赖先加载；
- `OpenSslPreload.java` + `libopenssl_preload.so` 在 `onCreate` 里 `dlopen(..., RTLD_GLOBAL)` 预加载；
- CA：`tls_android.cj` 读取 `/system/etc/security/cacerts` 拼成 PEM，交给 LinderHttp
  `TlsOptions.customCa(...)`（`platformCaPem`）。

`jniLibs.srcDirs = ['libs', 'src/main/jniLibs']` 已加入 `android/app/build.gradle`。

TLS 已验证握手成功；当前 `https://zh.eva101.ru` 返回 503（服务端风控/域名问题），
首页会显示“站点返回异常响应，请更换域名重试”，可在设置页换站点。

---

## 4. 构建与测试

```bash
cd C:\Project\CJMP\SelineRead

keels build apk --debug
keels build hap

# Android UI 测试（需要设备）
keels test -d <android-device> --capture-only --result-dir docs/test-run
```

已验证：

- `keels build apk --debug` 成功
- `keels build hap` 成功（未签名）
- `keels test -d 2e390e17 --capture-only` → **3 passed / 0 failed**
  - `testSearchFlow`：输入 Rust、点击搜索、截图
  - `testBackReturnsToRecommendations`：搜索后按返回，清空搜索并回到推荐页
  - `testWideLayout`：旋转设备并截图（当前 MIUI 下旋转截图仍为竖屏，布局代码未在真机宽屏截图验证）

测试证据：

- [UI 测试报告](docs/ui-test-report.json)
- [首页](docs/screenshots/home.png)
- [搜索结果态](docs/screenshots/search_mode.png)
- [返回推荐页](docs/screenshots/back_home.png)

---

## 5. 依赖与上游修正

- `lib/cjpm.toml` 依赖：`zlibraryAPI4CJ`、`linderHttp`
- `zlibraryAPI4CJ` / `LinderHttp` 的 Android target 已从
  `${ANDROID_CJ_FRONTEND}/ohos`、`${ANDROID_CJ_FRONTEND}/macro/ohos`
  改为 `${ANDROID_CJ_FRONTEND}`、`${ANDROID_CJ_MACRO}`（保留 `.bak`）
- `build.bat`：外部 `CANGJIE_STDX_PATH` 优先，`ANDROID_CANGJIE_STDX_PATH` 固定使用 CJMP 自带 Android stdx
- 原先独立的 `SelineKit` library 已合并进 `model/prefs.cj` 与 `model/session.cj`，工程已删除

---

## 6. 已知限制

- 当前默认站点返回 503，需在设置页更换可用域名。
- `testWideLayout` 的旋转在当前 MIUI 设备上未生效，宽屏布局未获得真机宽屏截图。
- HAP 未签名；安装请用 `keels run --autosign` 或 DevEco 签名。
- iOS 未在 Windows 构建。

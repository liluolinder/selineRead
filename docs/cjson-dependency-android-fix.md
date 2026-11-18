# CJson 依赖在 Android 构建中的路径报错修复

## 现象

`lib/cjpm.toml` 增加 `CJson = { git = "https://gitcode.com/LiquidStudio/CJson.git" }` 后，`keels build apk` 失败：

```
Error: can not find path 'C:\Program\SDK\CJMP\cjmp-ui\android\dynamic\ohos/ohos'
       which is listed in 'target.aarch64-linux-android26.bin-dependencies' field
       at C:\Users\<user>\.cjpm\git\CJson\<commit>\cjpm.toml
Error: can not find path 'C:\Program\SDK\CJMP\cjmp-ui\android\dynamic\ohos/macro/ohos'
       ...（同上）
Error: cjpm build failed with errorlevel 1
```

## 原因

CJson 仓库的 `cjpm.toml` 按**旧版/库工程模板**的约定书写：

```toml
[target.aarch64-linux-android26.bin-dependencies]
path-option = [ "${ANDROID_CJ_FRONTEND}/ohos", "${ANDROID_CJ_FRONTEND}/macro/ohos", ... ]
```

而 Keels `0.8.0` app 工程的 `build.bat` 定义：

```bat
set ANDROID_CJ_FRONTEND=!CJMP_UI_PATH!\android\dynamic\ohos
set ANDROID_CJ_MACRO=!CJMP_UI_PATH!\android\macro\ohos
```

即 `${ANDROID_CJ_FRONTEND}` 本身已经指向 `.../dynamic/ohos`，CJson 再拼 `/ohos` 就变成不存在的 `.../ohos/ohos`。

同一文件里还有两处环境相关的残留配置：

- `compile-option` 带 `-L "${ANDROID_BRIDGE}" -ljnimeow`：CJson 本身是纯仓颉 JSON 库（无 `jnimeow` 符号），本工程也没有该 JNI 桥库，留着会在链接阶段出问题。
- `-L ".../lib/clang/17/lib/linux"`：本机 NDK 27 对应 clang 18。

## 处理

修改 cjpm 依赖缓存中的 `cjpm.toml`（提交哈希目录由 cjpm 决定）：

```powershell
Get-ChildItem "$env:USERPROFILE\.cjpm\git\CJson"
```

对 `%USERPROFILE%\.cjpm\git\CJson\<commit>\cjpm.toml` 做三处修改：

1. `path-option` 改为与 app 工程一致：

   ```toml
   path-option = [ "${ANDROID_CJ_FRONTEND}", "${ANDROID_CJ_MACRO}", "${ANDROID_CANGJIE_STDX_PATH}", "${ANDROID_CJMP_LIBS_PATH}/cjmp" ]
   ```

2. 删除 `compile-option` 中的 `-L "${ANDROID_BRIDGE}" -ljnimeow`。
3. 将 `lib/clang/17/lib/linux` 改为 `lib/clang/18/lib/linux`。

改完后 `keels build apk --debug` 即可通过。

## 注意

- 该修改位于 `~/.cjpm` 缓存，**清理 cjpm 缓存或换机器后会复现**。
- 更好的长期方案（任选其一）：
  1. 向上游 CJson 仓库提交修复：`path-option` 使用 `${ANDROID_CJ_FRONTEND}` / `${ANDROID_CJ_MACRO}`，移除 `ANDROID_BRIDGE`/`jnimeow` 依赖。
  2. 把 CJson 作为本地 path 依赖维护（与 `zlibraryAPI4CJ`、`LinderHttp` 一致），在本地仓库中保留修正后的 `cjpm.toml`。

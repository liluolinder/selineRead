# seline_read

Z-Library 桌面阅读客户端，用**仓颉 + CangHui（chui）**写成，后端是 [`zlibraryAPI4CJ`](../zlibraryAPI4CJ)。

```
┌──────────────────────── seline_read（本工程，可执行） ────────────────────────┐
│  main.cj        启动编排：隐藏控制台 → 阻塞初始化 → 原生线程建窗口 → 帧循环     │
│  state.cj       全部可变状态（MVVM 的 ViewModel）+ API 调用 + 图片缓存 + 下载   │
│  shell.cj       自绘标题栏 / 内容面板 / 状态栏                                  │
│  sidebar_rail.cj 可伸缩侧栏（弹簧动画，交互与 seline_bili 一致）                │
│  sidebar_item.cj 侧栏行 / 分区组标题 / 账号入口                                 │
│  home.cj        热门页 + 图书卡片                                               │
│  search.cj      搜索结果页                                                     │
│  detail.cj      图书详情页（元信息 / 可选格式 / 下载）                          │
│  misc_pages.cj  下载列表页 / 设置页（登录表单、本地目录）                        │
│  cover.cj       网络封面绘制 + 文本按宽截断                                     │
│  widgets.cj     加载态 / 空状态 / 错误条 / 页头                                 │
│  platform/      Win32 原生线程包裹、隐藏控制台                                  │
└──────────┬────────────────┬──────────────────┬──────────────────────────────┘
           │                │                  │
      chui（GUI）     seline_ui（共用 UI）  zlibraryAPI4CJ（Z-Library API）
      禁止修改         令牌/组件/标题栏/图片解码   本库
```

## 架构约定（MVVM）

- **Model/ViewModel**：`AppState` 持有所有 `State<T>`；只有 UI 线程写它。
  网络、下载、解码在后台 `spawn` 里做，结果用 `DesktopApp.postToUi` 回投。
- **View**：`homePage` / `searchPage` / `detailPage` / `settingsPage` 等页面函数
  只读 State、声明控件；构建闭包**不发请求**（构建每帧都跑）。
- **平台**：`platform/ui_thread.cj` 用 Win32 `CreateThread` 把 `app.run` 包在
  固定原生线程上（仓颉运行时是 M:N 调度，UI 线程迁移会让窗口抛
  `IllegalStateException`）。
- **共享 UI**：可复用组件（如 `SelineCenteredLeaf`）放进 `seline_ui`；
  `chui` 本身一行不改。

## 功能

| 能力 | 状态 |
| --- | --- |
| 自绘标题栏（frameless + 拖动 + 窗口按钮 + 居中搜索框） | 完成 |
| Windows 原生线程启动 `app.run` | 完成 |
| MVVM 状态层（`AppState` + `State<T>` + `postToUi`） | 完成 |
| 可伸缩侧栏（弹簧动画、分区组、账号入口，交互同 seline_bili） | 完成 |
| 热门图书网格 + 网络封面（磁盘/内存缓存） | 完成 |
| 搜索 + 搜索结果页 | 完成 |
| 图书详情（元信息 / 可选格式 / 简介） | 完成 |
| 登录（邮箱密码，凭证落盘，重启自动恢复） | 完成 |
| 下载（格式选择 → `BookApi.file` → 落盘） | 完成 |
| 下载列表页 | 完成（本次会话记录） |
| 本地阅读器 | 未开始（下载后可先用系统阅读器打开） |

## 缓存与账号文件

- 封面缓存：`%TEMP%\SelineRead\covers/<md5>.jpg`（也就是 `/temp/SelineRead`）。
- 账号凭证：`%TEMP%\SelineRead\account.txt`（`userId|userKey|siteLanguage`，
  与浏览器 Cookie 等价，请勿分享）。
- 下载目录：`%USERPROFILE%\Downloads\SelineRead`（设置页可见）。

## 运行

前提：`SDL3.dll`、`SDL3_ttf.dll` 与 `main.exe` 同目录（`build.ps1` 会自动复制），
且 `C:\Program\SDK\Cangjie\runtime\lib\windows_x86_64_cjnative` 在 `PATH` 上。

```powershell
cd C:\Project\Cangjie\seline_read
.\build.ps1
cd target\release\bin
.\main.exe
```

### 验收开关（不影响正常使用）

```powershell
.\main.exe --shot=%TEMP%\home.png        # 启动后导出窗口画面并退出
.\main.exe --rail                        # 启动即展开侧栏
.\main.exe --tab=2                       # 直接打开下载页
.\main.exe --search=rust                 # 启动即搜索
.\main.exe --login                       # 用 ZLIB_TEST_EMAIL / ZLIB_TEST_PASSWORD 自动登录
.\main.exe --login --download=<id>|<hash> # 登录成功后自动下载指定书
```

诊断日志写在 `%TEMP%/seline_read_debug.log`（Windows 子系统下 stdout 无接收方）。

## 已知限制

- 下载列表目前只记录本次会话（重启后不重新扫描目录）。
- 窗口最大化时圆角暂未归零（普通窗口态 12px 圆角）。
- Windows 上底层 TLS 偶发原生崩溃（`0xc0000374`，环境问题，非本工程代码）。

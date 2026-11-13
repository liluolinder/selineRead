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
| 自绘标题栏（frameless + 拖动 + 窗口按钮 + 居中搜索框 + 品牌图标） | 完成 |
| Windows 原生线程启动 `app.run` | 完成 |
| MVVM 状态层（`AppState` + `State<T>` + `postToUi`） | 完成 |
| 可伸缩侧栏（弹簧动画、分区组、账号入口，交互同 seline_bili） | 完成 |
| 热门图书网格 + 网络封面（磁盘/内存缓存，默认封面占位） | 完成 |
| 搜索 + 搜索结果页 | 完成 |
| 书单页（papi 抓取公开书单 + 预览封面） | 完成 |
| 书单详情（书单内图书网格） | 完成 |
| 图书详情（元信息 / 下载菜单 / 简介 / 评论） | 完成 |
| 登录（邮箱密码，凭证落盘，重启自动恢复） | 完成 |
| 下载（点「下载」弹出菜单：默认链接 + 可选格式 → `BookApi.file` → 落盘） | 完成 |
| 评论（papi：书/书单评论、点赞、回复关系，offset 分页） | 完成 |
| 收藏（eapi `user/book/saved`，登录后分页加载） | 完成 |
| 字体缺字回退（`Fonts.registerBundledFallback`：Windows 优先 msyh.ttc） | 完成 |
| 下载列表页 | 完成（本次会话记录） |
| 本地阅读器 | 未开始（下载后可先用系统阅读器打开） |

## 图标与占位图

- 应用图标：`assets/SR.png`（标题栏品牌位 + `DesktopApp.setWindowIcon`，任务栏/Alt-Tab 生效）。
- 图片占位：`assets/default_cover.png`（封面加载中 / 无封面 / 解码失败时铺在封面上）。
- `build.ps1` 会把 `assets/` 复制到 `target\release\bin\assets\`；运行时按
  `SELINE_READ_ASSETS` → `assets/` → `target/release/bin/assets/` 依次查找。

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
.\main.exe --tab=2                       # 直接打开书单页
.\main.exe --tab=3                       # 直接打开下载页
.\main.exe --tab=1                       # 收藏页（登录后加载 user/book/saved）
.\main.exe --tab=2 --bl-open             # 书单页并自动打开第一份书单
$env:SELINE_READ_SEARCH="三体"          # 启动后直接搜索（中文命令行参数在子系统下会丢，用环境变量）
# 竞态验收：先搜 三体，10ms 后再搜 活着；三体的迟到结果应被丢弃
$env:SELINE_READ_SEARCH="三体"; $env:SELINE_READ_SEARCH_RACE_B="活着"; $env:SELINE_READ_SEARCH_RACE_DELAY_MS="10"
.\main.exe --book=<id>|<hash> --dl-menu  # 打开详情页并展开下载版本菜单
.\main.exe --search=rust                 # 启动即搜索
.\main.exe --login                       # 用 ZLIB_TEST_EMAIL / ZLIB_TEST_PASSWORD 自动登录
.\main.exe --login --download=<id>|<hash> # 登录成功后自动下载指定书
```

诊断日志写在 `%TEMP%/seline_read_debug.log`（Windows 子系统下 stdout 无接收方）。

## 导航

侧栏（无「分区」分组）：**热门 / 收藏 / 书单 / 下载**，设置固定在底部。
搜索不再是独立页签：标题栏回车后结果显示在「热门」页签内，点「热门」图标或「回到热门」退出搜索。

## 已知限制

- 下载列表目前只记录本次会话（重启后不重新扫描目录）。
- 书单与评论都来自网站前端 papi（eapi 没有这两类接口）。
- 评论接口忽略 `limit`、每页固定最多 100 条，分页只能按 offset 递增。
- 首屏偶发某张封面空白：CDN 请求失败时显示默认封面占位图，不会反复重试。\n- 首页不设页头与底部状态栏（用户要求）：直接一墙封面；只有获取失败时才出现「重新加载」按钮。
- 窗口最大化时圆角暂未归零（普通窗口态 12px 圆角）。
- Windows 上底层 TLS 偶发原生崩溃（`0xc0000374`，环境问题，非本工程代码）。

## 设置 / 下载 / 主题（本轮新增）

### 设置页（左侧竖直页签）

| 页签 | 内容 |
| --- | --- |
| 显示设置 | 深浅色主题（切换时从按钮位置向外辐射切换） + 账号登录 |
| 下载设置 | 下载目录（可编辑、自动创建、持久化） |
| 网络设置 | 3 个官方站占位（不可删） + 自定义站（可增删，单选框选当前站） + 种子站（可增删） + 「重新拉取站点」 |

配置持久化在 `%TEMP%/SelineRead/user_config.txt`（主题 / 下载目录 / 当前站点 / 自定义站 / 种子站）。
启动时先读配置，用选中站点建客户端，种子站列表一起传给 `ZlibClient`；
**种子站回退成功的新地址会覆盖当前自定义站点并持久化**（`adoptRefreshedSite`）。

### 下载管理器（selineDownload）

- 依赖 `../selineDownload`；下载页展示任务列表：标题、状态、进度条、`已下载/总大小 · 速度`、失败原因；
- 每个进行中的任务有「停止」按钮（`DownloadTask.cancel`），另有「清空已结束」；
- zlib 链接不支持 Range / 多线程，所以固定**单线程 + 关闭断点续传**：停止后只能重新下载；
- 进度回调经 `postToUi` 回到 UI 线程，每 100ms 刷新一次。

### 评论

- 滚到底部自动「揭示更多 / 加载下一页」，不再需要点按钮；
- 「回复」会显示 `回复 @原评论作者` + 原评论正文（父评论不在已加载分页时提示未加载）。

### 导航

- 从详情页「相关书籍」再进另一本时，`返回` 回到**上一本书**（详情返回栈），再返回才回到列表；
- 首页 / 搜索 / 收藏 / 书单 / 详情各自保留滚动位置（切页再回来不会跳到顶部）。

## 验收开关（新增）

```powershell
$env:SELINE_READ_OFFLINE="1"              # 跳过网络首屏（只跑 UI，截图/回归用）
$env:SELINE_READ_LIGHT="1"                # 启动即浅色
$env:SELINE_READ_TOGGLE_THEME_MS="1200"   # 启动后 1.2s 触发一次主题切换（看辐射动画）
$env:SELINE_READ_SETTINGS_TAB="2"         # 设置页直接切到网络设置（0/1/2）
$env:SELINE_READ_DETAIL_SECTION="1"       # 详情页切到评论（0 信息 / 1 评论 / 2 相关）
$env:SELINE_READ_DETAIL_SCROLL="1400"; $env:SELINE_READ_SCROLL_AFTER_MS="2500"  # 内容加载完后再滚到指定位置
$env:SELINE_READ_TEST_NAV="1"             # 自检详情返回栈（日志 navselftest）
$env:SELINE_READ_TEST_DL="1"              # 自检下载管理器（真实下载一本书，日志 dlselftest）
```
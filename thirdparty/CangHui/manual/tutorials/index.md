# Tutorials

- [cuic 工具链：构建、运行、调试、截图与 ASCII 布局](cuic-cli.md)
- [桌面无边框窗口](frameless-window.md)
- [外部帧平面与输入桥（开发者预览）](platform-interfaces.md)
- [Surface、交互所有权与容器排版](surface-and-typography.md)

## cuic 新特性速览

| 命令 | 作用 |
|---|---|
| `cuic build/test/run [platform] [project]` | 构建/测试/运行 |
| `cuic debug [platform] [project] [--device] [--app]` | 显式调试渠道命令面 |
| `cuic prnt [platform] [project] [--device] [--app] [--output]` | 截图/设备界面获取 |
| `cuic pview [project] <probe> [--columns] [--rows] [--events]` | ASCII 布局输出 |
| `cuic device list [--json]` | 列出 hdc 设备 |

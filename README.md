# Seline Read

<div align="center">

**阅韵心读 - 鸿蒙平台电子书管理平台**

一个优雅的 Z-Library 第三方客户端，为鸿蒙系统用户带来极致的电子书阅读体验。

[![HarmonyOS](https://img.shields.io/badge/HarmonyOS-5.0.5+-blue.svg)]()
[![License](https://img.shields.io/badge/license-MulanPSL2-blue.svg)]()

</div>

## 简介

Seline Read 是专为鸿蒙系统打造的 Z-Library 第三方客户端，提供了简洁优雅的界面和流畅的阅读体验。应用支持书籍搜索、下载管理、书架管理等核心功能，未来将扩展支持更多电子书协议。

## 功能特性

### 核心功能
- **书籍搜索** - 快速搜索 Z-Library 海量电子书资源
- **书籍下载** - 支持多种格式电子书下载
- **下载管理** - 完整的下载任务管理和状态追踪
- **本地书架** - 优雅的本地书籍管理和阅读记录
- **账号管理** - 安全的 Z-Library 账号登录和管理

### 特色功能
- **状态栏集成** - 便捷的状态栏快速访问
- **后台下载** - 支持后台数据传输，下载不打断阅读
- **分享导出** - 一键分享或导出下载的书籍
- **冲突处理** - 智能文件冲突处理（覆盖/共存）
- **显示设置** - 个性化显示和界面配置
- **适人握持** - 贴心的握持优化设计

## 技术栈

- **开发语言**: ArkTS / Cangjie
- **目标 SDK 版本**: HarmonyOS 6.0.2 (API 22)
- **支持设备**: 手机、平板、2合1设备、电视、穿戴设备

### 核心依赖
- `@hadss/super_fast_file_trans` - 高速文件传输组件

## 项目结构

```
SelineRead/
├── entry/                    # 主应用模块
│   └── src/main/
│       ├── ets/
│       │   ├── entryability/        # 应用入口
│       │   ├── statusBarViewAbility/ # 状态栏扩展
│       │   ├── selineRead/          # 核心阅读功能
│       │   └── zlibrary/            # Z-Library 协议实现
│       ├── cangjie/                 # Cangjie 语言模块
│       └── resources/               # 资源文件
├── features/                 # 功能模块
│   ├── commonPackage/        # 通用组件包
│   ├── color/                # 颜色主题
│   └── templateComponent/    # 模板组件
└── AppScope/                 # 应用全局配置
```

## 快速开始

### 环境要求
- DevEco Studio 5.0+
- HarmonyOS SDK 5.0.5+
- Node.js (用于依赖管理)

### 安装步骤

1. **克隆仓库**
```bash
git clone https://gitcode.com/LiquidStudio/SelineRead.git
cd SelineRead
```

2. **安装依赖**
```bash
ohpm install
```

3. **配置签名**
- 在 DevEco Studio 中配置应用签名证书
- 或修改 `build-profile.json5` 中的签名配置

4. **运行应用**
- 连接鸿蒙设备或启动模拟器
- 在 DevEco Studio 中点击运行按钮

## 权限说明

应用需要以下权限：
- `ohos.permission.INTERNET` - 网络访问（搜索和下载书籍）
- `ohos.permission.KEEP_BACKGROUND_RUNNING` - 后台运行（后台下载）
- `ohos.permission.GET_NETWORK_INFO` - 获取网络信息
- `ohos.permission.WINDOW_TOPMOST` - 窗口置顶（状态栏扩展）

## 路线图

### 已完成
- Z-Library 协议支持
- 书籍搜索和下载
- 本地书架管理
- 下载任务管理
- 账号登录管理

### 计划中
- [ ] 支持更多电子书源协议
- [ ] 阅读器功能增强
- [ ] 书籍笔记和批注
- [ ] 多语言支持

## 贡献

欢迎提交 Issue 和 Pull Request！

1. Fork 本仓库
2. 创建特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 开启 Pull Request



## 鸣谢

- 感谢 Z-Library 提供的海量书籍资源
- 感谢鸿蒙生态的开发支持
- 感谢所有贡献者和测试用户

## 许可证

本项目采用木兰宽松许可证第2版（MulanPSL-2.0） - 详见 [LICENSE](LICENSE) 文件


## 联系方式

- 仓库地址: [GitCode](https://gitcode.com/LiquidStudio/SelineRead)
- QQ群: 228546422
- Issue: [GitCode Issues](https://gitcode.com/LiquidStudio/SelineRead/issues)

## 免责声明

本应用仅为 Z-Library 的第三方客户端，与 Z-Library 官方无任何关联。用户使用本应用搜索和下载的内容应遵守当地法律法规。开发者不对用户的使用行为负责。

---

<div align="center">

**如果觉得这个项目对你有帮助，请给个 Star ⭐**

</div>

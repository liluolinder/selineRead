# zlibraryAPI4CJ

一个用于访问 Z-Library 的 Cangjie 语言 API 客户端库。

## 简介

zlibraryAPI4CJ 是一个用 Cangjie 编程语言开发的 Z-Library API 客户端库，提供了用户认证、图书搜索、图书信息获取、下载等功能。

## 功能特性

- 用户登录（邮箱密码登录 / 用户ID和密钥登录）
- 图书搜索（支持按年份过滤）
- 获取推荐图书
- 获取图书详细信息
- 获取相似书籍
- 保存/取消保存书籍
- 获取下载链接和下载文件
- 获取用户保存的书籍列表
- 获取用户推荐书籍

## 依赖项

- `html4cj` - HTML 解析库
- `linderHttp` - HTTP 请求库
- `cjjson` - JSON 序列化/反序列化库

## 安装

```bash
cjpm install
```

## 快速开始

### 基本使用

```cangjie
import zlibraryAPI4CJ

// 创建客户端
let client = ZlibClient()

// 使用邮箱密码登录
let loginRes = client.login(email: "your@email.com", password: "your_password")

if (loginRes.success == 1) {
    let userInfo = loginRes.userInfo.getOrThrow()
    println("登录成功，用户ID: ${userInfo.id}")
}

// 搜索图书
let searchRes = client.search(message: "Python编程", page: 1, limit: 10)
for (book in searchRes.books) {
    println("书名: ${book.title}, 作者: ${book.author}")
}

// 获取推荐图书
let recommendRes = client.getRecommendBook()
```

### 使用用户ID和密钥登录

```cangjie
import zlibraryAPI4CJ

let client = ZlibClient()

// 使用用户ID和密钥登录
let loginRes = client.login(userID: 12345678, userKey: "your_user_key")
```

### 获取图书详细信息

```cangjie
// 从搜索结果获取图书详细信息
let searchRes = client.search(message: "Rust编程")
    if (searchRes.books.size > 0) {
        let book = searchRes.books[0]
        let info = book
        println("标题: ${info.title}")
        println("作者: ${info.author.getOrThrow()}")
        println("页数: ${info.pages}")
        println("文件大小: ${info.filesizeString}")
    }
```

### 下载图书

```cangjie
// 登录后获取下载信息
let loginRes = client.login(email: "your@email.com", password: "password")
let userInfo = loginRes.userInfo.getOrThrow()
let cookie = userInfo.cookie

// 获取图书详细信息
let detailRes = book.getBookInfo(cookie: cookie)
let downloadRes = detailRes.book.getDownloadInfo(cookie: cookie)

if (downloadRes.success == 1) {
    let downloadInfo = downloadRes.file
    if (downloadInfo.allowDownload) {
        // 下载文件到指定路径
        downloadInfo.download(path: Path("D:/downloads"))
    }
}
```

### 获取用户保存的书籍

```cangjie
let loginRes = client.login(email: "your@email.com", password: "password")
let userInfo = loginRes.userInfo.getOrThrow()

// 获取第一页保存的书籍
let savedRes = userInfo.getSaved(page: 1)

for (book in savedRes.books) {
    println("书名: ${book.title}")
}

println("当前页: ${savedRes.pagination.current}")
println("总页数: ${savedRes.pagination.totalPages}")
```

### 保存和取消保存书籍

```cangjie
let loginRes = client.login(email: "your@email.com", password: "password")
let userInfo = loginRes.userInfo.getOrThrow()
let cookie = userInfo.cookie

// 保存书籍
let book = searchRes.books[0]
let saved = book.saveBook(cookie: cookie)
if (saved) {
    println("保存成功")
}

// 取消保存
let unSaved = book.unSaveBook(cookie: cookie)
if (unSaved) {
    println("取消保存成功")
}
```

## 配置

可以通过修改 `src/common/commons.cj` 文件来配置 API 基础 URL：

```cangjie
public var zlibBaseUrl: String = "https://zh.101run.ru"
public var zlibEAPI: String = "${zlibBaseUrl}/eapi"
```

## 项目结构

```
src/
├── client.cj              # 主客户端类 ZlibClient
├── common/
│   └── commons.cj         # 公共配置和工具
└── dataModel/
    ├── bookInfo.cj        # 图书详细信息模型
    ├── bookInfoBrief.cj   # 图书简要信息模型
    ├── downloadInfo.cj    # 下载信息模型
    ├── userInfo.cj        # 用户信息模型
    ├── userSavedBook.cj   # 用户保存书籍和分页模型
    └── importFile.cj      # 导入文件
```

## 许可证

本项目遵循相应的开源许可证。

## 贡献

欢迎提交 Issue 和 Pull Request。

## 免责声明

本库仅供学习和研究使用，请遵守 Z-Library 的使用条款和相关法律法规。

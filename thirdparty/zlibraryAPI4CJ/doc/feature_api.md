# zlibraryAPI4CJ API 参考文档

## 目录

- [ZlibClient 类](#zlibclient-类)
- [数据模型](#数据模型)
  - [BookInfo](#bookinfo)
  - [BookInfoBrief](#bookinfobrief)
  - [DownloadInfo](#downloadinfo)
  - [ZlibUserInfo](#zlibuserinfo)
  - [Pagination](#pagination)
- [响应结构](#响应结构)

---

## ZlibClient 类

Z-Library API 的主客户端类，提供用户认证和图书搜索功能。

### 方法

#### `login(email: String, password: String): GetUserInfoOrLoginRes`

使用邮箱和密码登录 Z-Library。

**参数：**
- `email` (String) - 用户邮箱地址
- `password` (String) - 用户密码

**返回值：**
- `GetUserInfoOrLoginRes` - 登录响应，包含用户信息

**示例：**
```cangjie
let client = ZlibClient()
let res = client.login(email: "user@example.com", password: "password123")
if (res.success == 1) {
    let userInfo = res.userInfo.getOrThrow()
    println("用户ID: ${userInfo.id}")
}
```

---

#### `login(userID: UInt64, userKey: String): GetUserInfoOrLoginRes`

使用用户ID和密钥登录 Z-Library。

**参数：**
- `userID` (UInt64) - 用户ID
- `userKey` (String) - 用户密钥 (remix_userkey)

**返回值：**
- `GetUserInfoOrLoginRes` - 登录响应，包含用户信息

**示例：**
```cangjie
let client = ZlibClient()
let res = client.login(userID: 12345678, userKey: "your_user_key")
```

---

#### `getRecommendBook(): GetBookRes`

获取热门推荐图书（无需登录）。

**返回值：**
- `GetBookRes` - 包含推荐图书列表的响应

**示例：**
```cangjie
let client = ZlibClient()
let res = client.getRecommendBook()
for (book in res.books) {
    println("书名: ${book.title}")
}
```

---

#### `search(message: String, yearFrom: ?UInt16 = None, yearTo: ?UInt16 = None, page: UInt16 = 1, limit: UInt16 = 20): GetBookWithInfoAndPaginationRes`

搜索图书。

**参数：**
- `message` (String) - 搜索关键词
- `yearFrom` (?UInt16) - 起始年份（可选）
- `yearTo` (?UInt16) - 结束年份（可选）
- `page` (UInt16) - 页码，默认为 1
- `limit` (UInt16) - 每页数量，默认为 20

**返回值：**
- `GetBookWithInfoAndPaginationRes` - 包含图书列表和分页信息的响应

**示例：**
```cangjie
let client = ZlibClient()

// 基本搜索
let res1 = client.search(message: "Python编程")

// 带年份过滤的搜索
let res2 = client.search(
    message: "人工智能",
    yearFrom: 2020,
    yearTo: 2024,
    page: 1,
    limit: 10
)
```

---

## 数据模型

### BookInfo

图书详细信息类。

#### 属性

| 属性名 | 类型 | 说明 |
|--------|------|------|
| `id` | UInt64 | 图书ID |
| `contentType` | String | 内容类型 |
| `title` | String | 书名 |
| `author` | ?String | 作者 |
| `volume` | String | 卷号 |
| `year` | UInt64 | 出版年份 |
| `edition` | ?String | 版本 |
| `publisher` | ?String | 出版社 |
| `identifier` | ?String | 标识符（ISBN等） |
| `language` | String | 语言 |
| `pages` | UInt64 | 页数 |
| `series` | String | 系列 |
| `cover` | String | 封面URL |
| `termsHash` | String | 术语哈希 |
| `active` | UInt64 | 激活状态 |
| `deleted` | UInt64 | 删除状态 |
| `filesize` | UInt64 | 文件大小（字节） |
| `filesizeString` | String | 文件大小（格式化字符串） |
| `extension` | String | 文件扩展名 |
| `md5` | String | MD5哈希 |
| `sha256` | String | SHA256哈希 |
| `href` | String | 链接 |
| `hash` | String | 图书哈希 |
| `kindleAvailable` | Bool | 是否可发送到Kindle |
| `sendToEmailAvailable` | Bool | 是否可发送到邮箱 |
| `interestScore` | String | 兴趣评分 |
| `qualityScore` | String | 质量评分 |
| `description` | String | 描述 |
| `dl` | String | 下载链接 |
| `readOnlineUrl` | String | 在线阅读URL |
| `isUserSavedBook` | ?Bool | 是否已保存 |
| `dataSaved` | ?String | 保存日期 |
| `readOnlineAvailable` | Bool | 是否可在线阅读 |

#### 方法

##### `saveBook(cookie: String): Bool`

保存图书到用户收藏。

**参数：**
- `cookie` (String) - 用户cookie

**返回值：**
- `Bool` - 是否保存成功

**示例：**
```cangjie
let saved = book.saveBook(cookie: userInfo.cookie)
if (saved) {
    println("保存成功")
}
```

---

##### `unSaveBook(cookie: String): Bool`

取消保存图书。

**参数：**
- `cookie` (String) - 用户cookie

**返回值：**
- `Bool` - 是否取消成功

**示例：**
```cangjie
let unSaved = book.unSaveBook(cookie: userInfo.cookie)
if (unSaved) {
    println("取消保存成功")
}
```

---

##### `getSimilarBook(): GetBookRes`

获取相似图书推荐。

**返回值：**
- `GetBookRes` - 相似图书列表

**示例：**
```cangjie
let similarRes = book.getSimilarBook()
for (similarBook in similarRes.books) {
    println("相似书名: ${similarBook.title}")
}
```

---

##### `getDownloadInfo(cookie: String): GetDownloadInfoRes`

获取图书下载信息。

**参数：**
- `cookie` (String) - 用户cookie

**返回值：**
- `GetDownloadInfoRes` - 下载信息响应

**示例：**
```cangjie
let downloadRes = book.getDownloadInfo(cookie: userInfo.cookie)
if (downloadRes.success == 1) {
    let info = downloadRes.file
    if (info.allowDownload) {
        info.download(path: Path("D:/downloads"))
    }
}
```

---

### BookInfoBrief

图书简要信息类。

#### 属性

| 属性名 | 类型 | 说明 |
|--------|------|------|
| `id` | UInt64 | 图书ID |
| `title` | String | 书名 |
| `author` | String | 作者 |
| `cover` | String | 封面URL |
| `hash` | String | 图书哈希 |

#### 方法

##### `getBookInfo(cookie: ?String = None): GetBookInfoRes`

获取图书详细信息。

**参数：**
- `cookie` (?String) - 用户cookie（可选）

**返回值：**
- `GetBookInfoRes` - 图书详细信息响应

**示例：**
```cangjie
// 不登录获取基本信息
let res = book.getBookInfo()

// 登录后获取完整信息
let res = book.getBookInfo(cookie: userInfo.cookie)
```

---

##### `getSimilarBook(): GetBookRes`

获取相似图书推荐。

**返回值：**
- `GetBookRes` - 相似图书列表

---

##### `getDownloadInfo(cookie: String): GetDownloadInfoRes`

获取图书下载信息。

**参数：**
- `cookie` (String) - 用户cookie

**返回值：**
- `GetDownloadInfoRes` - 下载信息响应

---

### DownloadInfo

下载信息类。

#### 属性

| 属性名 | 类型 | 说明 |
|--------|------|------|
| `downloadLink` | String | 下载链接 |
| `description` | String | 描述 |
| `author` | String | 作者 |
| `extension` | String | 文件扩展名 |
| `allowDownload` | Bool | 是否允许下载 |

#### 属性（计算属性）

##### `fileName: String`

从下载链接中提取文件名。

**示例：**
```cangjie
let fileName = downloadInfo.fileName
println("文件名: ${fileName}")
```

#### 方法

##### `download(path: Path, conflictMethod: ConflictMethod = ConflictMethod.HARMONY)`

下载文件到指定路径。

**参数：**
- `path` (Path) - 保存目录路径
- `conflictMethod` (ConflictMethod) - 文件冲突处理方式，默认为 `ConflictMethod.HARMONY`

**示例：**
```cangjie
// 下载到指定目录
downloadInfo.download(path: Path("D:/downloads"))

// 指定冲突处理方式
downloadInfo.download(
    path: Path("D:/downloads"),
    conflictMethod: ConflictMethod.OVERWRITE
)
```

---

### ZlibUserInfo

用户信息类。

#### 属性

| 属性名 | 类型 | 说明 |
|--------|------|------|
| `id` | UInt64 | 用户ID |
| `email` | String | 邮箱 |
| `name` | String | 用户名 |
| `kindleEmail` | String | Kindle邮箱 |
| `remixUserkey` | String | 用户密钥 |
| `todyDownloadNum` | UInt64 | 今日下载次数 |
| `downloadLimit` | UInt64 | 下载限制 |

#### 属性（计算属性）

##### `cookie: String`

生成用户cookie字符串。

**示例：**
```cangjie
let cookie = userInfo.cookie
// cookie 格式: "siteLanguage=zh; remix_userkey=xxx; remix_userid=xxx"
```

#### 方法

##### `getPersonalInfo(): GetUserInfoOrLoginRes`

获取用户个人信息。

**返回值：**
- `GetUserInfoOrLoginRes` - 用户信息响应

**示例：**
```cangjie
let res = userInfo.getPersonalInfo()
if (res.success == 1) {
    println("用户名: ${res.userInfo.getOrThrow().name}")
}
```

---

##### `getSaved(page: UInt64 = 1): GetBookWithInfoAndPaginationRes`

获取用户保存的书籍列表。

**参数：**
- `page` (UInt64) - 页码，默认为 1

**返回值：**
- `GetBookWithInfoAndPaginationRes` - 包含书籍列表和分页信息的响应

**示例：**
```cangjie
let res = userInfo.getSaved(page: 1)
for (book in res.books) {
    println("书名: ${book.title}")
}
println("总页数: ${res.pagination.totalPages}")
```

---

##### `getRecommendBook(): GetBookRes`

获取用户个性化推荐图书。

**返回值：**
- `GetBookRes` - 推荐图书列表

**示例：**
```cangjie
let res = userInfo.getRecommendBook()
for (book in res.books) {
    println("推荐书名: ${book.title}")
}
```

---

### Pagination

分页信息结构体。

#### 属性

| 属性名 | 类型 | 说明 |
|--------|------|------|
| `limit` | UInt64 | 每页数量 |
| `current` | UInt64 | 当前页码 |
| `totalItems` | UInt64 | 总项目数 |
| `totalPages` | UInt64 | 总页数 |

---

## 响应结构

### GetUserInfoOrLoginRes

用户信息或登录响应。

**属性：**
| 属性名 | 类型 | 说明 |
|--------|------|------|
| `success` | UInt8 | 是否成功（1=成功，0=失败） |
| `errorInfo` | ?String | 错误信息 |
| `userInfo` | ?ZlibUserInfo | 用户信息 |

---

### GetBookRes

图书列表响应。

**属性：**
| 属性名 | 类型 | 说明 |
|--------|------|------|
| `success` | UInt8 | 是否成功 |
| `books` | Array<BookInfoBrief> | 图书列表 |

---

### GetBookInfoRes

图书详细信息响应。

**属性：**
| 属性名 | 类型 | 说明 |
|--------|------|------|
| `success` | UInt8 | 是否成功 |
| `book` | BookInfo | 图书详细信息 |

---

### GetDownloadInfoRes

下载信息响应。

**属性：**
| 属性名 | 类型 | 说明 |
|--------|------|------|
| `success` | UInt8 | 是否成功 |
| `file` | DownloadInfo | 下载信息 |

---

### GetBookWithInfoAndPaginationRes

带分页信息的图书列表响应。

**属性：**
| 属性名 | 类型 | 说明 |
|--------|------|------|
| `success` | UInt8 | 是否成功 |
| `books` | Array<BookInfo> | 图书详细信息列表 |
| `pagination` | Pagination | 分页信息 |

---

## 公共配置

### commons.cj

公共配置文件，包含以下全局变量：

```cangjie
public var zlibBaseUrl: String = "https://zh.101run.ru"
public var zlibEAPI: String = "${zlibBaseUrl}/eapi"
public var httpClient: LinderHttp = LinderHttp(
    readTimeout: Duration.minute,
    writeTimeout: Duration.minute
)
```

可以通过修改这些变量来配置API基础URL和HTTP客户端参数。

---

## 错误处理

大多数方法在遇到错误时会抛出 `Exception` 异常。建议使用 `try-catch` 语句进行错误处理。

**示例：**
```cangjie
try {
    let res = client.search(message: "Python")
    // 处理结果
} catch (err: Exception) {
    println("发生错误: ${err.message}")
}
```

---

## 使用建议

1. **登录后保存cookie**：登录后获取 `ZlibUserInfo` 实例，使用其 `cookie` 属性进行需要认证的操作。

2. **检查success字段**：所有响应都有 `success` 字段，操作前应检查其值是否为 1。

3. **处理可选值**：注意处理 `?String`、`?Bool` 等可选类型字段，使用 `isSome()`、`getOrThrow()` 等方法。

4. **下载文件**：下载前检查 `allowDownload` 属性，确保允许下载。

5. **分页处理**：使用 `Pagination` 信息处理分页查询，避免一次性获取过多数据。

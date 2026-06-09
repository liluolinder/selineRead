package selineWebdav

import ignite.*
import std.collection.ArrayList
import std.fs.Path
import std.time.DateTime
import stdx.encoding.base64.*
import stdx.log.*

// 日志器
let logger: Logger = getGlobalLogger()

// 用户认证信息
public struct WebDavUser {
    public let username: String
    public let password: String

    public init(username: String, password: String) {
        this.username = username
        this.password = password
    }
}

// WebDAV配置
public struct WebDavConfig {
    public let rootPath: String
    public let enableRead: Bool
    public let enableWrite: Bool
    public let enableDelete: Bool
    public let enableMkcol: Bool
    public let enableCopy: Bool
    public let enableMove: Bool
    public let showHidden: Bool
    public let enableAuth: Bool
    public let users: ArrayList<WebDavUser>
    public let realm: String
    public let encodeHref: Bool

    public init(
        rootPath: String,
        enableRead!: Bool = true,
        enableWrite!: Bool = true,
        enableDelete!: Bool = true,
        enableMkcol!: Bool = true,
        enableCopy!: Bool = true,
        enableMove!: Bool = true,
        showHidden!: Bool = false,
        enableAuth!: Bool = false,
        users!: ArrayList<WebDavUser> = ArrayList<WebDavUser>(),
        realm!: String = "WebDAV",
        encodeHref!: Bool = false
    ) {
        this.rootPath = rootPath
        this.enableRead = enableRead
        this.enableWrite = enableWrite
        this.enableDelete = enableDelete
        this.enableMkcol = enableMkcol
        this.enableCopy = enableCopy
        this.enableMove = enableMove
        this.showHidden = showHidden
        this.enableAuth = enableAuth
        this.users = users
        this.realm = realm
        this.encodeHref = encodeHref
    }
}

// WebDAV处理器
public class WebDavHandler {
    private let fileManager: FileManager
    private let config: WebDavConfig

    public init(config: WebDavConfig) {
        this.config = config
        this.fileManager = FileManager(config.rootPath)
        logger.info("WebDavHandler initialized with root: ${config.rootPath}")
    }

    public init(rootPath: String) {
        this.config = WebDavConfig(rootPath)
        this.fileManager = FileManager(rootPath)
        logger.info("WebDavHandler initialized with root: ${rootPath}")
    }

    // 获取根路径
    public func getRootPath(): String {
        fileManager.getRootPath()
    }

    // 主处理函数
    public func handle(ctx: Ctx): Unit {
        // 检查认证
        if (config.enableAuth) {
            if (!checkAuth(ctx)) {
                sendAuthRequired(ctx)
                return
            }
        }

        let method = ctx.method
        let path = ctx.path
        logger.debug("Request: ${method} ${path}")

        match (method) {
            case "GET" => handleGet(ctx)
            case "PUT" => handlePut(ctx)
            case "DELETE" => handleDelete(ctx)
            case "PROPFIND" => handlePropFind(ctx)
            case "PROPPATCH" => handlePropPatch(ctx)
            case "MKCOL" => handleMkcol(ctx)
            case "COPY" => handleCopy(ctx)
            case "MOVE" => handleMove(ctx)
            case "HEAD" => handleHead(ctx)
            case "OPTIONS" => handleOptions(ctx)
            case "LOCK" => handleLock(ctx)
            case "UNLOCK" => handleUnlock(ctx)
            case _ => handleNotImplemented(ctx)
        }
    }

    // 检查HTTP Basic认证
    private func checkAuth(ctx: Ctx): Bool {
        let authHeader = ctx.header("Authorization") ?? ""
        
        if (!authHeader.startsWith("Basic ")) {
            return false
        }

        // 解码Base64
        let encoded = authHeader[6..]
        let decoded = decodeBase64(encoded)
        
        // 解析 username:password
        match (decoded.indexOf(":")) {
            case Some(colonIndex) =>
                let username = decoded[0..colonIndex]
                let password = decoded[(colonIndex + 1)..]

                // 验证用户
                for (user in config.users) {
                    if (user.username == username && user.password == password) {
                        return true
                    }
                }
                logger.warn("Authentication failed for user: ${username}")
                false
            case None => false
        }
    }

    // 发送401未授权响应
    private func sendAuthRequired(ctx: Ctx): Unit {
        logger.warn("Unauthorized access attempt to: ${ctx.path}")
        // WebDAV客户端需要XML格式的错误响应
        let errorXml = "<?xml version=\"1.0\" encoding=\"utf-8\"?>\n" +
            "<D:error xmlns:D=\"DAV:\">\n" +
            "  <D:need-auth/>\n" +
            "</D:error>"
        
        ctx.status(401)
            .setHeader("WWW-Authenticate", "Basic realm=\"${config.realm}\", charset=\"UTF-8\"")
            .setHeader("Content-Type", "application/xml; charset=utf-8")
            .setHeader("DAV", "1, 2")
            .sendString(errorXml)
    }

    // Base64解码
    private func decodeBase64(encoded: String): String {
        match (fromBase64String(encoded)) {
            case Some(bytes) => String.fromUtf8(bytes)
            case None => ""
        }
    }

    // GET - 下载文件
    private func handleGet(ctx: Ctx): Unit {
        if (!config.enableRead) {
            logger.warn("GET forbidden: read access denied for ${ctx.path}")
            ctx.status(403).sendString("Forbidden")
            return
        }

        let requestPath = ctx.path
        match (fileManager.getSafePath(requestPath)) {
            case Some(fullPath) =>
                if (!fileManager.exists(fullPath)) {
                    logger.warn("GET not found: ${requestPath}")
                    ctx.status(404).sendString("Not Found")
                    return
                }

                if (fileManager.isDirectory(fullPath)) {
                    // 对于目录，返回HTML目录列表
                    logger.debug("GET directory listing: ${requestPath}")
                    sendDirectoryListing(ctx, fullPath, requestPath)
                } else {
                    // 发送文件
                    logger.info("GET file: ${requestPath}")
                    ctx.sendFile(fullPath)
                }
            case None => 
                logger.warn("GET forbidden (unsafe path): ${requestPath}")
                ctx.status(403).sendString("Forbidden")
        }
    }

    // PUT - 上传文件
    private func handlePut(ctx: Ctx): Unit {
        if (!config.enableWrite) {
            logger.warn("PUT forbidden: write access denied for ${ctx.path}")
            ctx.status(403).sendString("Forbidden")
            return
        }

        let requestPath = ctx.path
        match (fileManager.getSafePath(requestPath)) {
            case Some(fullPath) =>
                // 检查父目录是否存在
                let parentDir = Path(fullPath).parent.toString()
                if (parentDir.size > 0 && !fileManager.exists(parentDir)) {
                    logger.warn("PUT conflict: parent directory does not exist for ${requestPath}")
                    ctx.status(409).sendString("Conflict")
                    return
                }

                // 检查资源是否已存在
                let resourceExists = fileManager.exists(fullPath)

                // 读取请求体
                let data = ctx.bodyBytes()
                if (fileManager.writeFile(fullPath, data)) {
                    if (resourceExists) {
                        logger.info("PUT updated: ${requestPath}")
                        ctx.status(204).noContent()
                    } else {
                        logger.info("PUT created: ${requestPath}")
                        ctx.status(201).sendString("Created")
                    }
                } else {
                    logger.error("PUT failed: ${requestPath}")
                    ctx.status(500).sendString("Internal Server Error")
                }
            case None => 
                logger.warn("PUT forbidden (unsafe path): ${requestPath}")
                ctx.status(403).sendString("Forbidden")
        }
    }

    // DELETE - 删除文件或目录
    private func handleDelete(ctx: Ctx): Unit {
        if (!config.enableDelete) {
            logger.warn("DELETE forbidden: delete access denied for ${ctx.path}")
            ctx.status(403).sendString("Forbidden")
            return
        }

        let requestPath = ctx.path
        match (fileManager.getSafePath(requestPath)) {
            case Some(fullPath) =>
                if (!fileManager.exists(fullPath)) {
                    logger.warn("DELETE not found: ${requestPath}")
                    ctx.status(404).sendString("Not Found")
                    return
                }

                let success = if (fileManager.isDirectory(fullPath)) {
                    fileManager.deleteDirectory(fullPath)
                } else {
                    fileManager.deleteFile(fullPath)
                }

                if (success) {
                    logger.info("DELETE success: ${requestPath}")
                    ctx.status(204).noContent()
                } else {
                    logger.error("DELETE failed: ${requestPath}")
                    ctx.status(500).sendString("Internal Server Error")
                }
            case None => 
                logger.warn("DELETE forbidden (unsafe path): ${requestPath}")
                ctx.status(403).sendString("Forbidden")
        }
    }

    // PROPFIND - 获取属性/列出目录
    private func handlePropFind(ctx: Ctx): Unit {
        if (!config.enableRead) {
            logger.warn("PROPFIND forbidden: read access denied for ${ctx.path}")
            ctx.status(403).sendString("Forbidden")
            return
        }

        let requestPath = ctx.path
        match (fileManager.getSafePath(requestPath)) {
            case Some(fullPath) =>
                if (!fileManager.exists(fullPath)) {
                    logger.warn("PROPFIND not found: ${requestPath}")
                    ctx.status(404).sendString("Not Found")
                    return
                }

                // 解析Depth头
                let depthHeader = ctx.header("Depth") ?? "0"
                let depth = parseDepth(depthHeader)
                logger.debug("PROPFIND ${requestPath} Depth: ${depthHeader}")

                // 构建多状态响应
                let builder = MultiStatusBuilder(fileManager.getRootPath(), encodeHref: config.encodeHref)
                builder.start()

                // 添加当前资源
                match (fileManager.getFileInfo(fullPath)) {
                    case Some(info) =>
                        builder.addFileResponse(info, depth)

                        // 如果是目录且depth > 0，添加子项
                        if (info.isDirectory && depth > 0) {
                            addDirectoryEntries(builder, fullPath, depth, true)
                        }
                    case None => ()
                }

                builder.end()

                // 发送响应
                logger.debug("PROPFIND success: ${requestPath}")
                ctx.status(207)
                    .setHeader("Content-Type", "application/xml; charset=utf-8")
                    .setHeader("DAV", "1, 2")
                    .sendString(builder.build())
            case None => 
                logger.warn("PROPFIND forbidden (unsafe path): ${requestPath}")
                ctx.status(403).sendString("Forbidden")
        }
    }

    // 递归添加目录条目
    private func addDirectoryEntries(builder: MultiStatusBuilder, dirPath: String, depth: Int64, _isRoot: Bool): Unit {
        let entries = fileManager.listDirectory(dirPath)
        for (entry in entries) {
            // 跳过隐藏文件
            if (!config.showHidden && entry.name.startsWith(".")) {
                continue
            }
            
            builder.addFileResponse(entry, depth)
            
            // 如果是目录且depth > 1（或infinity），递归添加子目录
            if (entry.isDirectory && depth > 1) {
                // 使用Path来正确处理路径拼接
                let fullPath = Path(dirPath).join(entry.name).toString()
                addDirectoryEntries(builder, fullPath, depth - 1, false)
            }
        }
    }

    // MKCOL - 创建目录
    private func handleMkcol(ctx: Ctx): Unit {
        if (!config.enableMkcol) {
            logger.warn("MKCOL forbidden: mkcol access denied for ${ctx.path}")
            ctx.status(403).sendString("Forbidden")
            return
        }

        let requestPath = ctx.path
        match (fileManager.getSafePath(requestPath)) {
            case Some(fullPath) =>
                if (fileManager.exists(fullPath)) {
                    logger.warn("MKCOL method not allowed: resource already exists at ${requestPath}")
                    ctx.status(405).sendString("Method Not Allowed")
                    return
                }

                // 检查父目录是否存在
                let parentDir = Path(fullPath).parent.toString()
                if (parentDir.size > 0 && !fileManager.exists(parentDir)) {
                    logger.warn("MKCOL conflict: parent directory does not exist for ${requestPath}")
                    ctx.status(409).sendString("Conflict")
                    return
                }

                if (fileManager.createDirectory(fullPath)) {
                    logger.info("MKCOL created: ${requestPath}")
                    ctx.status(201).sendString("Created")
                } else {
                    logger.error("MKCOL failed: ${requestPath}")
                    ctx.status(500).sendString("Internal Server Error")
                }
            case None => 
                logger.warn("MKCOL forbidden (unsafe path): ${requestPath}")
                ctx.status(403).sendString("Forbidden")
        }
    }

    // COPY - 复制文件或目录
    private func handleCopy(ctx: Ctx): Unit {
        if (!config.enableCopy) {
            logger.warn("COPY forbidden: copy access denied for ${ctx.path}")
            ctx.status(403).sendString("Forbidden")
            return
        }

        let requestPath = ctx.path
        let destination = ctx.header("Destination") ?? ""

        if (destination.size == 0) {
            logger.warn("COPY bad request: missing Destination header")
            ctx.status(400).sendString("Bad Request")
            return
        }

        match (fileManager.getSafePath(requestPath)) {
            case Some(srcPath) =>
                if (!fileManager.exists(srcPath)) {
                    logger.warn("COPY not found: ${requestPath}")
                    ctx.status(404).sendString("Not Found")
                    return
                }

                // 解析目标路径
                let destPath = parseDestination(destination)
                match (fileManager.getSafePath(destPath)) {
                    case Some(dstPath) =>
                        // 检查源和目标是否相同
                        if (srcPath == dstPath) {
                            logger.warn("COPY forbidden: source and destination are the same")
                            ctx.status(403).sendString("Forbidden")
                            return
                        }

                        // 检查是否覆盖
                        let overwrite = ctx.header("Overwrite") ?? "T"
                        let destExists = fileManager.exists(dstPath)
                        
                        if (destExists && overwrite == "F") {
                            logger.warn("COPY precondition failed: destination exists and Overwrite=F")
                            ctx.status(412).sendString("Precondition Failed")
                            return
                        }

                        // 检查父目录是否存在
                        let parentDir = Path(dstPath).parent.toString()
                        if (parentDir.size > 0 && !fileManager.exists(parentDir)) {
                            logger.warn("COPY conflict: parent directory does not exist for destination")
                            ctx.status(409).sendString("Conflict")
                            return
                        }

                        let success = if (fileManager.isDirectory(srcPath)) {
                            fileManager.copyDirectory(srcPath, dstPath)
                        } else {
                            fileManager.copyFile(srcPath, dstPath)
                        }

                        if (success) {
                            if (destExists) {
                                logger.info("COPY overwritten: ${requestPath} -> ${destPath}")
                                ctx.status(204).noContent()
                            } else {
                                logger.info("COPY created: ${requestPath} -> ${destPath}")
                                ctx.status(201).sendString("Created")
                            }
                        } else {
                            logger.error("COPY failed: ${requestPath} -> ${destPath}")
                            ctx.status(507).sendString("Insufficient Storage")
                        }
                    case None => 
                        logger.warn("COPY forbidden (unsafe destination): ${destPath}")
                        ctx.status(403).sendString("Forbidden")
                }
            case None => 
                logger.warn("COPY forbidden (unsafe path): ${requestPath}")
                ctx.status(403).sendString("Forbidden")
        }
    }

    // MOVE - 移动/重命名文件或目录
    private func handleMove(ctx: Ctx): Unit {
        if (!config.enableMove) {
            logger.warn("MOVE forbidden: move access denied for ${ctx.path}")
            ctx.status(403).sendString("Forbidden")
            return
        }

        let requestPath = ctx.path
        let destination = ctx.header("Destination") ?? ""

        if (destination.size == 0) {
            logger.warn("MOVE bad request: missing Destination header")
            ctx.status(400).sendString("Bad Request")
            return
        }

        match (fileManager.getSafePath(requestPath)) {
            case Some(srcPath) =>
                if (!fileManager.exists(srcPath)) {
                    logger.warn("MOVE not found: ${requestPath}")
                    ctx.status(404).sendString("Not Found")
                    return
                }

                // 解析目标路径
                let destPath = parseDestination(destination)
                match (fileManager.getSafePath(destPath)) {
                    case Some(dstPath) =>
                        // 检查源和目标是否相同
                        if (srcPath == dstPath) {
                            logger.warn("MOVE forbidden: source and destination are the same")
                            ctx.status(403).sendString("Forbidden")
                            return
                        }

                        // 检查是否覆盖
                        let overwrite = ctx.header("Overwrite") ?? "T"
                        let destExists = fileManager.exists(dstPath)
                        
                        if (destExists && overwrite == "F") {
                            logger.warn("MOVE precondition failed: destination exists and Overwrite=F")
                            ctx.status(412).sendString("Precondition Failed")
                            return
                        }

                        // 检查父目录是否存在
                        let parentDir = Path(dstPath).parent.toString()
                        if (parentDir.size > 0 && !fileManager.exists(parentDir)) {
                            logger.warn("MOVE conflict: parent directory does not exist for destination")
                            ctx.status(409).sendString("Conflict")
                            return
                        }

                        // 删除已存在的目标
                        if (destExists) {
                            if (fileManager.isDirectory(dstPath)) {
                                fileManager.deleteDirectory(dstPath)
                            } else {
                                fileManager.deleteFile(dstPath)
                            }
                        }

                        if (fileManager.move(srcPath, dstPath)) {
                            if (destExists) {
                                logger.info("MOVE overwritten: ${requestPath} -> ${destPath}")
                                ctx.status(204).noContent()
                            } else {
                                logger.info("MOVE created: ${requestPath} -> ${destPath}")
                                ctx.status(201).sendString("Created")
                            }
                        } else {
                            logger.error("MOVE failed: ${requestPath} -> ${destPath}")
                            ctx.status(500).sendString("Internal Server Error")
                        }
                    case None => 
                        logger.warn("MOVE forbidden (unsafe destination): ${destPath}")
                        ctx.status(403).sendString("Forbidden")
                }
            case None => 
                logger.warn("MOVE forbidden (unsafe path): ${requestPath}")
                ctx.status(403).sendString("Forbidden")
        }
    }

    // HEAD - 获取文件信息
    private func handleHead(ctx: Ctx): Unit {
        if (!config.enableRead) {
            logger.warn("HEAD forbidden: read access denied for ${ctx.path}")
            ctx.status(403).sendString("Forbidden")
            return
        }

        let requestPath = ctx.path
        match (fileManager.getSafePath(requestPath)) {
            case Some(fullPath) =>
                if (!fileManager.exists(fullPath)) {
                    logger.warn("HEAD not found: ${requestPath}")
                    ctx.status(404).sendString("Not Found")
                    return
                }

                match (fileManager.getFileInfo(fullPath)) {
                    case Some(info) =>
                        logger.debug("HEAD success: ${requestPath}")
                        ctx.status(200)
                            .setHeader("Content-Type", fileManager.getMimeType(fullPath))
                            .setHeader("Content-Length", "${info.size}")
                            .setHeader("Last-Modified", info.modifiedTime.toString())
                            .setHeader("DAV", "1, 2")
                            .noContent()
                    case None => 
                        logger.error("HEAD failed: ${requestPath}")
                        ctx.status(500).sendString("Internal Server Error")
                }
            case None => 
                logger.warn("HEAD forbidden (unsafe path): ${requestPath}")
                ctx.status(403).sendString("Forbidden")
        }
    }

    // OPTIONS - 获取支持的方法
    private func handleOptions(ctx: Ctx): Unit {
        var allowMethods = "OPTIONS"

        if (config.enableRead) {
            allowMethods += ", GET, HEAD, PROPFIND"
        }
        if (config.enableWrite) {
            allowMethods += ", PUT, PROPPATCH"
        }
        if (config.enableDelete) {
            allowMethods += ", DELETE"
        }
        if (config.enableMkcol) {
            allowMethods += ", MKCOL"
        }
        if (config.enableCopy) {
            allowMethods += ", COPY"
        }
        if (config.enableMove) {
            allowMethods += ", MOVE"
        }
        
        // LOCK和UNLOCK总是支持
        allowMethods += ", LOCK, UNLOCK"

        logger.debug("OPTIONS: ${allowMethods}")
        ctx.status(200)
            .setHeader("Allow", allowMethods)
            .setHeader("DAV", "1, 2")
            .setHeader("MS-Author-Via", "DAV")
            .noContent()
    }

    // 未实现的方法
    private func handleNotImplemented(ctx: Ctx): Unit {
        logger.warn("Not implemented method: ${ctx.method} ${ctx.path}")
        ctx.status(501).sendString("Not Implemented")
    }

    // 发送目录列表(XML格式)
    private func sendDirectoryListing(ctx: Ctx, dirPath: String, requestPath: String): Unit {
        let entries = fileManager.listDirectory(dirPath)

        var xml = "<?xml version=\"1.0\" encoding=\"utf-8\"?>\n" +
            "<directory xmlns=\"urn:webdav\">\n" +
            "  <path>${escapeXml(requestPath)}</path>\n" +
            "  <entries>\n"

        // 添加父目录
        if (requestPath != "/") {
            xml += "    <entry>\n" +
                "      <name>..</name>\n" +
                "      <href>../</href>\n" +
                "      <type>directory</type>\n" +
                "    </entry>\n"
        }

        // 添加目录项
        for (entry in entries) {
            if (!config.showHidden && entry.name.startsWith(".")) {
                continue
            }

            let entryType = if (entry.isDirectory) { "directory" } else { "file" }
            let href = if (entry.isDirectory) { entry.name + "/" } else { entry.name }
            let size = if (entry.isDirectory) { "0" } else { "${entry.size}" }
            let modified = entry.modifiedTime.toString()

            xml += "    <entry>\n" +
                "      <name>${escapeXml(entry.name)}</name>\n" +
                "      <href>${escapeXml(href)}</href>\n" +
                "      <type>${entryType}</type>\n" +
                "      <size>${size}</size>\n" +
                "      <modified>${modified}</modified>\n" +
                "    </entry>\n"
        }

        xml += "  </entries>\n" +
            "</directory>"

        ctx.status(200)
            .setHeader("Content-Type", "application/xml; charset=utf-8")
            .sendString(xml)
    }

    // XML转义
    private func escapeXml(s: String): String {
        var result = ""
        for (ch in s.toRuneArray()) {
            match (ch) {
                case r'<' => result += "&lt;"
                case r'>' => result += "&gt;"
                case r'&' => result += "&amp;"
                case r'"' => result += "&quot;"
                case r'\'' => result += "&apos;"
                case _ => result += ch.toString()
            }
        }
        result
    }

    // 解析Depth头
    private func parseDepth(depth: String): Int64 {
        match (depth) {
            case "0" => 0
            case "1" => 1
            case "infinity" => 999
            case _ => 0
        }
    }

    // 解析Destination头
    private func parseDestination(destination: String): String {
        // 移除协议和主机部分，只保留路径
        // 例如: http://localhost:8080/path -> /path
        let runes = destination.toRuneArray()
        var i = 0

        // 跳过协议 http:// 或 https://
        if (destination.startsWith("http://")) {
            i = 7
        } else if (destination.startsWith("https://")) {
            i = 8
        }

        // 跳过主机部分
        while (i < runes.size && runes[i] != r'/') {
            i += 1
        }

        // 返回路径部分
        if (i < runes.size) {
            destination[i..]
        } else {
            "/"
        }
    }

    // PROPPATCH - 修改属性
    private func handlePropPatch(ctx: Ctx): Unit {
        if (!config.enableWrite) {
            logger.warn("PROPPATCH forbidden: write access denied for ${ctx.path}")
            ctx.status(403).sendString("Forbidden")
            return
        }

        let requestPath = ctx.path
        match (fileManager.getSafePath(requestPath)) {
            case Some(fullPath) =>
                if (!fileManager.exists(fullPath)) {
                    logger.warn("PROPPATCH not found: ${requestPath}")
                    ctx.status(404).sendString("Not Found")
                    return
                }

                // 构建多状态响应
                // 注意：当前实现不支持自定义属性，返回成功但实际不修改
                let responseXml = "<?xml version=\"1.0\" encoding=\"utf-8\"?>\n" +
                    "<D:multistatus xmlns:D=\"DAV:\">\n" +
                    "  <D:response>\n" +
                    "    <D:href>${requestPath}</D:href>\n" +
                    "    <D:propstat>\n" +
                    "      <D:prop/>\n" +
                    "      <D:status>HTTP/1.1 200 OK</D:status>\n" +
                    "    </D:propstat>\n" +
                    "  </D:response>\n" +
                    "</D:multistatus>"

                logger.debug("PROPPATCH success: ${requestPath}")
                ctx.status(207)
                    .setHeader("Content-Type", "application/xml; charset=utf-8")
                    .setHeader("DAV", "1, 2")
                    .sendString(responseXml)
            case None => 
                logger.warn("PROPPATCH forbidden (unsafe path): ${requestPath}")
                ctx.status(403).sendString("Forbidden")
        }
    }

    // LOCK - 锁定资源
    private func handleLock(ctx: Ctx): Unit {
        let requestPath = ctx.path
        match (fileManager.getSafePath(requestPath)) {
            case Some(fullPath) =>
                let resourceExists = fileManager.exists(fullPath)
                
                // 生成锁令牌
                let lockToken = "urn:uuid:${DateTime.now().toString().hashCode()}"
                
                // 构建锁响应
                let responseXml = "<?xml version=\"1.0\" encoding=\"utf-8\"?>\n" +
                    "<D:prop xmlns:D=\"DAV:\">\n" +
                    "  <D:lockdiscovery>\n" +
                    "    <D:activelock>\n" +
                    "      <D:locktype><D:write/></D:locktype>\n" +
                    "      <D:lockscope><D:exclusive/></D:lockscope>\n" +
                    "      <D:depth>infinity</D:depth>\n" +
                    "      <D:owner>WebDAV Client</D:owner>\n" +
                    "      <D:timeout>Second-3600</D:timeout>\n" +
                    "      <D:locktoken><D:href>${lockToken}</D:href></D:locktoken>\n" +
                    "      <D:lockroot><D:href>${requestPath}</D:href></D:lockroot>\n" +
                    "    </D:activelock>\n" +
                    "  </D:lockdiscovery>\n" +
                    "</D:prop>"

                if (resourceExists) {
                    logger.info("LOCK on existing resource: ${requestPath}")
                    ctx.status(200)
                        .setHeader("Content-Type", "application/xml; charset=utf-8")
                        .setHeader("Lock-Token", "<${lockToken}>")
                        .setHeader("DAV", "1, 2")
                        .sendString(responseXml)
                } else {
                    // 在未映射URL上创建锁（同时创建空资源）
                    logger.info("LOCK created new resource: ${requestPath}")
                    ctx.status(201)
                        .setHeader("Content-Type", "application/xml; charset=utf-8")
                        .setHeader("Lock-Token", "<${lockToken}>")
                        .setHeader("DAV", "1, 2")
                        .sendString(responseXml)
                }
            case None => 
                logger.warn("LOCK forbidden (unsafe path): ${requestPath}")
                ctx.status(403).sendString("Forbidden")
        }
    }

    // UNLOCK - 解锁资源
    private func handleUnlock(ctx: Ctx): Unit {
        let requestPath = ctx.path
        
        // 检查Lock-Token头
        let lockToken = ctx.header("Lock-Token")
        if ((lockToken?.size ?? 0) == 0) {
            logger.warn("UNLOCK bad request: missing Lock-Token header")
            ctx.status(400).sendString("Bad Request")
            return
        }

        match (fileManager.getSafePath(requestPath)) {
            case Some(fullPath) =>
                // 简单实现：总是返回成功
                logger.info("UNLOCK success: ${requestPath}")
                ctx.status(204).noContent()
            case None => 
                logger.warn("UNLOCK forbidden (unsafe path): ${requestPath}")
                ctx.status(403).sendString("Forbidden")
        }
    }
}

package selineWebdav

import std.fs.{Path, File, Directory, exists, remove, rename, FileInfo, OpenMode}
import std.collection.ArrayList
import std.time.DateTime
import std.env.getWorkingDirectory
import std.unicode.*

// 文件信息结构
public struct WebDavFileInfo {
    public let name: String
    public let path: String
    public let isDirectory: Bool
    public let size: Int64
    public let modifiedTime: DateTime
    public let createdTime: DateTime

    public init(name: String, path: String, isDirectory: Bool, size: Int64, modifiedTime: DateTime,
        createdTime: DateTime) {
        this.name = name
        this.path = path
        this.isDirectory = isDirectory
        this.size = size
        this.modifiedTime = modifiedTime
        this.createdTime = createdTime
    }
}

// 文件管理器 - 提供文件系统操作
public class FileManager {
    private let rootPath: Path

    public init(rootPath: String) {
        // 将相对路径转换为绝对路径
        let path = Path(rootPath)
        this.rootPath = if (path.isAbsolute()) {
            path
        } else {
            // 获取当前工作目录并拼接
            getWorkingDirectory().join(rootPath)
        }
    }

    public func getRootPath(): String {
        rootPath.toString()
    }

    // 获取安全的文件路径(防止路径遍历攻击)
    public func getSafePath(requestPath: String): ?String {
        // 解码URL路径
        let decodedPath = urlDecode(requestPath)

        // 移除开头的斜杠
        let cleanPath = if (decodedPath.startsWith("/")) {
            if (decodedPath.size > 1) {
                decodedPath[1..]
            } else {
                ""
            }
        } else {
            decodedPath
        }

        // 构建完整路径
        let fullPath = if (cleanPath.size > 0) {
            rootPath.join(cleanPath)
        } else {
            rootPath
        }

        // 检查是否在根目录内
        let fullPathStr = fullPath.toString()
        let rootPathStr = rootPath.toString()
        if (!fullPathStr.startsWith(rootPathStr)) {
            return None
        }

        Some(fullPathStr)
    }

    // 检查路径是否存在
    public func exists(path: String): Bool {
        exists(Path(path))
    }

    // 检查是否为目录
    public func isDirectory(path: String): Bool {
        try {
            let fsFileInfo = FileInfo(Path(path))
            fsFileInfo.isDirectory()
        } catch (_: Exception) {
            false
        }
    }

    // 获取文件信息
    public func getFileInfo(path: String): ?WebDavFileInfo {
        let pathObj = Path(path)
        if (!exists(pathObj)) {
            return None
        }

        try {
            let fsFileInfo = FileInfo(pathObj)
            let isDir = fsFileInfo.isDirectory()
            let name = pathObj.fileName
            let size = if (isDir) {
                0
            } else {
                fsFileInfo.size
            }

            // 获取文件时间信息
            let (modifiedTime, createdTime) = getFileTimes(path)

            // 计算相对于根目录的路径
            let relativePath = getRelativePath(path)

            Some(
                WebDavFileInfo(
                    name,
                    relativePath,
                    isDir,
                    size,
                    modifiedTime,
                    createdTime
                )
            )
        } catch (_: Exception) {
            None
        }
    }

    // 获取相对于根目录的路径
    private func getRelativePath(fullPath: String): String {
        let rootPathStr = rootPath.toString()
        // 规范化路径：统一使用反斜杠比较
        let normalizedFull = fullPath.replace("/", "\\")
        let normalizedRoot = rootPathStr.replace("/", "\\")

        if (normalizedFull.startsWith(normalizedRoot)) {
            let rel = normalizedFull[normalizedRoot.size..]
            // 移除开头的路径分隔符
            if (rel.startsWith("\\")) {
                // 将反斜杠转换为正斜杠用于URL
                rel[1..].replace("\\", "/")
            } else {
                rel.replace("\\", "/")
            }
        } else {
            // 如果不是以根路径开头，返回文件名
            Path(fullPath).fileName
        }
    }

    // 获取文件时间信息
    private func getFileTimes(_path: String): (DateTime, DateTime) {
        // 仓颉标准库可能不支持直接获取文件时间，返回当前时间作为默认值
        let now = DateTime.now()
        (now, now)
    }

    // 列出目录内容
    public func listDirectory(dirPath: String): ArrayList<WebDavFileInfo> {
        let result = ArrayList<WebDavFileInfo>()

        if (!isDirectory(dirPath)) {
            return result
        }

        try {
            let pathObj = Path(dirPath)
            let entries = Directory.readFrom(pathObj)
            for (entry in entries) {
                let fullPath = entry.path
                match (getFileInfo(fullPath.toString())) {
                    case Some(info) => result.add(info)
                    case None => ()
                }
            }
        } catch (_: Exception) {
            // 忽略错误，返回已收集的结果
        }

        result
    }

    // 创建目录
    public func createDirectory(path: String): Bool {
        try {
            Directory.create(Path(path), recursive: true)
            true
        } catch (_: Exception) {
            false
        }
    }

    // 删除文件
    public func deleteFile(path: String): Bool {
        try {
            remove(Path(path))
            true
        } catch (_: Exception) {
            false
        }
    }

    // 删除目录
    public func deleteDirectory(path: String): Bool {
        try {
            remove(Path(path), recursive: true)
            true
        } catch (_: Exception) {
            false
        }
    }

    // 读取文件内容
    public func readFile(path: String): ?Array<Byte> {
        try {
            let data = File.readFrom(Path(path))
            Some(data)
        } catch (_: Exception) {
            None
        }
    }

    // 写入文件内容
    public func writeFile(path: String, data: Array<Byte>): Bool {
        try {
            // 确保父目录存在
            let pathObj = Path(path)
            let parentDir = pathObj.parent
            if (parentDir.toString().size > 0 && !exists(parentDir)) {
                Directory.create(parentDir, recursive: true)
            }

            let file = File(pathObj, OpenMode.Write)
            file.write(data)
            file.close()
            true
        } catch (_: Exception) {
            false
        }
    }

    // 复制文件
    public func copyFile(srcPath: String, dstPath: String): Bool {
        try {
            // 确保目标父目录存在
            let dstPathObj = Path(dstPath)
            let parentDir = dstPathObj.parent
            if (parentDir.toString().size > 0 && !exists(parentDir)) {
                Directory.create(parentDir, recursive: true)
            }

            // 读取源文件
            match (readFile(srcPath)) {
                case Some(data) => writeFile(dstPath, data)
                case None => false
            }
        } catch (_: Exception) {
            false
        }
    }

    // 复制目录
    public func copyDirectory(srcPath: String, dstPath: String): Bool {
        try {
            let dstPathObj = Path(dstPath)

            // 创建目标目录
            if (!exists(dstPathObj)) {
                Directory.create(dstPathObj, recursive: true)
            }

            // 复制目录内容
            let entries = listDirectory(srcPath)
            for (entry in entries) {
                let srcFullPath = Path(entry.path)
                let dstFullPath = dstPathObj.join(entry.name)

                if (entry.isDirectory) {
                    if (!copyDirectory(srcFullPath.toString(), dstFullPath.toString())) {
                        return false
                    }
                } else {
                    if (!copyFile(srcFullPath.toString(), dstFullPath.toString())) {
                        return false
                    }
                }
            }
            true
        } catch (_: Exception) {
            false
        }
    }

    // 移动/重命名文件或目录
    public func move(srcPath: String, dstPath: String): Bool {
        try {
            // 确保目标父目录存在
            let dstPathObj = Path(dstPath)
            let parentDir = dstPathObj.parent
            if (parentDir.toString().size > 0 && !exists(parentDir)) {
                Directory.create(parentDir, recursive: true)
            }

            // 使用rename进行移动
            rename(Path(srcPath), to: dstPathObj)
            true
        } catch (_: Exception) {
            false
        }
    }

    // 获取MIME类型
    public func getMimeType(path: String): String {
        let pathObj = Path(path)
        let ext = pathObj.extensionName
        match (ext.toLower()) {
            case "html" | "htm" => "text/html; charset=utf-8"
            case "css" => "text/css; charset=utf-8"
            case "js" => "application/javascript; charset=utf-8"
            case "json" => "application/json; charset=utf-8"
            case "xml" => "application/xml; charset=utf-8"
            case "txt" => "text/plain; charset=utf-8"
            case "pdf" => "application/pdf"
            case "zip" => "application/zip"
            case "jpg" | "jpeg" => "image/jpeg"
            case "png" => "image/png"
            case "gif" => "image/gif"
            case "svg" => "image/svg+xml"
            case "mp4" => "video/mp4"
            case "mp3" => "audio/mpeg"
            case _ => "application/octet-stream"
        }
    }

    // URL解码
    private func urlDecode(s: String): String {
        let runes = s.toRuneArray()
        var bytes = ArrayList<UInt8>()
        var i = 0

        while (i < runes.size) {
            if (runes[i] == r'%' && i + 2 < runes.size) {
                // 尝试解析十六进制编码
                let hex1 = charToHex(runes[i + 1])
                let hex2 = charToHex(runes[i + 2])
                match (hex1) {
                    case Some(h1) => match (hex2) {
                        case Some(h2) =>
                            let byteVal = UInt8((h1 << 4) | h2)
                            bytes.add(byteVal)
                            i += 3
                        case None =>
                            // 将当前字符作为普通字节添加
                            bytes.add(UInt8(UInt32(runes[i])))
                            i += 1
                    }
                    case None =>
                        bytes.add(UInt8(UInt32(runes[i])))
                        i += 1
                }
            } else {
                // 将字符转换为UTF-8字节
                let ch = runes[i]
                let chValue = UInt32(ch)
                if (chValue < 0x80) {
                    bytes.add(UInt8(chValue))
                } else if (chValue < 0x800) {
                    bytes.add(UInt8(0xC0 | (chValue >> 6)))
                    bytes.add(UInt8(0x80 | (chValue & 0x3F)))
                } else if (chValue < 0x10000) {
                    bytes.add(UInt8(0xE0 | (chValue >> 12)))
                    bytes.add(UInt8(0x80 | ((chValue >> 6) & 0x3F)))
                    bytes.add(UInt8(0x80 | (chValue & 0x3F)))
                } else {
                    bytes.add(UInt8(0xF0 | (chValue >> 18)))
                    bytes.add(UInt8(0x80 | ((chValue >> 12) & 0x3F)))
                    bytes.add(UInt8(0x80 | ((chValue >> 6) & 0x3F)))
                    bytes.add(UInt8(0x80 | (chValue & 0x3F)))
                }
                i += 1
            }
        }

        // 将字节数组转换为字符串
        String.fromUtf8(bytes.toArray())
    }

    // 字符转十六进制值
    private func charToHex(ch: Rune): ?Int64 {
        if (ch >= r'0' && ch <= r'9') {
            Some(Int64(UInt32(ch)) - Int64(UInt32(r'0')))
        } else if (ch >= r'a' && ch <= r'f') {
            Some(Int64(UInt32(ch)) - Int64(UInt32(r'a')) + 10)
        } else if (ch >= r'A' && ch <= r'F') {
            Some(Int64(UInt32(ch)) - Int64(UInt32(r'A')) + 10)
        } else {
            None
        }
    }
}

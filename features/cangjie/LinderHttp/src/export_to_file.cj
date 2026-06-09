package linderHttp



/**
 * 将字符串内容导出到指定路径的文件中。
 *
 * 当目标路径已存在同名文件时，根据冲突解决策略处理：
 * - `Harmony`（默认）：自动生成新文件名（格式：`原文件名(序号).扩展名`），序号从1开始递增直到不冲突。
 * - `OverWrite`：直接覆盖原文件。
 *
 * @param content     要写入的字符串内容，不可为空。
 * @param filePath    目标文件路径（包含文件名和扩展名），不可为空。
 * @param conflictMethod 文件冲突解决策略，默认为`ConflictMethod.Harmony`。
 */
public func exportToFile(content!: String, filePath!: Path, conflictMethod!: ConflictMethod = ConflictMethod.Harmony): Unit {
    var targetPath = filePath.normalize()
    var targetFileName = filePath.fileName

    match (conflictMethod) {
        case ConflictMethod.Harmony =>
            let dir: Array<FileInfo> = Directory.readFrom(filePath.parent)
            let files = dir.map({value => value.name})
            if (files.contains(targetFileName)) {
                let fileInPath = Path(targetFileName)
                var counter = 1
                let baseName = fileInPath.fileNameWithoutExtension
                let extension = fileInPath.extensionName
                while (files.contains(targetFileName)) {
                    targetFileName = "${baseName}(${counter}).${extension}"
                    counter++
                }
                targetPath = filePath.parent.join(Path(targetFileName))
            }
        case ConflictMethod.OverWrite => targetPath = targetPath
    }
    let file = File(targetPath, OpenMode.Write)
    file.write(content.toArray())
    file.close()
}

/**
 * 将输入流的内容导出到指定路径的文件中。
 *
 * 当目标路径已存在同名文件时，根据冲突解决策略处理：
 * - `Harmony`（默认）：自动生成新文件名（格式：`原文件名(序号).扩展名`）。
 * - `OverWrite`：直接覆盖原文件。
 *
 * @param content     输入流对象，不可为空（读取后流位置将移动到末尾）。
 * @param filePath    目标文件路径（包含文件名和扩展名），不可为空。
 * @param conflictMethod 文件冲突解决策略，默认为`ConflictMethod.Harmony`。
 * @param totalSize   总大小（用于进度跟踪）
 */
public func exportToFile(content!: InputStream, filePath!: Path,
    conflictMethod!: ConflictMethod = ConflictMethod.Harmony): Unit {
    var targetPath = filePath.normalize()
    var targetFileName = filePath.fileName

    match (conflictMethod) {
        case ConflictMethod.Harmony =>
            let dir: Array<FileInfo> = Directory.readFrom(filePath.parent)
            let files = dir.map({value => value.name})
            if (files.contains(targetFileName)) {
                let fileInPath = Path(targetFileName)
                var counter = 1
                let baseName = fileInPath.fileNameWithoutExtension
                let extension = fileInPath.extensionName
                while (files.contains(targetFileName)) {
                    targetFileName = "${baseName}(${counter}).${extension}"
                    counter++
                }

                targetPath = filePath.parent.join(Path(targetFileName))
            }

        case ConflictMethod.OverWrite => targetPath = targetPath
    }

    let file = File(targetPath, OpenMode.Write)
    let buffer: Array<Byte> = Array<Byte>(4096, repeat: 0)
    var readSize = content.read(buffer)
    var hasReadSize = readSize
    do {
        file.write(buffer[0..readSize])
        readSize = content.read(buffer)
        hasReadSize += readSize
    } while (readSize > 0)

    file.close()
}

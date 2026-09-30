package zlibraryAPI4CJ.dataModel

public struct GetDownloadInfoRes <: Serializable<GetDownloadInfoRes> {
    public var success: UInt8 = 0
    public var file: ?DownloadInfo = DownloadInfo()
    public var errorInfo: ?String = ''

    public func serialize(): DataModel {
        return DataModelStruct().add(field<UInt8>("success", success)).add(field<Option<DownloadInfo>>("file", file))
    }
    public static func deserialize(dm: DataModel): GetDownloadInfoRes {
        var dms = match (dm) {
            case data: DataModelStruct => data
            case _ => throw Exception("this data is not DataModelStruct")
        }
        var result = GetDownloadInfoRes()
        result.success = UInt8.deserialize(dms.get("success"))
        result.file = Option<DownloadInfo>.deserialize(dms.get("file"))
        result.errorInfo = Option<String>.deserialize(dms.get("error"))
        return result
    }
}

public struct DownloadInfo <: Serializable<DownloadInfo> {
    public var downloadLink: ?String = ''
    public var description: ?String = ''
    public var author: ?String = ''
    public var extension: ?String = ''
    public var allowDownload: Bool = true

    public prop fileName: String {
        get() {
            URL.parse(downloadLink.getOrThrow()).queryForm.get("filename") ?? ""
        }
    }

    /**
     * 下载这本书。
     *
     * @param path 保存目录
     * @param overwrite 目标文件已存在时是否覆盖；默认 false 会自动改名（`file(1).ext`），
     *                  等价于旧 API 的 ConflictMethod.Harmony；传 true 等价于 OverWrite。
     * 下载本身（分片/续传）不在 HTTP 库职责内，这里只做「整包流式落盘」。
     */
    public func download(path!: Path, overwrite!: Bool = false) {
        let savePath = path.join(fileName)
        LinderHttp.get(downloadLink.getOrThrow().replace("%", ""),
            timeouts: Timeouts(read: Duration.Max, write: Duration.Max))
            .saveTo(savePath, overwrite: overwrite)
    }

    public func serialize(): DataModel {
        return DataModelStruct()
            .add(field<?String>("downloadLink", downloadLink))
            .add(field<?String>("description", description))
            .add(field<?String>("author", author))
            .add(field<?String>("extension", extension))
            .add(field<Bool>("allowDownload", allowDownload))
    }
    public static func deserialize(dm: DataModel): DownloadInfo {
        var dms = match (dm) {
            case data: DataModelStruct => data
            case _ => throw Exception("this data is not DataModelStruct")
        }
        var result = DownloadInfo()
        result.downloadLink = Option<String>.deserialize(dms.get("downloadLink"))
        result.description = Option<String>.deserialize(dms.get("description"))
        result.author = Option<String>.deserialize(dms.get("author"))
        result.extension = Option<String>.deserialize(dms.get("extension"))
        result.allowDownload = Bool.deserialize(dms.get("allowDownload"))
        return result
    }
}

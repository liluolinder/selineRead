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
    public var downloadLink: String = ''
    public var description: String = ''
    public var author: String = ''
    public var extension: String = ''
    public var allowDownload: Bool = true

    public prop fileName: String {
        get() {
            URL.parse(downloadLink).queryForm.get("filename") ?? ""
        }
    }

    public func download(path!: Path, conflictMethod!: ConflictMethod = ConflictMethod.Harmony) {
        let savePath = path.join(fileName)
        let response = LinderHttpClient(
            url: RequestUrl.from(downloadLink.replace("%", "")),
            writeTimeout: Duration.Max,
            readTimeout: Duration.Max,
        ).send()
        response.status |> println
        response.getBodyFile(filePath: savePath, conflictMethod: conflictMethod)
    }

    public func serialize(): DataModel {
        return DataModelStruct()
            .add(field<String>("downloadLink", downloadLink))
            .add(field<String>("description", description))
            .add(field<String>("author", author))
            .add(field<String>("extension", extension))
            .add(field<Bool>("allowDownload", allowDownload))
    }
    public static func deserialize(dm: DataModel): DownloadInfo {
        var dms = match (dm) {
            case data: DataModelStruct => data
            case _ => throw Exception("this data is not DataModelStruct")
        }
        var result = DownloadInfo()
        result.downloadLink = String.deserialize(dms.get("downloadLink"))
        result.description = String.deserialize(dms.get("description"))
        result.author = String.deserialize(dms.get("author"))
        result.extension = String.deserialize(dms.get("extension"))
        result.allowDownload = Bool.deserialize(dms.get("allowDownload"))
        return result
    }
}

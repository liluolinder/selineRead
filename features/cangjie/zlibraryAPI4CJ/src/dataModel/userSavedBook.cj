package zlibraryAPI4CJ.dataModel

public struct GetBookWithInfoAndPaginationRes <: Serializable<GetBookWithInfoAndPaginationRes> {
    public var success: UInt8 = 0
    public var books: ?Array<BookInfo> = []
    public var pagination: ?Pagination = Pagination()
    public var errorInfo: ?String = ''

    public func serialize(): DataModel {
        return DataModelStruct()
            .add(field<UInt8>("success", success))
            .add(field<?Array<BookInfo>>("books", books))
            .add(field<?Pagination>("pagination", pagination))
            .add(field<?String>("errorInfo", errorInfo))
    }
    public static func deserialize(dm: DataModel): GetBookWithInfoAndPaginationRes {
        var dms = match (dm) {
            case data: DataModelStruct => data
            case _ => throw Exception("this data is not DataModelStruct")
        }
        var result = GetBookWithInfoAndPaginationRes()
        result.success = UInt8.deserialize(dms.get("success"))
        result.books = Option<Array<BookInfo>>.deserialize(dms.get("books"))
        result.pagination = Option<Pagination>.deserialize(dms.get("pagination"))
        result.errorInfo = Option<String>.deserialize(dms.get('error'))
        return result
    }
}

public struct Pagination <: Serializable<Pagination> {
    public var limit: UInt64 = 0
    public var current: UInt64 = 0
    public var totalItems: UInt64 = 0
    public var totalPages: UInt64 = 0

    public func serialize(): DataModel {
        return DataModelStruct()
            .add(field<UInt64>("limit", limit))
            .add(field<UInt64>("current", current))
            .add(field<UInt64>("total_items", totalItems))
            .add(field<UInt64>("total_pages", totalPages))
    }
    public static func deserialize(dm: DataModel): Pagination {
        var dms = match (dm) {
            case data: DataModelStruct => data
            case _ => throw Exception("this data is not DataModelStruct")
        }
        var result = Pagination()
        result.limit = UInt64.deserialize(dms.get("limit"))
        result.current = UInt64.deserialize(dms.get("current"))
        result.totalItems = UInt64.deserialize(dms.get("total_items"))
        result.totalPages = UInt64.deserialize(dms.get("total_pages"))
        return result
    }
}

package linderHttp

/**
 * HTTP请求方法枚举
 * 
 * 包含所有标准HTTP方法以及自定义方法支持。
 */
public enum RequestMethod <: ToString {
    | GET
    | POST
    | HEAD
    | PUT
    | PATCH
    | DELETE
    | COPY
    | OPTIONS
    | LINK
    | UNLINK
    | PURGE
    | LOCK
    | UNLOCK
    | PROPFIND
    | VIEW
    | CUSTOM(String)

    public func toString(): String {
        match (this) {
            case GET => "GET"
            case POST => "POST"
            case HEAD => "HEAD"
            case PUT => "PUT"
            case PATCH => "PATCH"
            case DELETE => "DELETE"
            case COPY => "COPY"
            case OPTIONS => "OPTIONS"
            case LINK => "LINK"
            case UNLINK => "UNLINK"
            case PURGE => "PURGE"
            case LOCK => "LOCK"
            case UNLOCK => "UNLOCK"
            case PROPFIND => "PROPFIND"
            case VIEW => "VIEW"
            case CUSTOM(v) => v
        }
    }
}

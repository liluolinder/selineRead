package mirrors

import java.lang.*

@JavaMirror["android.os.Build$VERSION"]
public open class Build_VERSION {
    public static let BASE_OS: ?JString

    public static let CODENAME: ?JString

    public static let INCREMENTAL: ?JString

    public static let MEDIA_PERFORMANCE_CLASS: Int32

    public static let PREVIEW_SDK_INT: Int32

    public static let RELEASE: ?JString

    public static let RELEASE_OR_CODENAME: ?JString

    public static let RELEASE_OR_PREVIEW_DISPLAY: ?JString

    public static let SDK: ?JString

    public static let SDK_INT: Int32

    public static let SECURITY_PATCH: ?JString

    public init()
}
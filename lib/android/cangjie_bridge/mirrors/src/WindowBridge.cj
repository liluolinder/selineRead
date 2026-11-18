package mirrors

import java.lang.*

@JavaMirror["seline.book.prefs.WindowBridge"]
public class WindowBridge {
    public static func attach(activity: ?Activity): Unit

    public static func applyFullscreen(): Unit

    public static func topInsetDp(): Float32

    public static func bottomInsetDp(): Float32

    public static func density(): Float32

    public static func widthPx(): Int32

    public static func heightPx(): Int32
}
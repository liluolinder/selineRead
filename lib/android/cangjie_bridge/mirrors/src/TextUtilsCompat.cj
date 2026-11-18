package mirrors

import java.lang.*

@JavaMirror["androidx.core.text.TextUtilsCompat"]
public class TextUtilsCompat {
    public static func htmlEncode(s: ?JString): ?JString

    public static func getLayoutDirectionFromLocale(locale: ?Locale): Int32
}
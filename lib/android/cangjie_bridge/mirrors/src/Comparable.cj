package mirrors

import java.lang.*

@JavaMirror["java.lang.Comparable"]
public interface Comparable {
    func compareTo(arg0: ?JObject): Int32
}
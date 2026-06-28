package ignite.tests

import ignite.*

@Test
public class JsonEscapeRegressionTestSuite {
    @TestCase
    public func testEscapeJsonTextEscapesAllAsciiControls(): Unit {
        let raw = String.fromUtf8([
            UInt8(0),
            UInt8(1),
            UInt8(8),
            UInt8(12),
            UInt8(10),
            UInt8(13),
            UInt8(9),
            UInt8(34),
            UInt8(92)
        ])
        let escaped = escapeJsonText(raw)
        @Assert(escaped, "\\u0000\\u0001\\b\\f\\n\\r\\t\\\"\\\\")
    }
}

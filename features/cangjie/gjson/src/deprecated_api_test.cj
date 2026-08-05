package gjson

import std.unittest.*
import std.unittest.testmacro.*

// 旧版大写 API 兼容性测试
// 这些 API 已标记 @Deprecated，仍可正常调用（调用处会产生编译期 warning）
@Test
class DeprecatedApiTest {
    @TestCase
    func testLegacyArray() {
        let res = get("[1,2,3]", "@this")
        let legacy = res.Array()
        @Assert(legacy.size, 3)
        @Assert(legacy[0].raw, "1")
    }

    @TestCase
    func testLegacyForEach() {
        let res = get("{\"a\":1,\"b\":2}", "@this")
        let boxed = Box<Int64>(0)
        res.ForEach({ key, _ =>
            boxed.value++
            true
        })
        @Assert(boxed.value, 2)
    }

    @TestCase
    func testLegacyValid() {
        @Assert(Valid("{\"a\":1}"), true)
        @Assert(Valid("{bad}"), false)
        @Assert(ValidBytes("{\"a\":}".toArray()), false)
    }

    @TestCase
    func testLegacyTime() {
        let res = parse("\"2024-01-01T12:00:00Z\"")
        let t = res.Time()
        @Assert(t.toString(), "2024-01-01T12:00:00Z")
    }

    @TestCase
    func testLegacyModifier() {
        @Assert(ModifierExists("pretty"), true)
        AddModifier("test_legacy", { json: String, arg: String => "\"ok\"" })
        @Assert(ModifierExists("test_legacy"), true)
    }
}

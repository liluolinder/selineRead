package ignite.tests

import ignite.*

@Test
public class KModePanicHookConfigTestSuite {
    @TestCase
    public func testConfigAcceptsKModePanicHandler(): Unit {
        let hook: KModePanicHandler = { _, _ => true }
        let config = Config(
            kmode: true,
            kmodePanicHandler: Some(hook)
        )

        var hasHook = false
        if (let Some(_) <- config.kmodePanicHandler) {
            hasHook = true
        }

        @Assert(config.kmode, true)
        @Assert(hasHook, true)
    }

    @TestCase
    public func testConfigDefaultKModePanicHandlerIsNone(): Unit {
        let config = Config()
        var hasHook = false
        if (let Some(_) <- config.kmodePanicHandler) {
            hasHook = true
        }
        @Assert(hasHook, false)
    }
}

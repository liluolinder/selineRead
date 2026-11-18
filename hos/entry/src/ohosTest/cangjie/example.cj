package ohos_app_cangjie_entry_test

import std.unittest.*
import std.unittest.TestPackage
import std.unittest.common.*
import std.unittest.testmacro.*
import ohos.base.AppLog
import ohos.base.BusinessException
import ohos.ui_test.Driver
import ohos.ui_test.On

@Test
public class TestExample00 {
    prop driver: Driver {
        get() {
            Driver.create()
        }
    }

    @BeforeEach
    func beforeEach() {
        driver.delayMs(1000)
    }

    @TestCase
    func testClickButton() {
        AppLog.info("keels ui test click button start.")
        try {
            let button = driver.findComponent(On().id("keelsButton"))
            button.click()
            AppLog.info("keels ui test click button finish.")
        } catch (e: BusinessException) {
            AppLog.info("keels ui test click button failed.")
            @Expect(false)
        }
    }

    @TestCase
    func testCaptureScreen() {
        AppLog.info("keels ui test capture screen start.")
        try {
            captureGolden("screen", driver)
            AppLog.info("keels ui test capture screen finish.")
        } catch (e: BusinessException) {
            AppLog.info("keels ui test capture screen failed.")
            @Expect(false)
        }
    }
}

package ohos_app_cangjie_entry_test

import std.unittest.*
import std.unittest.TestPackage
import std.unittest.common.*
import std.unittest.testmacro.*
import ohos.base.AppLog
import ohos.base.BusinessException
import ohos.ui_test.Driver
import ohos.ui_test.On
import ohos.ui_test.DisplayRotation

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
    func testSearchFlow() {
        AppLog.info("keels ui test search flow start.")
        try {
            let input = driver.findComponent(On().id("searchInput"))
            input.inputText("Rust")
            driver.delayMs(800)
            driver.findComponent(On().id("keelsButton")).click()
            driver.delayMs(8000)
            captureGolden("search_mode", driver)
            AppLog.info("keels ui test search flow finish.")
        } catch (e: BusinessException) {
            AppLog.info("keels ui test search flow failed: ${e.message}")
            @Expect(false)
        }
    }

    @TestCase
    func testBackReturnsToRecommendations() {
        AppLog.info("keels ui test back start.")
        try {
            let input = driver.findComponent(On().id("searchInput"))
            input.inputText("Rust")
            driver.findComponent(On().id("keelsButton")).click()
            driver.delayMs(3000)
            driver.pressBack()
            driver.delayMs(1500)
            captureGolden("back_home", driver)
            AppLog.info("keels ui test back finish.")
        } catch (e: BusinessException) {
            AppLog.info("keels ui test back failed: ${e.message}")
            @Expect(false)
        }
    }

    @TestCase
    func testWideLayout() {
        AppLog.info("keels ui test wide layout start.")
        try {
            driver.setDisplayRotation(DisplayRotation.ROTATION_90)
            driver.delayMs(3000)
            captureGolden("wide_layout", driver)
            driver.setDisplayRotation(DisplayRotation.ROTATION_0)
            driver.delayMs(1000)
            AppLog.info("keels ui test wide layout finish.")
        } catch (e: BusinessException) {
            AppLog.info("keels ui test wide layout failed: ${e.message}")
            @Expect(false)
        }
    }
}

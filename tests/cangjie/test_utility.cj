package ohos_app_cangjie_entry_test

// CJMP Tools manages this test dependency file.
// Do not modify it unless you need to customize the test framework itself.

import ohos.base.AppLog
import std.env.getHomeDirectory
import std.fs.*
import std.sync.*
import std.time.*
import std.unittest.*

let TEST_REPORT_DIR = "ut_report"
let TEST_XML_REPORT_DIR = "xml"
let TEST_XML_REPORT_TMP_DIR = "xml.tmp"

func scheduleCjmpUiTestSuite(): Unit {
    spawn {
        AppLog.info("keels test runner waiting ui ready.")
        sleep(1500 * Duration.millisecond)
        runKeelsUiTestSuiteForCurrentPlatform()
    }
}

@When[keels_test_platform == "android"]
func runKeelsUiTestSuiteForCurrentPlatform(): Unit {
    exclusiveScope {
        runKeelsUiTestSuite()
    }
}

@When[keels_test_platform != "android"]
func runKeelsUiTestSuiteForCurrentPlatform(): Unit {
    runKeelsUiTestSuite()
}

func runKeelsUiTestSuite(): Unit {
    AppLog.info("keels test runner started.")
    prepareTestReportDirectories()
    let configuration = Configuration()
    if (KEELS_TEST_FILTER.size > 0) {
        configuration.setByName("filter", KEELS_TEST_FILTER)
    }
    runKeelsSelectedTestSuites(configuration)
    publishTestXmlReport()
    AppLog.info("keels test runner finished.")
}

func prepareTestReportDirectories(): Unit {
    let resultRoot = getTestResultRoot()
    if (!exists(resultRoot)) {
        Directory.create(resultRoot, recursive: true)
    }
    let xmlReportPath = getTestXmlReportPath()
    let xmlReportTmpPath = getTestXmlReportTmpPath()
    if (exists(xmlReportPath)) {
        remove(xmlReportPath, recursive: true)
    }
    if (exists(xmlReportTmpPath)) {
        remove(xmlReportTmpPath, recursive: true)
    }
    Directory.create(xmlReportTmpPath, recursive: true)
    resetGoldenReportDirectory()
}

func publishTestXmlReport(): Unit {
    rename(getTestXmlReportTmpPath(), to: getTestXmlReportPath(), overwrite: true)
}

@When[keels_test_platform == "android"]
func getTestResultRoot(): Path {
    return Path("/data/data/seline.book.read").join(TEST_REPORT_DIR)
}

@When[keels_test_platform != "android"]
func getTestResultRoot(): Path {
    AppLog.info("getHomeDirectory: ${getHomeDirectory()}")
    return getHomeDirectory().join("Documents").join(TEST_REPORT_DIR)
}

func getTestXmlReportPath(): Path {
    return getTestResultRoot().join(TEST_XML_REPORT_DIR)
}

func getTestXmlReportTmpPath(): Path {
    return getTestResultRoot().join(TEST_XML_REPORT_TMP_DIR)
}

func getTestXmlReportCaseTmpPath(index: Int64): Path {
    let path = getTestXmlReportTmpPath().join("case${index}")
    if (!exists(path)) {
        Directory.create(path, recursive: true)
    }
    return path
}

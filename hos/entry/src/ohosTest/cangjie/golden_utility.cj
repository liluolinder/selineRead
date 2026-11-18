package ohos_app_cangjie_entry_test

import ohos.ui_test.Driver
import std.fs.*

let GOLDEN_REPORT_DIR = "golden"

public func captureGolden(name: String, driver: Driver): Unit {
    let path = getGoldenPath(name)
    ensureGoldenNameIsUnique(name)
    if (!driver.screenCap(path.toString())) {
        throw Exception("Failed to capture golden image: ${name}")
    }
}

func resetGoldenReportDirectory(): Unit {
    let path = getGoldenDirectory()
    if (exists(path)) {
        remove(path, recursive: true)
    }
    Directory.create(path, recursive: true)
}

func getGoldenPath(name: String): Path {
    validateGoldenName(name)
    let directory = getGoldenDirectory()
    if (!exists(directory)) {
        Directory.create(directory, recursive: true)
    }
    return directory.join("${name}.bmp")
}

@When[keels_test_platform != "hos"]
func getGoldenDirectory(): Path {
    return getTestResultRoot().join(GOLDEN_REPORT_DIR)
}

@When[keels_test_platform == "hos"]
func getGoldenDirectory(): Path {
    return Path("/data/storage/el1/base").join("ut_report").join(GOLDEN_REPORT_DIR)
}

func validateGoldenName(name: String): Unit {
    if (name.isEmpty() || name.contains("/") || name.contains("\\") || name.contains("..")) {
        throw IllegalArgumentException("Golden name must be a non-empty file name without path separators.")
    }
}

func ensureGoldenNameIsUnique(name: String): Unit {
    if (exists(getGoldenPath(name))) {
        throw IllegalArgumentException("Golden name must be unique within one test run: ${name}")
    }
}

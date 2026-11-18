# Golden Images

Golden images are PNG reference images used by UI tests that call
`captureGolden`.

## Capture Only

Use `--capture-only` to save the current screenshots without comparing them
and without updating reference images:

```text
keels test --capture-only -d <device-id>
```

By default, screenshots are written under the test results directory:

```text
<result-dir>/screenshots/
  login_button.png
  home_page.png
```

`--capture-only` ignores `--update-goldens` and `--golden-dir` when they are
also provided. In `report.json`, this mode sets `golden.mode` to `capture` and
uses `goldenCaptureSummary` and `goldenCaptureResults`.

## Update Goldens

Use `--update-goldens` to write the current captures as PNG reference images:

```text
keels test --update-goldens -d <device-id>
```

By default, golden images are written by platform:

```text
tests/goldens/
  android/
    login_button.png
  ohos/
    login_button.png
  ios/
    login_button.png
```

Use `--golden-dir` to write the PNG reference images directly into a custom
directory:

```text
keels test --update-goldens --golden-dir <path> -d <device-id>

<path>/
  login_button.png
  home_page.png
```

Update mode does not compare images. In `report.json`, this mode sets
`golden.mode` to `update` and uses `goldenUpdateSummary` and
`goldenUpdateResults`.

## Verify

Run tests without `--capture-only` or `--update-goldens` to compare current
captures against saved reference images:

```text
keels test -d <device-id>
```

By default, verify mode reads reference images from:

```text
tests/goldens/android/
tests/goldens/hos/
tests/goldens/ios/
```

Use `--golden-dir` to read reference images from a custom directory:

```text
keels test --golden-dir <path> -d <device-id>

<path>/
  login_button.png
  home_page.png
```

Verify mode compares every captured image with its reference image. A pixel is
different when the maximum per-channel difference exceeds 16. The golden check
fails when the different pixel ratio exceeds 0.1%. Screen captures compare
RGBA.

When comparison fails, a `diff.png` is generated in the test results directory. In
`report.json`, verify mode sets `golden.mode` to `verify`; golden comparison
details are merged into the failed test cases.

## Capturing Images

Capture the whole screen:

```cangjie
captureGolden("home_page", driver)
```

- Golden name must be a non-empty file name without path separators or `..`.
- Golden names must be unique within one test run.
- Full-screen captures compare RGBA values.

## Result Artifacts

Verify and update modes keep per-capture artifacts under the run results directory:

```text
<result-dir>/golden-results/
  login_button/
    actual/
      login_button.png
    expected/
      login_button.png
    diff/
      diff.png
```

`expected/` and `diff/` are verify-mode artifacts. `diff.png` is generated only
when image comparison fails. `--capture-only` writes flat PNG files under the
run's `screenshots/` directory instead.

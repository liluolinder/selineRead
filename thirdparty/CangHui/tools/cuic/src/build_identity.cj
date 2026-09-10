package cuic

// The installer replaces these values only in its disposable source copy. A direct repository
// build stays explicitly unembedded instead of pretending to identify a particular commit.
let CUIC_BUILD_CHANNEL = "development"
let CUIC_BUILD_REVISION = "unembedded"

func renderCuicVersion(): String {
    "cuic ${VERSION} (${CUIC_BUILD_CHANNEL}@${CUIC_BUILD_REVISION})"
}

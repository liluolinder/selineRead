package cuic

@Test
func doctorOptionsKeepCompatibilityAndMachineModes(): Unit {
    let options = parseDoctorOptions([
        "cuic", "doctor", "ipad", "--project", "demo", "--json", "--verbose"
    ], 2)
    @Expect(options.target, "ios")
    @Expect(options.project, "demo")
    @Expect(options.json)
    @Expect(options.verbose)
}
@Test
func doctorStatusOnlyCountsRequestedTargetBlockers(): Unit {
    let global = DoctorGroup("global", "Global", "all", [
        doctorReady("global.ready", "Ready", "ok", "")
    ])
    let macos = DoctorGroup("macos", "macOS", "macos", [
        doctorReady("macos.ready", "Ready", "ok", "")
    ])
    let android = DoctorGroup("android", "Android", "android", [
        doctorUnsupported("android.unsupported", "Unsupported", "missing", "none", "")
    ])
    let result = DoctorResult("macos", "arm64", "macos", [global, macos, android])
    @Expect(result.requestedBlockers(), Int64(0))
    @Expect(result.exitCode(), Int64(0))
    @Expect(doctorStatusName(result.requestedStatus()), "ready")
}

@Test
func doctorMacosRuntimeProviderAcceptsAnExistingStagingLibrary(): Unit {
    let framework = tryResolveFrameworkRoot(currentDirectory())
    let check = doctorMacosRuntimeProvider("macos", "macos.sdl3", "SDL3 provider",
        joinPath(framework, "sdl/.sdl3/libSDL3.dylib"), "sdl3")
    @Expect(doctorStatusName(check.status), "ready")
}

@Test
func doctorJsonKeepsStableSchemaAndActionShape(): Unit {
    let group = DoctorGroup("toolchain", "Toolchain", "all", [
        doctorDegraded("toolchain.sample", "Sample", "needs work", DoctorActionKind.Manual, "repair it", "/tmp/tool")
    ])
    let result = DoctorResult("macos", "arm64", "macos", [group])
    let json = renderDoctorJson(result, false)
    @Expect(json.contains("\"schema\":\"canghui.doctor.v0\""))
    @Expect(json.contains("\"cliVersion\":\"0.6.0\""))
    @Expect(json.contains("\"cliProvenance\":{\"channel\":\"development\",\"revision\":\"unembedded\"}"))
    @Expect(json.contains("\"status\":\"degraded\""))
    @Expect(json.contains("\"kind\":\"manual\""))
    @Expect(json.contains("\"evidence\":\"\""))
}

@Test
func doctorVerboseEvidenceRedactsPathsCredentialsAndIdentity(): Unit {
    @Expect(doctorSafeEvidence("cjc 1.1.3"), "cjc 1.1.3")
    @Expect(doctorSafeEvidence("/Users/alice/sdk/bin/cjc | 1.1.3"), "redacted")
    @Expect(doctorSafeEvidence("C:\\Users\\alice\\sdk\\cjc.exe | 1.1.3"), "redacted")
    @Expect(doctorSafeEvidence("https://alice:password@example.invalid/sdk"), "redacted")
    @Expect(doctorSafeEvidence("Authorization: Bearer exposed"), "redacted")

    let group = DoctorGroup("safe", "Safe", "all", [
        doctorReady("safe.path", "Path", "ok", "/home/alice/private/tool")
    ])
    let json = renderDoctorJson(DoctorResult("macos", "arm64", "macos", [group]), true)
    @Expect(json.contains("\"evidence\":\"redacted\""))
    @Expect(!json.contains("alice"))
}

@Test
func doctorIosReportsBootstrapAndNativeSurfaceAdapter(): Unit {
    let framework = tryResolveFrameworkRoot(currentDirectory())
    let checks = doctorIosFrameworkChecks(framework)
    var readyBootstrapAssets: Int64 = 0
    var readySurfaceAssets: Int64 = 0
    var rendererReady = false
    for (check in checks) {
        if (startsWithText(check.id, "ios.bootstrap-") &&
            doctorStatusName(check.status) == "ready") {
            readyBootstrapAssets += 1
        }
        if (startsWithText(check.id, "ios.surface-") &&
            doctorStatusName(check.status) == "ready") {
            readySurfaceAssets += 1
        }
        if (check.id == "ios.renderer" && doctorStatusName(check.status) == "ready") {
            rendererReady = true
        }
    }
    @Expect(readyBootstrapAssets, Int64(3))
    @Expect(readySurfaceAssets, Int64(3))
    @Expect(rendererReady)
}

@Test
func doctorAndroidReportsBootstrapWithoutClaimingRuntimeCompletion(): Unit {
    let framework = tryResolveFrameworkRoot(currentDirectory())
    let checks = doctorAndroidGroup(framework).checks
    var readySurfaceAssets: Int64 = 0
    var backendDegraded = false
    for (check in checks) {
        if (startsWithText(check.id, "android.surface-") &&
            doctorStatusName(check.status) == "ready") {
            readySurfaceAssets += 1
        }
        if (check.id == "android.backend" && doctorStatusName(check.status) == "degraded") {
            backendDegraded = true
        }
    }
    @Expect(readySurfaceAssets, Int64(5))
    @Expect(backendDegraded)
}

@Test
func doctorReportsApplicationShellContractAndSchema(): Unit {
    let framework = tryResolveFrameworkRoot(currentDirectory())
    let checks = doctorApplicationShellGroup(framework).checks
    var contractReady = false
    var schemaReady = false
    var planSchemaReady = false
    var artifactSchemaReady = false
    for (check in checks) {
        if (check.id == "application-shell.contract" && doctorStatusName(check.status) == "ready") {
            contractReady = true
        }
        if (check.id == "application-shell.schema" && doctorStatusName(check.status) == "ready") {
            schemaReady = true
        }
        if (check.id == "application-shell.plan-schema" && doctorStatusName(check.status) == "ready") {
            planSchemaReady = true
        }
        if (check.id == "application-shell.artifact-schema" && doctorStatusName(check.status) == "ready") {
            artifactSchemaReady = true
        }
    }
    @Expect(contractReady)
    @Expect(schemaReady)
    @Expect(planSchemaReady)
    @Expect(artifactSchemaReady)
}

@Test
func doctorReportsMobileHostContractWithoutOverclaimingPlatformPackages(): Unit {
    let framework = tryResolveFrameworkRoot(currentDirectory())
    let checks = doctorMobileApplicationHostGroup(framework).checks
    var contractReady = false
    var schemaReady = false
    var signingPreparationReady = false
    var signingPreparationSchemaReady = false
    var externalSignerReceiptReady = false
    var externalSignerReceiptSchemaReady = false
    var signedPackageEvidenceReady = false
    var signedPackageEvidenceSchemaReady = false
    var installationAttemptReady = false
    var installationAttemptSchemaReady = false
    var replayContractReady = false
    var replaySchemaReady = false
    var kmodeAdapterReady = false
    var consumerFixtureReady = false
    var docsReady = false
    var iosReady = false
    var iosInputTreeReady = false
    var androidDegraded = false
    var harmonyDegraded = false
    for (check in checks) {
        if (check.id == "mobile-host.contract" && doctorStatusName(check.status) == "ready") {
            contractReady = true
        }
        if (check.id == "mobile-host.schema" && doctorStatusName(check.status) == "ready") {
            schemaReady = true
        }
        if (check.id == "mobile-host.signing-preparation" && doctorStatusName(check.status) == "ready") {
            signingPreparationReady = true
        }
        if (check.id == "mobile-host.signing-preparation-schema" && doctorStatusName(check.status) == "ready") {
            signingPreparationSchemaReady = true
        }
        if (check.id == "mobile-host.external-signer-receipt" && doctorStatusName(check.status) == "ready") {
            externalSignerReceiptReady = true
        }
        if (check.id == "mobile-host.external-signer-receipt-schema" && doctorStatusName(check.status) == "ready") {
            externalSignerReceiptSchemaReady = true
        }
        if (check.id == "mobile-host.signed-package-evidence" && doctorStatusName(check.status) == "ready") {
            signedPackageEvidenceReady = true
        }
        if (check.id == "mobile-host.signed-package-evidence-schema" && doctorStatusName(check.status) == "ready") {
            signedPackageEvidenceSchemaReady = true
        }
        if (check.id == "mobile-host.installation-attempt" && doctorStatusName(check.status) == "ready") {
            installationAttemptReady = true
        }
        if (check.id == "mobile-host.installation-attempt-schema" && doctorStatusName(check.status) == "ready") {
            installationAttemptSchemaReady = true
        }
        if (check.id == "mobile-host.replay-contract" && doctorStatusName(check.status) == "ready") {
            replayContractReady = true
        }
        if (check.id == "mobile-host.replay-schema" && doctorStatusName(check.status) == "ready") {
            replaySchemaReady = true
        }
        if (check.id == "mobile-host.kmode-adapter" && doctorStatusName(check.status) == "ready") {
            kmodeAdapterReady = true
        }
        if (check.id == "mobile-host.consumer-fixture" && doctorStatusName(check.status) == "ready") {
            consumerFixtureReady = true
        }
        if (check.id == "mobile-host.docs" && doctorStatusName(check.status) == "ready") {
            docsReady = true
        }
        if (check.id == "mobile-host.ios-provider" && doctorStatusName(check.status) == "ready") {
            iosReady = true
        }
        if (check.id == "mobile-host.ios-input-tree" && doctorStatusName(check.status) == "ready") {
            iosInputTreeReady = true
        }
        if (check.id == "mobile-host.android-provider" && doctorStatusName(check.status) == "degraded") {
            androidDegraded = true
        }
        if (check.id == "mobile-host.harmony-provider" && doctorStatusName(check.status) == "degraded") {
            harmonyDegraded = true
        }
    }
    @Expect(contractReady)
    @Expect(schemaReady)
    @Expect(signingPreparationReady)
    @Expect(signingPreparationSchemaReady)
    @Expect(externalSignerReceiptReady)
    @Expect(externalSignerReceiptSchemaReady)
    @Expect(signedPackageEvidenceReady)
    @Expect(signedPackageEvidenceSchemaReady)
    @Expect(installationAttemptReady)
    @Expect(installationAttemptSchemaReady)
    @Expect(replayContractReady)
    @Expect(replaySchemaReady)
    @Expect(kmodeAdapterReady)
    @Expect(consumerFixtureReady)
    @Expect(docsReady)
    @Expect(iosReady)
    @Expect(iosInputTreeReady)
    @Expect(androidDegraded)
    @Expect(harmonyDegraded)
}

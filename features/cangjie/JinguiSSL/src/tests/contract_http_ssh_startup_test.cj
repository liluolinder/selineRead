package jinguissl.tests

import jinguissl.contract.*

@Test
public class ContractHttpSshStartupTestSuite {
    @TestCase
    public func testContractHttpSshStartupReadinessFacade(): Unit {
        let report = contractHttpSshStartupReadiness(aesBackendHint: "shim")
        @Assert(report.capability.stableDomains.size > 0, true)
        @Assert(report.httpTlsReady, true)
        @Assert(report.sshReady, true)
        @Assert(report.x509Ready, true)
        @Assert(
            report.overallReady,
            report.randomAvailable && report.httpTlsReady && report.sshReady && report.x509Ready
        )
        @Assert(report.productionAccelerationReady, false)
        @Assert(report.aes.effectiveBackendHint, "shim")
        @Assert(report.aesCurrentReleasePlan.currentReleaseSeries, "0.6")
        @Assert(report.aesCurrentReleasePlan.primaryBackend, "armv8-ce")
        @Assert(report.aesCurrentReleasePlan.usingPrimaryBackend, false)
        @Assert(
            contractHttpSshStartupContainsString(
                report.warnings,
                "AES accelerated backend is not ready; software or shim path may be used"
            ),
            true
        )
        @Assert(
            contractHttpSshStartupContainsString(
                report.warnings,
                "selected AES backend is not the current 0.6 primary backend"
            ),
            true
        )

        let outcome = contractTryHttpSshStartupReadiness(
            requestedAesEngine: ContractAesEngineKind.Hardware,
            aesBackendHint: "none"
        )
        @Assert(outcome.ok, false)
        match (outcome.code) {
            case Some(value) =>
                @Assert(value.toString(), "UNSUPPORTED")
            case None =>
                @Fail("HTTP/SSH startup readiness outcome should carry contract code")
        }
    }

    @TestCase
    public func testContractRequireHttpSshStartupReadinessFacade(): Unit {
        let relaxed = contractRequireHttpSshStartupReadiness(
            policy: ContractHttpSshStartupPolicy(
                requireRandom: true,
                requireHttpTls: true,
                requireSsh: false,
                requireX509: true,
                requireAcceleration: false
            ),
            aesBackendHint: "shim"
        )
        @Assert(relaxed.httpTlsReady, true)
        @Assert(relaxed.x509Ready, true)

        let accelerationRequired = contractTryRequireHttpSshStartupReadiness(
            policy: ContractHttpSshStartupPolicy(
                requireRandom: true,
                requireHttpTls: true,
                requireSsh: true,
                requireX509: true,
                requireAcceleration: true
            ),
            aesBackendHint: "shim"
        )
        @Assert(accelerationRequired.ok, false)
        match (accelerationRequired.code) {
            case Some(value) =>
                @Assert(value.toString(), "UNSUPPORTED")
            case None =>
                @Fail("HTTP/SSH startup policy failure should carry contract code")
        }
        @Assert(
            accelerationRequired.message.contains("accelerated AES backend is required but not ready"),
            true
        )

        let directBridgeRequired = contractTryRequireHttpSshStartupReadiness(
            policy: ContractHttpSshStartupPolicy(
                requireRandom: true,
                requireHttpTls: true,
                requireSsh: false,
                requireX509: true,
                requireDirectStdxTlsServerConfigBridge: true
            ),
            aesBackendHint: "shim"
        )
        @Assert(directBridgeRequired.ok, false)
        match (directBridgeRequired.code) {
            case Some(value) =>
                @Assert(value.toString(), "UNSUPPORTED")
            case None =>
                @Fail("direct bridge policy failure should carry contract code")
        }
        @Assert(
            directBridgeRequired.message.contains(
                "direct stdx.net.tls.TlsServerConfig bridge is required but unavailable"
            ),
            true
        )

        let releasePrimaryRequired = contractTryRequireHttpSshStartupReadiness(
            policy: ContractHttpSshStartupPolicy(
                requireRandom: true,
                requireHttpTls: true,
                requireSsh: true,
                requireX509: true,
                requireCurrentReleasePrimaryBackend: true
            ),
            aesBackendHint: "shim"
        )
        @Assert(releasePrimaryRequired.ok, false)
        let releaseReport = contractHttpSshStartupReadiness(aesBackendHint: "shim")
        match (releasePrimaryRequired.code) {
            case Some(value) =>
                @Assert(value.toString(), "UNSUPPORTED")
            case None =>
                @Fail("release primary backend policy failure should carry contract code")
        }
        if (!releaseReport.aesCurrentReleasePlan.primaryBackendAvailable) {
            @Assert(
                releasePrimaryRequired.message.contains(
                    "current release primary AES backend is unavailable: ${releaseReport.aesCurrentReleasePlan.primaryBackend}"
                ),
                true
            )
        } else {
            @Assert(
                releasePrimaryRequired.message.contains(
                    "current release requires primary AES backend ${releaseReport.aesCurrentReleasePlan.primaryBackend}, but startup resolved ${releaseReport.aes.selectedEngine.backend}"
                ),
                true
            )
        }
    }

    @TestCase
    public func testContractHttpSshStartupProfilesFacade(): Unit {
        let templates = contractListHttpSshStartupProfiles()
        @Assert(templates.size >= 6, true)

        let production = contractDescribeHttpSshStartupProfile(
            ContractHttpSshStartupProfile.ProductionAccelerated
        )
        @Assert(production.label, "production-accelerated")
        @Assert(production.defaultAesEngine.toString(), "HARDWARE")
        @Assert(production.policy.requireAcceleration, true)
        @Assert(production.policy.requireCurrentReleasePrimaryBackend, true)
        @Assert(production.defaultAesBackendHint, "armv8-ce")

        let sshClient = contractDescribeHttpSshStartupProfile(
            ContractHttpSshStartupProfile.SshClientLibrary
        )
        @Assert(sshClient.policy.requireHttpTls, false)
        @Assert(sshClient.policy.requireSsh, true)
        @Assert(sshClient.policy.requireX509, false)

        let httpClient = contractRequireHttpSshStartupProfile(
            ContractHttpSshStartupProfile.HttpClientLibrary,
            aesBackendHint: "shim"
        )
        @Assert(httpClient.httpTlsReady, true)
        @Assert(httpClient.x509Ready, true)

        let productionFailed = contractTryRequireHttpSshStartupProfile(
            ContractHttpSshStartupProfile.ProductionAccelerated,
            aesBackendHint: "shim"
        )
        @Assert(productionFailed.ok, false)
        match (productionFailed.code) {
            case Some(value) =>
                @Assert(value.toString(), "UNSUPPORTED")
            case None =>
                @Fail("startup profile failure should carry contract code")
        }
    }
}

private func contractHttpSshStartupContainsString(values: Array<String>, expected: String): Bool {
    for (value in values) {
        if (value == expected) {
            return true
        }
    }
    false
}

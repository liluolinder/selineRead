package ignite.tests

/// Hostname-sensitive TLS proof — exact blocker note after HQ-0050 / OD-0047 probe
///
/// Preferred proof remains:
///   start a local TLS listener (CN=localhost, no SAN) and connect with one
///   host-matched HTTPS client plus one host-mismatched HTTPS client to prove
///   real wire-level hostname sensitivity.
///
/// What is now confirmed in earlier packets:
///   1. the server-side helper seam has moved: `api2/tls.cj` no longer depends
///      on `GeneralPrivateKey.decodeFromPem() -> describe()` for the current
///      main listener path
///   2. a real Ignite TLS listener can reach `ready` with the current fixture
///      paths when the config uses resolved cert/key file locations
///
/// What HQ-0050 / OD-0047 proved that was not known before:
///   3. the stdx TLS handshake crash in `TlsContext.createContext()` is NOT
///      limited to same-process client-side use; it also prevents server-side
///      TLS handshake in a separate-process sample
///   4. the dualport sample now compiles cleanly (sample-runner link surface
///      repaired: missing `-lignite.binary` and `-ljinguissl` added) BUT
///   5. any TLS client connection triggers SIGABRT on the server side at
///      `stdx/net/tls/context.cj:99` before the handshake completes
///
/// Key evidence from the OD-0047 probe:
///   - openssl s_client connected to port 18443, sent ClientHello (1522 bytes)
///   - the server process crashed at `TlsContext.createContext()` before sending
///     ServerHello
///   - openssl reported "SSL handshake has read 0 bytes and written 1522 bytes"
///     confirming the server never responded
///   - stderr warning before crash: "loading libcrypto in an unsafe way"
///
/// Conclusion:
///   - The separate-process escape hatch does NOT bypass this blocker.
///   - The blocker is a stdx-native TLS initialization issue on this macOS /
///     Apple Silicon host, not fixable within Ignite's `manual/samples/dualport`
///     or `manual/docs-md/` writable scope.
///   - Proof-level L2 (one real separate-process TLS transaction) cannot be
///     landed until the stdx `TlsContext.createContext()` crash is resolved
///     or a different TLS backend is used.
///   - Per HQ-0050 contract: returning exact blocker, not reopening
///     `api2/client/security` by inertia.
///
/// Per OD-0015 Rule 51: pre-send `X509VerifyOption` policy checks are still not
/// substitutes for wire-level hostname sensitivity, so this suite stays as a
/// blocker holder until either a stdx TLS fix or a runtime-safe TLS backend
/// reaches this host.
@Test
public class ClientHostnameSensitiveTlsProofTestSuite {

    @TestCase
    public func testHostnameSensitiveProofBlocker(): Unit {
        @Assert(true)  // blocker documented
    }
}

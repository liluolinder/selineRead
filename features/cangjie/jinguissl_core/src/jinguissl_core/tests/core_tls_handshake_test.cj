package jinguissl_core.tests

import jinguissl_core.crypto.error.CryptoException
import jinguissl_core.crypto.tls.*

@Test
public class TlsHandshakeTestSuite {
    @TestCase
    public func testHandshakeFrameRoundTrip(): Unit {
        let body = "abcd".toArray()
        let frame = TlsHandshakeFrame(Finished, body)
        let encoded = tlsEncodeHandshakeFrame(frame)
        let decoded = tlsDecodeHandshakeFrame(encoded)

        @Assert(decoded.msgType.toString(), "FINISHED")
        @Assert(decoded.body, body)

        let keyUpdateFrame = TlsHandshakeFrame(KeyUpdate, [UInt8(0x00)])
        let keyUpdateEncoded = tlsEncodeHandshakeFrame(keyUpdateFrame)
        let keyUpdateDecoded = tlsDecodeHandshakeFrame(keyUpdateEncoded)
        @Assert(keyUpdateDecoded.msgType.toString(), "KEY_UPDATE")
        @Assert(keyUpdateDecoded.body, [UInt8(0x00)])

        let ticketFrame = TlsHandshakeFrame(NewSessionTicket, [UInt8(0x01), UInt8(0x02)])
        let ticketEncoded = tlsEncodeHandshakeFrame(ticketFrame)
        let ticketDecoded = tlsDecodeHandshakeFrame(ticketEncoded)
        @Assert(ticketDecoded.msgType.toString(), "NEW_SESSION_TICKET")
        @Assert(ticketDecoded.body, [UInt8(0x01), UInt8(0x02)])

        let certificateRequestFrame = TlsHandshakeFrame(CertificateRequest, [UInt8(0x00), UInt8(0x00), UInt8(0x00)])
        let certificateRequestEncoded = tlsEncodeHandshakeFrame(certificateRequestFrame)
        let certificateRequestDecoded = tlsDecodeHandshakeFrame(certificateRequestEncoded)
        @Assert(certificateRequestDecoded.msgType.toString(), "CERTIFICATE_REQUEST")
        @Assert(certificateRequestDecoded.body, [UInt8(0x00), UInt8(0x00), UInt8(0x00)])
    }

    @TestCase
    public func testClientHelloRoundTripAndDeterministicEncoding(): Unit {
        let random = incrementalBytes(32, start: 0)
        let clientHello = TlsClientHello(
            random,
            [0x1301, 0x1302, 0xC02F],
            sessionId: [UInt8(0xaa), UInt8(0xbb)],
            compressionMethods: [UInt8(0x00)],
            extensions: [
                TlsExtension(0x0000, [UInt8(0x00), UInt8(0x02), UInt8(0x7a), UInt8(0x68)]),
                TlsExtension(0x0010, [UInt8(0x00), UInt8(0x02), UInt8(0x68), UInt8(0x32)])
            ],
            legacyVersion: TLS1_2
        )

        let encoded = tlsEncodeClientHelloHandshake(clientHello)
        let decoded = tlsDecodeClientHelloHandshake(encoded)

        @Assert(decoded.legacyVersion.toString(), "TLS1.2")
        @Assert(decoded.random, random)
        @Assert(decoded.sessionId, [UInt8(0xaa), UInt8(0xbb)])
        @Assert(decoded.cipherSuites, [0x1301, 0x1302, 0xC02F])
        @Assert(decoded.compressionMethods, [UInt8(0x00)])
        @Assert(decoded.extensions.size, 2)
        @Assert(decoded.extensions[0].extType, 0)
        @Assert(decoded.extensions[1].extType, 16)

        let minimal = TlsClientHello(
            random,
            [0x1301],
            compressionMethods: [UInt8(0x00)],
            extensions: [],
            legacyVersion: TLS1_2
        )
        let minimalEncoded = tlsEncodeClientHelloHandshake(minimal)
        @Assert(
            bytesToHex(minimalEncoded),
            "0100002b0303000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f000002130101000000"
        )
    }

    @TestCase
    public func testServerHelloRoundTripAndDeterministicEncoding(): Unit {
        let random = incrementalBytes(32, start: 0x20)
        let serverHello = TlsServerHello(
            random,
            0x1301,
            sessionId: [UInt8(0x01), UInt8(0x02), UInt8(0x03)],
            compressionMethod: UInt8(0x00),
            extensions: [
                TlsExtension(0x002b, [UInt8(0x02), UInt8(0x03), UInt8(0x04)])
            ],
            legacyVersion: TLS1_3
        )

        let encoded = tlsEncodeServerHelloHandshake(serverHello)
        let decoded = tlsDecodeServerHelloHandshake(encoded)

        @Assert(decoded.legacyVersion.toString(), "TLS1.3")
        @Assert(decoded.random, random)
        @Assert(decoded.sessionId, [UInt8(0x01), UInt8(0x02), UInt8(0x03)])
        @Assert(decoded.cipherSuite, 0x1301)
        @Assert(UInt8(decoded.compressionMethod), UInt8(0x00))
        @Assert(decoded.extensions.size, 1)
        @Assert(decoded.extensions[0].extType, 0x002b)

        let minimal = TlsServerHello(
            random,
            0x1301,
            compressionMethod: UInt8(0x00),
            extensions: [],
            legacyVersion: TLS1_2
        )
        let minimalEncoded = tlsEncodeServerHelloHandshake(minimal)
        @Assert(
            bytesToHex(minimalEncoded),
            "020000280303202122232425262728292a2b2c2d2e2f303132333435363738393a3b3c3d3e3f001301000000"
        )

        let encryptedExtensions = TlsEncryptedExtensionsMessage(
            extensions: [
                TlsExtension(TLS_EXT_ALPN, [UInt8(0x00), UInt8(0x03), UInt8(0x02), UInt8(0x68), UInt8(0x32)]),
                TlsExtension(TLS_EXT_SERVER_NAME, [])
            ]
        )
        let encodedEe = tlsEncodeEncryptedExtensionsHandshake(encryptedExtensions)
        let decodedEe = tlsDecodeEncryptedExtensionsHandshake(encodedEe)
        @Assert(decodedEe.extensions.size, 2)
        @Assert(decodedEe.extensions[0].extType, TLS_EXT_ALPN)
        @Assert(decodedEe.extensions[1].extType, TLS_EXT_SERVER_NAME)
    }

    @TestCase
    public func testKeyExchangeRoundTrip(): Unit {
        let payload = [UInt8(0xde), UInt8(0xad), UInt8(0xbe), UInt8(0xef)]
        let message = TlsKeyExchangeMessage(payload)

        let serverEncoded = tlsEncodeServerKeyExchangeHandshake(message)
        let serverDecoded = tlsDecodeServerKeyExchangeHandshake(serverEncoded)
        @Assert(serverDecoded.exchangeData, payload)

        let clientEncoded = tlsEncodeClientKeyExchangeHandshake(message)
        let clientDecoded = tlsDecodeClientKeyExchangeHandshake(clientEncoded)
        @Assert(clientDecoded.exchangeData, payload)
    }

    @TestCase
    public func testCertificateAndFinishedRoundTrip(): Unit {
        let cert1 = [UInt8(0x30), UInt8(0x82), UInt8(0x01), UInt8(0x0a)]
        let cert2 = [UInt8(0x30), UInt8(0x82), UInt8(0x02), UInt8(0x0b), UInt8(0x00)]

        let tls12Encoded = tlsEncodeCertificateHandshakeTls12([cert1, cert2])
        let tls12Decoded = tlsDecodeCertificateHandshakeTls12(tls12Encoded)
        @Assert(tls12Decoded.size, 2)
        @Assert(tls12Decoded[0], cert1)
        @Assert(tls12Decoded[1], cert2)

        let tls13Message = Tls13CertificateMessage(
            requestContext: [UInt8(0xaa), UInt8(0xbb)],
            entries: [
                TlsCertificateEntry(cert1, extensions: [TlsExtension(0x0010, [UInt8(0x01), UInt8(0x02)])]),
                TlsCertificateEntry(cert2)
            ]
        )
        let tls13Encoded = tlsEncodeCertificateHandshakeTls13(tls13Message)
        let tls13Decoded = tlsDecodeCertificateHandshakeTls13(tls13Encoded)
        @Assert(tls13Decoded.requestContext, [UInt8(0xaa), UInt8(0xbb)])
        @Assert(tls13Decoded.entries.size, 2)
        @Assert(tls13Decoded.entries[0].certData, cert1)
        @Assert(tls13Decoded.entries[0].extensions.size, 1)
        @Assert(tls13Decoded.entries[0].extensions[0].extType, 0x0010)
        @Assert(tls13Decoded.entries[1].certData, cert2)

        let certVerify = TlsCertificateVerifyMessage(0x0403, [UInt8(0x30), UInt8(0x01), UInt8(0x00)])
        let certVerifyEncoded = tlsEncodeCertificateVerifyHandshake(certVerify)
        let certVerifyDecoded = tlsDecodeCertificateVerifyHandshake(certVerifyEncoded)
        @Assert(certVerifyDecoded.signatureScheme, 0x0403)
        @Assert(certVerifyDecoded.signature, [UInt8(0x30), UInt8(0x01), UInt8(0x00)])

        let certificateRequest = Tls13CertificateRequestMessage(
            requestContext: [UInt8(0x01), UInt8(0x02)],
            extensions: [TlsExtension(0x000d, [UInt8(0x00), UInt8(0x02), UInt8(0x04), UInt8(0x03)])]
        )
        let certificateRequestEncoded = tlsEncodeCertificateRequestHandshakeTls13(certificateRequest)
        let certificateRequestDecoded = tlsDecodeCertificateRequestHandshakeTls13(certificateRequestEncoded)
        @Assert(certificateRequestDecoded.requestContext, [UInt8(0x01), UInt8(0x02)])
        @Assert(certificateRequestDecoded.extensions.size, 1)
        @Assert(certificateRequestDecoded.extensions[0].extType, 0x000d)

        let finished = [UInt8(0x01), UInt8(0x02), UInt8(0x03), UInt8(0x04)]
        let finishedEncoded = tlsEncodeFinishedHandshake(finished)
        let finishedDecoded = tlsDecodeFinishedHandshake(finishedEncoded)
        @Assert(finishedDecoded, finished)
    }

    @TestCase
    public func testHandshakeDecodeRejectUnsupportedTypeAndVersion(): Unit {
        let unsupportedType = [UInt8(0xff), UInt8(0x00), UInt8(0x00), UInt8(0x00)]
        try {
            _ = tlsDecodeHandshakeFrame(unsupportedType)
            @Fail("unsupported handshake type should be rejected as unsupported")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "UNSUPPORTED")
        }

        let supportedClientHello = tlsEncodeClientHelloHandshake(
            TlsClientHello(
                incrementalBytes(32, start: 0),
                [0x1301],
                compressionMethods: [UInt8(0x00)],
                extensions: [],
                legacyVersion: TLS1_2
            )
        )
        let unsupportedVersionClientHello = supportedClientHello.clone()
        unsupportedVersionClientHello[4] = UInt8(0x03)
        unsupportedVersionClientHello[5] = UInt8(0x05)
        try {
            _ = tlsDecodeClientHelloHandshake(unsupportedVersionClientHello)
            @Fail("unsupported TLS ClientHello version should be rejected as unsupported")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "UNSUPPORTED")
        }
    }

    @TestCase
    public func testSniAlpnAndOcspExtensionCodecs(): Unit {
        let sniExt = tlsBuildServerNameExtension("WWW.Example.com")
        @Assert(sniExt.extType, TLS_EXT_SERVER_NAME)
        let sniHosts = tlsParseServerNameExtension(sniExt)
        @Assert(sniHosts.size, 1)
        @Assert(sniHosts[0], TEST_HOST_WWW)

        let alpnExt = tlsBuildAlpnExtension(["h2", "http/1.1"])
        @Assert(alpnExt.extType, TLS_EXT_ALPN)
        let alpnProtocols = tlsParseAlpnExtension(alpnExt)
        @Assert(alpnProtocols, ["h2", "http/1.1"])

        let ocspRequest = TlsOcspStatusRequest(
            responderIds: [
                [UInt8(0x30), UInt8(0x03), UInt8(0x01), UInt8(0x01), UInt8(0xff)],
                [UInt8(0x30), UInt8(0x00)]
            ],
            requestExtensions: [UInt8(0x30), UInt8(0x00)]
        )
        let ocspExt = tlsBuildOcspStatusRequestExtension(request: ocspRequest)
        @Assert(ocspExt.extType, TLS_EXT_STATUS_REQUEST)
        let parsedOcsp = tlsParseOcspStatusRequestExtension(ocspExt)
        @Assert(parsedOcsp.statusType, TLS_STATUS_REQUEST_TYPE_OCSP)
        @Assert(parsedOcsp.responderIds.size, 2)
        @Assert(parsedOcsp.responderIds[0], [UInt8(0x30), UInt8(0x03), UInt8(0x01), UInt8(0x01), UInt8(0xff)])
        @Assert(parsedOcsp.requestExtensions, [UInt8(0x30), UInt8(0x00)])

        let ackExt = tlsBuildOcspStatusRequestAckExtension()
        @Assert(tlsIsOcspStatusRequestAckExtension(ackExt), true)
    }

    @TestCase
    public func testRejectInvalidHandshakeShapes(): Unit {
        let wrongType = tlsEncodeHandshakeFrame(TlsHandshakeFrame(ServerHello, [0]))
        try {
            _ = tlsDecodeClientHelloHandshake(wrongType)
            @Fail("wrong handshake type should be rejected")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "PARSE_ERROR")
        }

        let truncated = [UInt8(0x01), UInt8(0x00), UInt8(0x00), UInt8(0x05), UInt8(0x03)]
        try {
            _ = tlsDecodeHandshakeFrame(truncated)
            @Fail("truncated handshake frame should be rejected")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "PARSE_ERROR")
        }

        let random = incrementalBytes(32)
        let badClientHello = TlsClientHello(
            random,
            [0x1301],
            compressionMethods: [UInt8(0x00)],
            extensions: []
        )
        let encoded = tlsEncodeClientHelloHandshake(badClientHello)
        let broken = encoded.clone()
        broken[40] = UInt8(0x00)
        broken[41] = UInt8(0x01)
        try {
            _ = tlsDecodeClientHelloHandshake(broken)
            @Fail("broken cipher_suites vector length should be rejected")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "PARSE_ERROR")
        }

        try {
            _ = tlsBuildServerNameExtension("bad host")
            @Fail("SNI host with invalid characters should be rejected")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "INVALID_ARGUMENT")
        }

        try {
            _ = tlsBuildAlpnExtension(["h2", ""])
            @Fail("empty ALPN protocol id should be rejected")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "INVALID_ARGUMENT")
        }

        let truncatedSni = TlsExtension(TLS_EXT_SERVER_NAME, [UInt8(0x00), UInt8(0x04), UInt8(0x00), UInt8(0x00)])
        try {
            _ = tlsParseServerNameExtension(truncatedSni)
            @Fail("truncated SNI extension should be rejected")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "PARSE_ERROR")
        }

        let badAlpn = TlsExtension(TLS_EXT_ALPN, [UInt8(0x00), UInt8(0x02), UInt8(0x03), UInt8(0x68), UInt8(0x32)])
        try {
            _ = tlsParseAlpnExtension(badAlpn)
            @Fail("broken ALPN vector should be rejected")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "PARSE_ERROR")
        }

        let badOcsp = TlsExtension(TLS_EXT_STATUS_REQUEST, [UInt8(0x01), UInt8(0x00), UInt8(0x02), UInt8(0x00), UInt8(0x01)])
        try {
            _ = tlsParseOcspStatusRequestExtension(badOcsp)
            @Fail("truncated OCSP status_request extension should be rejected")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "PARSE_ERROR")
        }

        let cert12 = tlsEncodeCertificateHandshakeTls12([[UInt8(0x30), UInt8(0x01), UInt8(0x00)]])
        let cert12Broken = cert12.clone()
        cert12Broken[4] = UInt8(0x00)
        cert12Broken[5] = UInt8(0x00)
        cert12Broken[6] = UInt8(0x04)
        try {
            _ = tlsDecodeCertificateHandshakeTls12(cert12Broken)
            @Fail("TLS12 certificate entry broken length should be rejected")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "PARSE_ERROR")
        }

        let cert13 = tlsEncodeCertificateHandshakeTls13(
            Tls13CertificateMessage(entries: [TlsCertificateEntry([UInt8(0x30), UInt8(0x01), UInt8(0x00)])])
        )
        let cert13Broken = cert13.clone()
        cert13Broken[8] = UInt8(0x00)
        cert13Broken[9] = UInt8(0x00)
        cert13Broken[10] = UInt8(0x04)
        try {
            _ = tlsDecodeCertificateHandshakeTls13(cert13Broken)
            @Fail("TLS13 certificate entry broken length should be rejected")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "PARSE_ERROR")
        }

        let ee = tlsEncodeEncryptedExtensionsHandshake(
            TlsEncryptedExtensionsMessage(extensions: [TlsExtension(TLS_EXT_SERVER_NAME, [])])
        )
        let brokenEe = ee.clone()
        brokenEe[4] = UInt8(0x00)
        brokenEe[5] = UInt8(0x01)
        try {
            _ = tlsDecodeEncryptedExtensionsHandshake(brokenEe)
            @Fail("broken EncryptedExtensions vector length should be rejected")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "PARSE_ERROR")
        }

        let certVerify = tlsEncodeCertificateVerifyHandshake(
            TlsCertificateVerifyMessage(0x0403, [UInt8(0x30), UInt8(0x01), UInt8(0x00)])
        )
        let certVerifyBroken = certVerify.clone()
        certVerifyBroken[6] = UInt8(0x00)
        certVerifyBroken[7] = UInt8(0x10)
        try {
            _ = tlsDecodeCertificateVerifyHandshake(certVerifyBroken)
            @Fail("TLS CertificateVerify broken signature length should be rejected")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "PARSE_ERROR")
        }

        try {
            _ = tlsEncodeFinishedHandshake([])
            @Fail("empty finished verify_data should be rejected")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "INVALID_ARGUMENT")
        }
    }
}

private func incrementalBytes(size: Int64, start!: Int64 = 0): Array<Byte> {
    let out = Array<Byte>(size, repeat: 0)
    var i = 0
    while (i < size) {
        out[i] = UInt8((start + i) & 0xff)
        i += 1
    }
    out
}

private func bytesToHex(bytes: Array<Byte>): String {
    let digits: Array<String> = [
        "0", "1", "2", "3", "4", "5", "6", "7",
        "8", "9", "a", "b", "c", "d", "e", "f"
    ]
    var out = ""
    for (b in bytes) {
        let ub = UInt8(b)
        out += digits[Int64((ub >> 4) & UInt8(0x0f))]
        out += digits[Int64(ub & UInt8(0x0f))]
    }
    out
}

package jinguissl_core.tests

import jinguissl_core.crypto.compliance.*
import jinguissl_core.crypto.error.CryptoException
import jinguissl_core.crypto.tls.*

@Test
public class TlsRecordTestSuite {
    @TestCase
    public func testEncodeDecodeRecord(): Unit {
        let payload = "client-hello".toArray()
        let encoded = tlsEncodeRecord(Handshake, TLS1_2, payload)
        let decoded = tlsDecodeRecord(encoded)

        @Assert(decoded.header.contentType.toString(), "HANDSHAKE")
        @Assert(decoded.header.version.toString(), "TLS1.2")
        @Assert(decoded.header.length, payload.size)
        @Assert(decoded.fragment, payload)
    }

    @TestCase
    public func testAlertPayloadAndRecordRoundTrip(): Unit {
        let closeNotifyPayload = tlsEncodeAlert(Warning, CloseNotify)
        let closeNotify = tlsDecodeAlert(closeNotifyPayload)
        @Assert(closeNotify.level.toString(), "WARNING")
        @Assert(closeNotify.description.toString(), "CLOSE_NOTIFY")
        @Assert(tlsIsCloseNotifyAlert(closeNotify), true)

        let encodedRecord = tlsEncodeAlertRecord(TLS1_3, Fatal, NoApplicationProtocol)
        let decodedRecord = tlsDecodeRecord(encodedRecord)
        @Assert(decodedRecord.header.contentType.toString(), "ALERT")
        @Assert(decodedRecord.header.version.toString(), "TLS1.3")
        @Assert(decodedRecord.header.length, 2)

        let parsedAlert = tlsDecodeAlertRecord(encodedRecord)
        @Assert(parsedAlert.level.toString(), "FATAL")
        @Assert(parsedAlert.description.toString(), "NO_APPLICATION_PROTOCOL")
    }

    @TestCase
    public func testFragmentAndReassemble(): Unit {
        let payload = makePayload(50000)
        let fragments = tlsRecordFragment(payload, maxFragmentLen: 2048)
        @Assert(fragments.size > 1, true)
        @Assert(fragments[0].size, 2048)

        let reassembled = tlsRecordReassemble(fragments)
        @Assert(reassembled, payload)
    }

    @TestCase
    public func testAeadSealOpenRoundTrip(): Unit {
        let key = hexToBytes("000102030405060708090a0b0c0d0e0f")
        let iv = hexToBytes("101112131415161718191a1b")
        let layer = TlsAeadRecordLayer(key, iv, version: TLS1_2)

        let plaintext = "record-layer-round-trip".toArray()
        let encoded = layer.seal(ApplicationData, plaintext)
        let opened = layer.open(encoded)

        @Assert(opened.contentType.toString(), "APPLICATION_DATA")
        @Assert(opened.version.toString(), "TLS1.2")
        @Assert(opened.fragment, plaintext)
        @Assert(layer.writeSequence, 1)
        @Assert(layer.readSequence, 1)
    }

    @TestCase
    public func testAeadFragmentedRoundTrip(): Unit {
        let key = hexToBytes(TEST_HEX_BLOCK_00112233445566778899AABBCCDDEEFF)
        let iv = hexToBytes("0f0e0d0c0b0a090807060504")
        let sender = TlsAeadRecordLayer(key, iv, version: TLS1_2)
        let receiver = TlsAeadRecordLayer(key, iv, version: TLS1_2)

        let plaintext = makePayload(27000)
        let records = sender.sealFragments(ApplicationData, plaintext, maxFragmentLen: 4096)
        @Assert(records.size > 1, true)

        let output = receiver.openAndReassemble(records)
        @Assert(output, plaintext)
    }

    @TestCase
    public func testAeadRejectTamperedOrInvalidRecord(): Unit {
        let key = hexToBytes("a0a1a2a3a4a5a6a7a8a9aaabacadaeaf")
        let iv = hexToBytes("b0b1b2b3b4b5b6b7b8b9babb")
        let sender = TlsAeadRecordLayer(key, iv, version: TLS1_3)
        let receiver = TlsAeadRecordLayer(key, iv, version: TLS1_3)

        let encoded = sender.seal(ApplicationData, "tls13-data".toArray())

        let tampered = encoded.clone()
        tampered[tampered.size - 1] = UInt8(tampered[tampered.size - 1]) ^ UInt8(0x01)
        try {
            _ = receiver.open(tampered)
            @Fail("tampered record should fail AEAD tag validation")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "INVALID_ARGUMENT")
        }

        let badLength = encoded.clone()
        badLength[3] = UInt8(0x00)
        badLength[4] = UInt8(0x01)
        try {
            _ = receiver.open(badLength)
            @Fail("record with mismatched length should fail parsing")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "PARSE_ERROR")
        }
    }

    @TestCase
    public func testAeadSealOpenAlertRecord(): Unit {
        let key = hexToBytes("a0a1a2a3a4a5a6a7a8a9aaabacadaeaf")
        let iv = hexToBytes("b0b1b2b3b4b5b6b7b8b9babb")
        let sender = TlsAeadRecordLayer(key, iv, version: TLS1_3)
        let receiver = TlsAeadRecordLayer(key, iv, version: TLS1_3)

        let alertPayload = tlsEncodeAlert(Fatal, HandshakeFailure)
        let encoded = sender.seal(Alert, alertPayload)
        let opened = receiver.open(encoded)
        @Assert(opened.contentType.toString(), "ALERT")
        @Assert(opened.version.toString(), "TLS1.3")
        let decodedAlert = tlsDecodeAlert(opened.fragment)
        @Assert(decodedAlert.level.toString(), "FATAL")
        @Assert(decodedAlert.description.toString(), "HANDSHAKE_FAILURE")
    }

    @TestCase
    public func testChacha20Poly1305RecordRoundTrip(): Unit {
        let key = hexToBytes("000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f")
        let iv = hexToBytes("101112131415161718191a1b")
        let layer = TlsChacha20Poly1305RecordLayer(key, iv, version: TLS1_2)

        let plaintext = "tls12-chacha20-record".toArray()
        let encoded = layer.seal(ApplicationData, plaintext)
        let opened = layer.open(encoded)

        @Assert(opened.contentType.toString(), "APPLICATION_DATA")
        @Assert(opened.version.toString(), "TLS1.2")
        @Assert(opened.fragment, plaintext)
        @Assert(layer.writeSequence, 1)
        @Assert(layer.readSequence, 1)
    }

    @TestCase
    public func testChacha20Poly1305RecordFragmentedRoundTrip(): Unit {
        let key = hexToBytes("202122232425262728292a2b2c2d2e2f303132333435363738393a3b3c3d3e3f")
        let iv = hexToBytes("b0b1b2b3b4b5b6b7b8b9babb")
        let sender = TlsChacha20Poly1305RecordLayer(key, iv, version: TLS1_3)
        let receiver = TlsChacha20Poly1305RecordLayer(key, iv, version: TLS1_3)

        let plaintext = makePayload(32768)
        let records = sender.sealFragments(ApplicationData, plaintext, maxFragmentLen: 2048)
        @Assert(records.size > 1, true)

        let output = receiver.openAndReassemble(records)
        @Assert(output, plaintext)
    }

    @TestCase
    public func testChacha20Poly1305RecordRejectTamperedRecord(): Unit {
        let key = hexToBytes("404142434445464748494a4b4c4d4e4f505152535455565758595a5b5c5d5e5f")
        let iv = hexToBytes("c0c1c2c3c4c5c6c7c8c9cacb")
        let sender = TlsChacha20Poly1305RecordLayer(key, iv, version: TLS1_3)
        let receiver = TlsChacha20Poly1305RecordLayer(key, iv, version: TLS1_3)

        let encoded = sender.seal(ApplicationData, "tls13-chacha".toArray())
        let tampered = encoded.clone()
        tampered[tampered.size - 1] = UInt8(tampered[tampered.size - 1]) ^ UInt8(0x01)
        try {
            _ = receiver.open(tampered)
            @Fail("tampered CHACHA20-POLY1305 record should fail tag validation")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "INVALID_ARGUMENT")
        }
    }

    @TestCase
    public func testAlertDecodeRejectInvalidInputs(): Unit {
        try {
            _ = tlsDecodeAlert([UInt8(0x02)])
            @Fail("alert payload shorter than 2 bytes should be rejected")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "PARSE_ERROR")
        }

        try {
            _ = tlsDecodeAlert([UInt8(0x03), UInt8(0x00)])
            @Fail("unsupported alert level should be rejected")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "UNSUPPORTED")
        }

        try {
            _ = tlsDecodeAlert([UInt8(0x02), UInt8(0xff)])
            @Fail("unsupported alert description should be rejected")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "UNSUPPORTED")
        }

        let nonAlertRecord = tlsEncodeRecord(Handshake, TLS1_2, [UInt8(0x01), UInt8(0x02)])
        try {
            _ = tlsDecodeAlertRecord(nonAlertRecord)
            @Fail("non-ALERT record should be rejected by alert decoder")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "PARSE_ERROR")
        }
    }

    @TestCase
    public func testRecordDecodeRejectUnsupportedContentTypeAndVersion(): Unit {
        let unsupportedTypeRecord = [UInt8(0x99), UInt8(0x03), UInt8(0x03), UInt8(0x00), UInt8(0x00)]
        try {
            _ = tlsDecodeRecord(unsupportedTypeRecord)
            @Fail("unsupported TLS content type should be rejected as unsupported")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "UNSUPPORTED")
        }

        let unsupportedVersionRecord = [UInt8(0x16), UInt8(0x03), UInt8(0x05), UInt8(0x00), UInt8(0x00)]
        try {
            _ = tlsDecodeRecord(unsupportedVersionRecord)
            @Fail("unsupported TLS version should be rejected as unsupported")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "UNSUPPORTED")
        }
    }

    @TestCase
    public func testTlsRecordComplianceGate(): Unit {
        let allowed = FipsProfile.phase1Default()
        tlsRecordRequireAllowed(allowed, TLS1_2)
        tlsRecordRequireAllowed(allowed, TLS1_3)

        let blocked = FipsProfile.fromText("RSA")
        try {
            tlsRecordRequireAllowed(blocked, TLS1_2)
            @Fail("TLS record gate should reject profile without AES-GCM/TLS entry")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "COMPLIANCE_REJECTED")
        }

        let chachaAllowed = FipsProfile.fromText("TLS1.2\nTLS1.3\nCHACHA20-POLY1305")
        tlsRecordRequireAllowed(chachaAllowed, TLS1_3, algorithm: CHACHA20_POLY1305)

        try {
            tlsRecordRequireAllowed(allowed, TLS1_2, algorithm: CHACHA20_POLY1305)
            @Fail("default phase profile should reject CHACHA20-POLY1305")
        } catch (e: CryptoException) {
            @Assert(e.code.toString(), "COMPLIANCE_REJECTED")
        }
    }
}

private func makePayload(size: Int64): Array<Byte> {
    let out = Array<Byte>(size, repeat: 0)
    var i = 0
    while (i < size) {
        out[i] = UInt8(i % 251)
        i += 1
    }
    out
}

private func hexToBytes(hex: String): Array<Byte> {
    let clean = hex.trimAscii().replace(" ", "").replace("\n", "").replace("\t", "")
    if ((clean.size % 2) != 0) {
        throw Exception("invalid hex length")
    }

    let out = Array<Byte>(clean.size / 2, repeat: 0)
    var i = 0
    while (i < clean.size) {
        let hi = hexNibble(clean[i])
        let lo = hexNibble(clean[i + 1])
        out[i / 2] = UInt8((hi << 4) | lo)
        i += 2
    }
    out
}

private func hexNibble(ch: Byte): UInt8 {
    if (ch >= b'0' && ch <= b'9') {
        return UInt8(ch - b'0')
    }
    let lower = if (ch >= b'A' && ch <= b'F') {
        ch + 32
    } else {
        ch
    }
    if (lower >= b'a' && lower <= b'f') {
        return UInt8(lower - b'a' + 10)
    }
    throw Exception("invalid hex char")
}

package ignite.tests

import ignite.binary.*

let TEST_AAGUID_HEX = "0011" + "2233" + "4455" + "6677" + "8899" + "aabb" + "ccdd" + "eeff"

@Test
public class BinaryAttestationObjectTestSuite {
    @TestCase
    public func testDecodeAttestationObjectAndComposeWithAuthHelpers(): Unit {
        let attestation = decodeAttestationObject(attestationHexToBytes(
            "a363666d74646e6f6e656861757468446174615888" +
            "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f" +
            "41" +
            "0000002a" +
            TEST_AAGUID_HEX +
            "0004" +
            "deadbeef" +
            "a50102032620012158200102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f202258202122232425262728292a2b2c2d2e2f303132333435363738393a3b3c3d3e3f40" +
            "6761747453746d74a0"
        ))

        @Assert(attestation.format, "none")
        @Assert(attestation.attStmt.kind, CborKind.MapValue)

        let authData = decodeAuthenticatorData(attestation.authData)
        let attested = decodeAttestedCredentialData(authData)
        let coseKey = decodeCoseEc2PublicKey(attested.credentialPublicKeyBytes)

        @Assert(authBytesToHex(attested.credentialId), "deadbeef")
        @Assert(coseKey.algorithm, CoseAlgorithm.Es256)
        @Assert(coseKey.curve, CoseCurve.P256)
    }

    @TestCase
    public func testDecodeAttestationObjectRejectsWrongRootAndTrailingData(): Unit {
        assertAttestationFailure(
            attestationHexToBytes("83010203"),
            AttestationObjectErrorCode.MalformedInput
        )
        assertAttestationFailure(
            attestationHexToBytes("a363666d74646e6f6e6568617574684461746141016761747453746d74a000"),
            AttestationObjectErrorCode.MalformedInput
        )
    }

    @TestCase
    public func testDecodeAttestationObjectRejectsMissingField(): Unit {
        assertAttestationFailure(
            attestationHexToBytes("a263666d74646e6f6e656761747453746d74a0"),
            AttestationObjectErrorCode.MissingField
        )
    }

    @TestCase
    public func testDecodeAttestationObjectRejectsWrongFieldKinds(): Unit {
        assertAttestationFailure(
            attestationHexToBytes("a363666d740168617574684461746141016761747453746d74a0"),
            AttestationObjectErrorCode.InvalidField
        )
        assertAttestationFailure(
            attestationHexToBytes("a363666d74646e6f6e65686175746844617461016761747453746d74a0"),
            AttestationObjectErrorCode.InvalidField
        )
        assertAttestationFailure(
            attestationHexToBytes("a363666d74646e6f6e6568617574684461746141016761747453746d7401"),
            AttestationObjectErrorCode.InvalidField
        )
    }
}

func assertAttestationFailure(
    bytes: Array<UInt8>,
    expectedCode: AttestationObjectErrorCode
): Unit {
    try {
        let _ = decodeAttestationObject(bytes)
        @Fail("attestationObject decode should have failed")
    } catch (e: AttestationObjectException) {
        @Assert(e.code, expectedCode)
    }
}

func attestationHexToBytes(input: String): Array<UInt8> {
    let text = input.trimAscii().toAsciiLower()
    let runes = text.toRuneArray()
    if (runes.size == 0 || (runes.size % 2) != 0) {
        throw Exception("hex length must be even and non-empty")
    }
    let out = Array<UInt8>(runes.size / 2, repeat: 0)
    var i: Int64 = 0
    while (i < runes.size) {
        let hi = attestationHexNibble(runes[i])
        let lo = attestationHexNibble(runes[i + 1])
        if (hi < 0 || lo < 0) {
            throw Exception("invalid hex text")
        }
        out[i / 2] = UInt8((hi << 4) | lo)
        i += 2
    }
    out
}

func attestationHexNibble(ch: Rune): Int64 {
    match (ch) {
        case r'0' => 0
        case r'1' => 1
        case r'2' => 2
        case r'3' => 3
        case r'4' => 4
        case r'5' => 5
        case r'6' => 6
        case r'7' => 7
        case r'8' => 8
        case r'9' => 9
        case r'a' => 10
        case r'b' => 11
        case r'c' => 12
        case r'd' => 13
        case r'e' => 14
        case r'f' => 15
        case _ => -1
    }
}

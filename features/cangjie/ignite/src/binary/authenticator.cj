package ignite.binary

public enum AuthenticatorDataErrorCode <: Equatable<AuthenticatorDataErrorCode> & ToString {
    | TruncatedInput
    | MissingAttestedCredentialData
    | MalformedCredentialPublicKey

    public operator func ==(right: AuthenticatorDataErrorCode): Bool {
        ordinalValue() == right.ordinalValue()
    }

    public operator func !=(right: AuthenticatorDataErrorCode): Bool {
        !(this == right)
    }

    public func ordinalValue(): Int64 {
        match (this) {
            case TruncatedInput => 0
            case MissingAttestedCredentialData => 1
            case MalformedCredentialPublicKey => 2
        }
    }

    public func toString(): String {
        match (this) {
            case TruncatedInput => "TRUNCATED_INPUT"
            case MissingAttestedCredentialData => "MISSING_ATTESTED_CREDENTIAL_DATA"
            case MalformedCredentialPublicKey => "MALFORMED_CREDENTIAL_PUBLIC_KEY"
        }
    }
}

public class AuthenticatorDataException <: Exception {
    public let code: AuthenticatorDataErrorCode

    public init(code: AuthenticatorDataErrorCode, message: String) {
        super(message)
        this.code = code
    }
}

public class AuthenticatorDataFlags {
    public let rawValue: UInt8

    public init(rawValue: UInt8) {
        this.rawValue = rawValue
    }

    public func isUserPresent(): Bool {
        hasMask(UInt8(0x01))
    }

    public func isUserVerified(): Bool {
        hasMask(UInt8(0x04))
    }

    public func isBackupEligible(): Bool {
        hasMask(UInt8(0x08))
    }

    public func isBackupState(): Bool {
        hasMask(UInt8(0x10))
    }

    public func hasAttestedCredentialData(): Bool {
        hasMask(UInt8(0x40))
    }

    public func hasExtensions(): Bool {
        hasMask(UInt8(0x80))
    }

    func hasMask(mask: UInt8): Bool {
        (Int64(rawValue) & Int64(mask)) != 0
    }
}

public class AuthenticatorData {
    public static let fixedHeaderLength: Int64 = 37

    public let rpIdHash: Array<UInt8>
    public let flags: AuthenticatorDataFlags
    public let signCount: UInt32
    public let tail: Array<UInt8>

    public init(
        rpIdHash: Array<UInt8>,
        flags: AuthenticatorDataFlags,
        signCount: UInt32,
        tail!: Array<UInt8> = []
    ) {
        if (rpIdHash.size != 32) {
            throw AuthenticatorDataException(
                AuthenticatorDataErrorCode.TruncatedInput,
                "authenticatorData rpIdHash must be 32 bytes"
            )
        }
        this.rpIdHash = cloneBytes(rpIdHash)
        this.flags = AuthenticatorDataFlags(flags.rawValue)
        this.signCount = signCount
        this.tail = cloneBytes(tail)
    }
}

public class AuthenticatorAttestedCredentialData {
    public let aaguid: Array<UInt8>
    public let credentialId: Array<UInt8>
    public let credentialPublicKeyBytes: Array<UInt8>
    public let remainingBytes: Array<UInt8>

    public init(
        aaguid: Array<UInt8>,
        credentialId: Array<UInt8>,
        credentialPublicKeyBytes: Array<UInt8>,
        remainingBytes!: Array<UInt8> = []
    ) {
        if (aaguid.size != 16) {
            throw AuthenticatorDataException(
                AuthenticatorDataErrorCode.TruncatedInput,
                "attested credential data AAGUID must be 16 bytes"
            )
        }
        this.aaguid = cloneBytes(aaguid)
        this.credentialId = cloneBytes(credentialId)
        this.credentialPublicKeyBytes = cloneBytes(credentialPublicKeyBytes)
        this.remainingBytes = cloneBytes(remainingBytes)
    }
}

public func decodeAuthenticatorData(input: Array<UInt8>): AuthenticatorData {
    if (input.size < AuthenticatorData.fixedHeaderLength) {
        throw AuthenticatorDataException(
            AuthenticatorDataErrorCode.TruncatedInput,
            "authenticatorData must be at least ${AuthenticatorData.fixedHeaderLength} bytes"
        )
    }

    let rpIdHash = sliceBytes(input, 0, end: 32)
    let flags = AuthenticatorDataFlags(input[32])
    let signCount = readUint32BE(input, 33)
    let tail = sliceBytes(input, AuthenticatorData.fixedHeaderLength)
    AuthenticatorData(rpIdHash, flags, signCount, tail: tail)
}

public func decodeAttestedCredentialData(
    input: AuthenticatorData,
    option!: CborDecodeOption = CborDecodeOption()
): AuthenticatorAttestedCredentialData {
    if (!input.flags.hasAttestedCredentialData()) {
        throw AuthenticatorDataException(
            AuthenticatorDataErrorCode.MissingAttestedCredentialData,
            "authenticatorData does not carry attested credential data"
        )
    }
    decodeAttestedCredentialDataTail(input.tail, option: option)
}

func decodeAttestedCredentialDataTail(
    input: Array<UInt8>,
    option!: CborDecodeOption = CborDecodeOption()
): AuthenticatorAttestedCredentialData {
    if (input.size < 18) {
        throw AuthenticatorDataException(
            AuthenticatorDataErrorCode.TruncatedInput,
            "attested credential data must be at least 18 bytes"
        )
    }

    let aaguid = sliceBytes(input, 0, end: 16)
    let credentialIdLength = Int64(readUint16BE(input, 16))
    let credentialIdEnd = 18 + credentialIdLength
    if (credentialIdEnd > input.size) {
        throw AuthenticatorDataException(
            AuthenticatorDataErrorCode.TruncatedInput,
            "attested credential data ended before credentialId completed"
        )
    }

    let credentialId = sliceBytes(input, 18, end: credentialIdEnd)
    let keyAndRemaining = sliceBytes(input, credentialIdEnd)
    if (keyAndRemaining.size == 0) {
        throw AuthenticatorDataException(
            AuthenticatorDataErrorCode.TruncatedInput,
            "attested credential data missing credentialPublicKey"
        )
    }

    let prefix = decodeCredentialPublicKeyPrefix(keyAndRemaining, option: option)
    let credentialPublicKeyBytes = sliceBytes(keyAndRemaining, 0, end: prefix.bytesRead)
    let remainingBytes = sliceBytes(keyAndRemaining, prefix.bytesRead)
    AuthenticatorAttestedCredentialData(
        aaguid,
        credentialId,
        credentialPublicKeyBytes,
        remainingBytes: remainingBytes
    )
}

func decodeCredentialPublicKeyPrefix(
    input: Array<UInt8>,
    option!: CborDecodeOption = CborDecodeOption()
): CborPrefixDecodeResult {
    try {
        let prefix = decodeCborPrefix(input, option: option)
        if (prefix.value.kind != CborKind.MapValue) {
            throw AuthenticatorDataException(
                AuthenticatorDataErrorCode.MalformedCredentialPublicKey,
                "credentialPublicKey must be a CBOR map"
            )
        }
        prefix
    } catch (e: CborException) {
        throw AuthenticatorDataException(
            AuthenticatorDataErrorCode.MalformedCredentialPublicKey,
            "credentialPublicKey is not a valid CBOR map: ${e.message}"
        )
    }
}

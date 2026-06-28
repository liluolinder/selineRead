package ignite.binary

public enum AttestationObjectErrorCode <: Equatable<AttestationObjectErrorCode> & ToString {
    | MalformedInput
    | MissingField
    | InvalidField

    public operator func ==(right: AttestationObjectErrorCode): Bool {
        ordinalValue() == right.ordinalValue()
    }

    public operator func !=(right: AttestationObjectErrorCode): Bool {
        !(this == right)
    }

    public func ordinalValue(): Int64 {
        match (this) {
            case MalformedInput => 0
            case MissingField => 1
            case InvalidField => 2
        }
    }

    public func toString(): String {
        match (this) {
            case MalformedInput => "MALFORMED_INPUT"
            case MissingField => "MISSING_FIELD"
            case InvalidField => "INVALID_FIELD"
        }
    }
}

public class AttestationObjectException <: Exception {
    public let code: AttestationObjectErrorCode

    public init(code: AttestationObjectErrorCode, message: String) {
        super(message)
        this.code = code
    }
}

public class AttestationObject {
    public let format: String
    public let authData: Array<UInt8>
    public let attStmt: CborValue

    public init(format: String, authData: Array<UInt8>, attStmt: CborValue) {
        if (attStmt.kind != CborKind.MapValue) {
            throw AttestationObjectException(
                AttestationObjectErrorCode.InvalidField,
                "attestationObject field 'attStmt' must be a CBOR map"
            )
        }
        this.format = format
        this.authData = cloneBytes(authData)
        this.attStmt = attStmt
    }
}

public func decodeAttestationObject(
    input: Array<UInt8>,
    option!: CborDecodeOption = CborDecodeOption()
): AttestationObject {
    try {
        let value = decodeCborMap(input, option: option)
        decodeAttestationObjectValue(value)
    } catch (e: CborException) {
        throw AttestationObjectException(
            AttestationObjectErrorCode.MalformedInput,
            "invalid attestationObject CBOR: ${e.message}"
        )
    }
}

func decodeAttestationObjectValue(value: CborValue): AttestationObject {
    let format = requireAttestationTextField(value, "fmt")
    let authData = requireAttestationByteStringField(value, "authData")
    let attStmt = requireAttestationMapField(value, "attStmt")
    AttestationObject(format, authData, attStmt)
}

func requireAttestationTextField(value: CborValue, key: String): String {
    let fieldValue = requireAttestationField(value, key)
    match (fieldValue.asTextString()) {
        case Some(text) => text
        case None =>
            throw AttestationObjectException(
                AttestationObjectErrorCode.InvalidField,
                "attestationObject field '${key}' must be a text string"
            )
    }
}

func requireAttestationByteStringField(value: CborValue, key: String): Array<UInt8> {
    let fieldValue = requireAttestationField(value, key)
    match (fieldValue.asByteString()) {
        case Some(bytes) => bytes
        case None =>
            throw AttestationObjectException(
                AttestationObjectErrorCode.InvalidField,
                "attestationObject field '${key}' must be a byte string"
            )
    }
}

func requireAttestationMapField(value: CborValue, key: String): CborValue {
    let fieldValue = requireAttestationField(value, key)
    if (fieldValue.kind != CborKind.MapValue) {
        throw AttestationObjectException(
            AttestationObjectErrorCode.InvalidField,
            "attestationObject field '${key}' must be a CBOR map"
        )
    }
    fieldValue
}

func requireAttestationField(value: CborValue, key: String): CborValue {
    match (value.getTextKey(key)) {
        case Some(fieldValue) => fieldValue
        case None =>
            throw AttestationObjectException(
                AttestationObjectErrorCode.MissingField,
                "attestationObject missing '${key}' field"
            )
    }
}

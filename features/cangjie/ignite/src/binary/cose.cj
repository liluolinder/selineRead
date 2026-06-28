package ignite.binary

public enum CoseErrorCode <: Equatable<CoseErrorCode> & ToString {
    | MalformedInput
    | UnsupportedKeyType
    | UnsupportedAlgorithm
    | UnsupportedCurve
    | MissingField
    | InvalidField

    public operator func ==(right: CoseErrorCode): Bool {
        ordinalValue() == right.ordinalValue()
    }

    public operator func !=(right: CoseErrorCode): Bool {
        !(this == right)
    }

    public func ordinalValue(): Int64 {
        match (this) {
            case MalformedInput => 0
            case UnsupportedKeyType => 1
            case UnsupportedAlgorithm => 2
            case UnsupportedCurve => 3
            case MissingField => 4
            case InvalidField => 5
        }
    }

    public func toString(): String {
        match (this) {
            case MalformedInput => "MALFORMED_INPUT"
            case UnsupportedKeyType => "UNSUPPORTED_KEY_TYPE"
            case UnsupportedAlgorithm => "UNSUPPORTED_ALGORITHM"
            case UnsupportedCurve => "UNSUPPORTED_CURVE"
            case MissingField => "MISSING_FIELD"
            case InvalidField => "INVALID_FIELD"
        }
    }
}

public class CoseException <: Exception {
    public let code: CoseErrorCode

    public init(code: CoseErrorCode, message: String) {
        super(message)
        this.code = code
    }
}

public enum CoseKeyType <: Equatable<CoseKeyType> & ToString {
    | Ec2

    public operator func ==(right: CoseKeyType): Bool {
        ordinalValue() == right.ordinalValue()
    }

    public operator func !=(right: CoseKeyType): Bool {
        !(this == right)
    }

    public func ordinalValue(): Int64 {
        match (this) {
            case Ec2 => 0
        }
    }

    public func coseValue(): Int64 {
        match (this) {
            case Ec2 => 2
        }
    }

    public func toString(): String {
        match (this) {
            case Ec2 => "EC2"
        }
    }
}

public enum CoseAlgorithm <: Equatable<CoseAlgorithm> & ToString {
    | Es256

    public operator func ==(right: CoseAlgorithm): Bool {
        ordinalValue() == right.ordinalValue()
    }

    public operator func !=(right: CoseAlgorithm): Bool {
        !(this == right)
    }

    public func ordinalValue(): Int64 {
        match (this) {
            case Es256 => 0
        }
    }

    public func coseValue(): Int64 {
        match (this) {
            case Es256 => -7
        }
    }

    public func toString(): String {
        match (this) {
            case Es256 => "ES256"
        }
    }
}

public enum CoseCurve <: Equatable<CoseCurve> & ToString {
    | P256

    public operator func ==(right: CoseCurve): Bool {
        ordinalValue() == right.ordinalValue()
    }

    public operator func !=(right: CoseCurve): Bool {
        !(this == right)
    }

    public func ordinalValue(): Int64 {
        match (this) {
            case P256 => 0
        }
    }

    public func coseValue(): Int64 {
        match (this) {
            case P256 => 1
        }
    }

    public func coordinateLength(): Int64 {
        match (this) {
            case P256 => 32
        }
    }

    public func toString(): String {
        match (this) {
            case P256 => "P-256"
        }
    }
}

public class CoseEc2PublicKey {
    public let keyType: CoseKeyType
    public let algorithm: CoseAlgorithm
    public let curve: CoseCurve
    public let x: Array<UInt8>
    public let y: Array<UInt8>

    public init(
        keyType: CoseKeyType,
        algorithm: CoseAlgorithm,
        curve: CoseCurve,
        x: Array<UInt8>,
        y: Array<UInt8>
    ) {
        let coordinateLength = curve.coordinateLength()
        if (x.size != coordinateLength || y.size != coordinateLength) {
            throw CoseException(
                CoseErrorCode.InvalidField,
                "COSE_Key ${curve.toString()} coordinates must be ${coordinateLength} bytes"
            )
        }
        this.keyType = keyType
        this.algorithm = algorithm
        this.curve = curve
        this.x = cloneBytes(x)
        this.y = cloneBytes(y)
    }
}

public func decodeCoseEc2PublicKey(
    input: Array<UInt8>,
    option!: CborDecodeOption = CborDecodeOption()
): CoseEc2PublicKey {
    try {
        let value = decodeCborMap(input, option: option)
        decodeCoseEc2PublicKeyValue(value)
    } catch (e: CborException) {
        throw CoseException(CoseErrorCode.MalformedInput, "invalid COSE_Key CBOR: ${e.message}")
    }
}

func decodeCoseEc2PublicKeyValue(value: CborValue): CoseEc2PublicKey {
    let keyTypeCode = requireCoseIntField(value, 1, "kty")
    let keyType = decodeCoseKeyType(keyTypeCode)

    let algorithmCode = requireCoseIntField(value, 3, "alg")
    let algorithm = decodeCoseAlgorithm(algorithmCode)

    let curveCode = requireCoseIntField(value, -1, "crv")
    let curve = decodeCoseCurve(curveCode)

    let x = requireCoseByteStringField(value, -2, "x")
    let y = requireCoseByteStringField(value, -3, "y")

    CoseEc2PublicKey(keyType, algorithm, curve, x, y)
}

func decodeCoseKeyType(value: Int64): CoseKeyType {
    if (value == CoseKeyType.Ec2.coseValue()) {
        return CoseKeyType.Ec2
    }
    throw CoseException(CoseErrorCode.UnsupportedKeyType, "unsupported COSE_Key kty: ${value}")
}

func decodeCoseAlgorithm(value: Int64): CoseAlgorithm {
    if (value == CoseAlgorithm.Es256.coseValue()) {
        return CoseAlgorithm.Es256
    }
    throw CoseException(CoseErrorCode.UnsupportedAlgorithm, "unsupported COSE_Key alg: ${value}")
}

func decodeCoseCurve(value: Int64): CoseCurve {
    if (value == CoseCurve.P256.coseValue()) {
        return CoseCurve.P256
    }
    throw CoseException(CoseErrorCode.UnsupportedCurve, "unsupported COSE_Key crv: ${value}")
}

func requireCoseIntField(value: CborValue, key: Int64, label: String): Int64 {
    let fieldValue = requireCoseField(value, key, label)
    match (fieldValue.asInt64()) {
        case Some(number) => number
        case None =>
            throw CoseException(
                CoseErrorCode.InvalidField,
                "COSE_Key field '${label}' must be an integer"
            )
    }
}

func requireCoseByteStringField(value: CborValue, key: Int64, label: String): Array<UInt8> {
    let fieldValue = requireCoseField(value, key, label)
    match (fieldValue.asByteString()) {
        case Some(bytes) => bytes
        case None =>
            throw CoseException(
                CoseErrorCode.InvalidField,
                "COSE_Key field '${label}' must be a byte string"
            )
    }
}

func requireCoseField(value: CborValue, key: Int64, label: String): CborValue {
    match (value.getIntKey(key)) {
        case Some(fieldValue) => fieldValue
        case None =>
            throw CoseException(CoseErrorCode.MissingField, "COSE_Key missing '${label}' field")
    }
}

package jinguissl_core.crypto.error

public enum CryptoErrorCode <: Equatable<CryptoErrorCode> & ToString {
    | InvalidArgument
    | OutOfBounds
    | DivideByZero
    | NoModInverse
    | ComplianceRejected
    | ParseError
    | Unsupported
    | InternalError

    public operator func ==(right: CryptoErrorCode): Bool {
        ordinalValue() == right.ordinalValue()
    }

    public operator func !=(right: CryptoErrorCode): Bool {
        !(this == right)
    }

    public func ordinalValue(): Int64 {
        match (this) {
            case InvalidArgument => 0
            case OutOfBounds => 1
            case DivideByZero => 2
            case NoModInverse => 3
            case ComplianceRejected => 4
            case ParseError => 5
            case Unsupported => 6
            case InternalError => 7
        }
    }

    public func toString(): String {
        match (this) {
            case InvalidArgument => "INVALID_ARGUMENT"
            case OutOfBounds => "OUT_OF_BOUNDS"
            case DivideByZero => "DIVIDE_BY_ZERO"
            case NoModInverse => "NO_MOD_INVERSE"
            case ComplianceRejected => "COMPLIANCE_REJECTED"
            case ParseError => "PARSE_ERROR"
            case Unsupported => "UNSUPPORTED"
            case InternalError => "INTERNAL_ERROR"
        }
    }
}

public class CryptoException <: Exception {
    public let code: CryptoErrorCode

    public CryptoException(code: CryptoErrorCode, message: String) {
        super(message)
        this.code = code
    }
}

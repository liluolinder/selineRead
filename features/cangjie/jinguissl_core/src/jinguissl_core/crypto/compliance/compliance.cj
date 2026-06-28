package jinguissl_core.crypto.compliance

import std.collection.HashSet
import std.collection.ArrayList
import jinguissl_core.crypto.error.{CryptoException, CryptoErrorCode}

public enum TlsVersion <: Equatable<TlsVersion> & ToString {
    | TLS1_2
    | TLS1_3

    public operator func ==(right: TlsVersion): Bool {
        ordinalValue() == right.ordinalValue()
    }

    public operator func !=(right: TlsVersion): Bool {
        !(this == right)
    }

    public func ordinalValue(): Int64 {
        match (this) {
            case TLS1_2 => 0
            case TLS1_3 => 1
        }
    }

    public func toString(): String {
        match (this) {
            case TLS1_2 => "TLS1.2"
            case TLS1_3 => "TLS1.3"
        }
    }
}

public let TLS_VERSION_1_2: TlsVersion = TLS1_2
public let TLS_VERSION_1_3: TlsVersion = TLS1_3

public class FipsProfile {
    let _allowList: HashSet<String>

    public init(algorithms: Array<String>) {
        if (algorithms.size == 0) {
            throw CryptoException(InvalidArgument, "allow list must not be empty")
        }
        let allowList = HashSet<String>()
        for (alg in algorithms) {
            let key = normalizeAlgorithm(alg)
            if (key.size > 0) {
                allowList.add(key)
            }
        }
        if (allowList.size == 0) {
            throw CryptoException(InvalidArgument, "allow list must not be empty")
        }
        this._allowList = allowList
    }

    public static func phase1Default(): FipsProfile {
        FipsProfile([
            "SHA-256", "SHA-384", "SHA-512",
            "HMAC-SHA-256", "HMAC-SHA-384", "HMAC-SHA-512",
            "AES-CTR", "AES-CBC", "AES-GCM",
            "RSA", "ECDSA", "ECDH",
            "RSA-KEM", "ECDH-KEM",
            "TLS1.2", "TLS1.3"
        ])
    }

    public static func fromText(content: String): FipsProfile {
        let normalized = content.replace("\r", "\n")
        let lines = normalized.split('\n')
        let entries = ArrayList<String>()
        for (line in lines) {
            let trimmed = line.trimAscii()
            if (trimmed.size == 0 || trimmed.startsWith("#")) {
                continue
            }
            for (part in trimmed.split(",", removeEmpty: true)) {
                let entry = part.trimAscii()
                if (entry.size > 0) {
                    entries.add(entry)
                }
            }
        }
        FipsProfile(entries.toArray())
    }

    public func isAllowed(algorithm: String): Bool {
        let key = normalizeAlgorithm(algorithm)
        if (key.size == 0) {
            return false
        }
        _allowList.contains(key)
    }

    /**
 * requireAllowed.
 *
 * @throws CryptoException 当操作失败时抛出
 */
public func requireAllowed(algorithm: String): Unit {
        if (!isAllowed(algorithm)) {
            throw CryptoException(ComplianceRejected, "algorithm is blocked by FIPS profile: ${algorithm}")
        }
    }

    public func allowedAlgorithms(): Array<String> {
        let result = ArrayList<String>()
        let iter = _allowList.iterator()
        while (let Some(name) <- iter.next()) {
            result.add(name)
        }
        result.toArray()
    }
}

private func normalizeAlgorithm(name: String): String {
    name.trimAscii().toAsciiUpper().replace(" ", "")
}

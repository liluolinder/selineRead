package jinguissl.contract

import jinguissl_core.crypto.error.{CryptoErrorCode, CryptoException}
import jinguissl_core.crypto.tls.{
    TLS_SESSION_DEFAULT_TTL_SECONDS,
    TlsSessionCache,
    TlsSessionCacheStats
}

public class ContractTlsSessionCacheStats {
    public let size: Int64
    public let hits: Int64
    public let misses: Int64
    public let evictions: Int64
    public let expiredRemovals: Int64

    public init(size: Int64, hits: Int64, misses: Int64, evictions: Int64, expiredRemovals: Int64) {
        this.size = size
        this.hits = hits
        this.misses = misses
        this.evictions = evictions
        this.expiredRemovals = expiredRemovals
    }
}

public class ContractTlsSessionCache {
    let _inner: TlsSessionCache

    public init(maxEntries!: Int64 = 1024, defaultTtlSeconds!: Int64 = TLS_SESSION_DEFAULT_TTL_SECONDS) {
        try {
            this._inner = TlsSessionCache(maxEntries: maxEntries, defaultTtlSeconds: defaultTtlSeconds)
        } catch (e: CryptoException) {
            throw ContractException(
                contractSessionCacheMapCryptoError(e),
                "TLS session cache initialization failed: ${e.message}"
            )
        }
    }

    public prop size: Int64 {
        get() {
            _inner.size
        }
    }

    public func stats(): ContractTlsSessionCacheStats {
        contractSessionCacheFromStats(_inner.stats())
    }

    public func clear(): Unit {
        _inner.clear()
    }
}

private func contractSessionCacheFromStats(stats: TlsSessionCacheStats): ContractTlsSessionCacheStats {
    ContractTlsSessionCacheStats(
        stats.size,
        stats.hits,
        stats.misses,
        stats.evictions,
        stats.expiredRemovals
    )
}

private func contractSessionCacheMapCryptoError(e: CryptoException): ContractErrorCode {
    match (e.code) {
        case CryptoErrorCode.InvalidArgument => ContractErrorCode.BadInput
        case CryptoErrorCode.OutOfBounds => ContractErrorCode.BadInput
        case CryptoErrorCode.DivideByZero => ContractErrorCode.BadInput
        case CryptoErrorCode.NoModInverse => ContractErrorCode.BadInput
        case CryptoErrorCode.ParseError => ContractErrorCode.BadInput
        case CryptoErrorCode.ComplianceRejected => ContractErrorCode.ComplianceRejected
        case CryptoErrorCode.Unsupported => ContractErrorCode.Unsupported
        case CryptoErrorCode.InternalError => ContractErrorCode.InternalError
        case _ => ContractErrorCode.InternalError
    }
}

/** @internal - OpenSSL BIGNUM compatibility shim, not a standalone product interface. Do not add contract barrier. */
package jinguissl_core.compat.bn

import jinguissl_core.crypto.bignum.BigNum

public class BN {
    public var value: BigNum

    public init() {
        this.value = BigNum.zero()
    }

    public init(value: BigNum) {
        this.value = value
    }
}

public func BN_new(): BN {
    BN()
}

public func BN_bin2bn(input: Array<Byte>, out!: ?BN = None): BN {
    let bn = out ?? BN_new()
    bn.value = BigNum.fromBytesBE(input)
    bn
}

public func BN_bn2bin(bn: BN): Array<Byte> {
    bn.value.toBytesBE()
}

public func BN_add(a: BN, b: BN): BN {
    BN(a.value.add(b.value))
}

public func BN_sub(a: BN, b: BN): BN {
    BN(a.value.sub(b.value))
}

public func BN_mul(a: BN, b: BN): BN {
    BN(a.value.mul(b.value))
}

public func BN_div(a: BN, b: BN): (BN, BN) {
    let (q, r) = a.value.divMod(b.value)
    (BN(q), BN(r))
}

public func BN_mod(a: BN, m: BN): BN {
    BN(a.value.mod(m.value))
}

public func BN_exp(a: BN, e: BN): BN {
    BN(a.value.exp(e.value))
}

public func BN_mod_exp(a: BN, e: BN, m: BN): BN {
    BN(a.value.modExp(e.value, m.value))
}

public func BN_mod_inverse(a: BN, m: BN): BN {
    BN(a.value.modInverse(m.value))
}

public func BN_lshift(a: BN, bits: Int64): BN {
    BN(a.value.lshift(bits))
}

public func BN_rshift(a: BN, bits: Int64): BN {
    BN(a.value.rshift(bits))
}

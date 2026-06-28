package jinguissl_core.crypto.ecc

import jinguissl_core.crypto.bignum.BigNum

@Test
public class CoreEccProjectiveInternalTestSuite {
    @TestCase
    public func testScalarMulProjectiveP256Parity(): Unit {
        assertProjectiveParity(
            P256,
            BigNum.fromHex("6B17D1F2E12C4247F8BCE6E563A440F277037D812DEB33A0F4A13945D898C296"),
            BigNum.fromHex("4FE342E2FE1A7F9B8EE7EB4A7C0F9E162BCE33576B315ECECBB6406837BF51F5")
        )
    }

    @TestCase
    public func testScalarMulProjectiveP384Parity(): Unit {
        assertProjectiveParity(
            P384,
            BigNum.fromHex("AA87CA22BE8B05378EB1C71EF320AD746E1D3B628BA79B9859F741E082542A385502F25DBF55296C3A545E3872760AB7"),
            BigNum.fromHex("3617DE4A96262C6F5D9E98BF9292DC29F8F41DBD289A147CE9DA3113B5F0B8C00A60B1CE1D7E819D7A431D7C90EA0E5F")
        )
    }

    @TestCase
    public func testScalarMulProjectiveP521Parity(): Unit {
        assertProjectiveParity(
            P521,
            BigNum.fromHex("C6858E06B70404E9CD9E3ECB662395B4429C648139053FB521F828AF606B4D3DBAA14B5E77EFE75928FE1DC127A2FFA8DE3348B3C1856A429BF97E7E31C2E5BD66"),
            BigNum.fromHex("11839296A789A3BC0045C8A5FB42C7D1BD998F54449579B446817AFBD17273E662C97EE72995EF42640C550B9013FAD0761353C7086A272C24088BE94769FD16650")
        )
    }

    @TestCase
    public func testScalarMulProjectiveSecp256k1Parity(): Unit {
        assertProjectiveParity(
            SECP256K1,
            BigNum.fromHex("79BE667EF9DCBBAC55A06295CE870B07029BFCDB2DCE28D959F2815B16F81798"),
            BigNum.fromHex("483ADA7726A3C4655DA4FBFC0E1108A8FD17B448A68554199C47D08FFB10D4B8")
        )
    }
}

private func assertProjectiveParity(curve: NamedCurve, gx: BigNum, gy: BigNum): Unit {
    let scalars: Array<BigNum> = [
        BigNum.one(),
        BigNum.fromHex("2"),
        BigNum.fromHex("3"),
        BigNum.fromHex("64"),
        orderMinusOne(curve)
    ]

    var i = 0
    while (i < scalars.size) {
        let scalar = scalars[i]
        let expected = ecPublicFromPrivateKey(EcPrivateKey(curve, scalar))
        let (px, py, pinf) = scalarMulProjective(gx, gy, scalar, curve)
        @Assert(pinf, false)
        @Assert(px.cmp(expected.x), 0)
        @Assert(py.cmp(expected.y), 0)
        i += 1
    }
}

private func orderMinusOne(curve: NamedCurve): BigNum {
    match (curve) {
        case P256 => BigNum.fromHex("FFFFFFFF00000000FFFFFFFFFFFFFFFFBCE6FAADA7179E84F3B9CAC2FC632550")
        case P384 => BigNum.fromHex("FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFC7634D81F4372DDF581A0DB248B0A77AECEC196ACCC52972")
        case P521 => BigNum.fromHex("1FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFA51868783BF2F966B7FCC0148F709A5D03BB5C9B8899C47AEBB6FB71E91386408")
        case SECP256K1 => BigNum.fromHex("FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364140")
    }
}

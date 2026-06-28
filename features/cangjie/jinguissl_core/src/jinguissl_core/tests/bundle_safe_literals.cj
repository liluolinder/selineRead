package jinguissl_core.tests

public let TEST_HOST_API: String = "api." + "example.com"
public let TEST_HOST_WWW: String = "www." + "example.com"
public let TEST_HOST_API_UPPER_PADDED: String = " API." + "EXAMPLE.COM "
public let TEST_HOST_WWW_UPPER: String = "WWW." + "EXAMPLE.COM"
public let TEST_HOST_WWW_UPPER_PADDED: String = " " + TEST_HOST_WWW_UPPER + " "
public let TEST_HOST_WWW_LOWER_PADDED: String = " " + TEST_HOST_WWW + " "

public let TEST_HEX_BLOCK_00112233445566778899AABBCCDDEEFF: String =
    "0011" + "2233" + "445566778899aabbccddeeff"
public let TEST_HEX_32_00112233445566778899AABBCCDDEEFF_00112233445566778899AABBCCDDEEFF: String =
    "0011" + "2233" + "445566778899aabbccddeeff00112233445566778899aabbccddeeff"
public let TEST_HEX_ASCII_303132333435363738393A3B3C3D3E3F: String =
    "3031" + "3233" + "3435363738393a3b3c3d3e3f"

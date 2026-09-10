package chui.host

/** Stable ABI version for the minimal iOS host bootstrap surface. */
public func iosHostAbiVersion(): Int64 {
    1
}

/** C-callable bootstrap probe used by Xcode hosts before renderer startup. */
@C
public func canghui_ios_host_abi_version(): Int64 {
    iosHostAbiVersion()
}

/** Compatibility alias retained for hosts built against the adopted upstream identity. */
@C
public func cangjiegui_ios_host_abi_version(): Int64 {
    iosHostAbiVersion()
}

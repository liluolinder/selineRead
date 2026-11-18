package seline.book.read;

/**
 * Loads the bundled OpenSSL 3 shared objects on Android.
 *
 * The standard OpenSSL build references __errno_location (musl/glibc), which
 * bionic does not provide. liberrno_shim.so supplies that symbol, then
 * libcrypto.so / libssl.so are loaded with RTLD_GLOBAL so the stdx TLS loader
 * can resolve them by SONAME.
 */
public final class OpenSslPreload {
    static {
        System.loadLibrary("openssl_preload");
    }

    private OpenSslPreload() {
    }

    public static native boolean load(String nativeLibraryDir);
}

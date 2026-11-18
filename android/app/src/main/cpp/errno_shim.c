#include <errno.h>
#include <fcntl.h>
#include <stddef.h>
#include <string.h>
#include <unistd.h>

// Compatibility symbols for an OpenSSL 3 build produced against a
// musl/glibc-like libc. Android's bionic does not export these names.
// The library is loaded with RTLD_GLOBAL before libcrypto.so / libssl.so.

int bcmp(const void* lhs, const void* rhs, size_t count) {
    return memcmp(lhs, rhs, count);
}

extern int __cxa_atexit(void (*)(void*), void*, void*);

int atexit(void (*function)(void)) {
    return __cxa_atexit((void (*)(void*))function, 0, 0);
}

void __at_fini(void) {
}

void __register_frame_info(const void* begin, void* object) {
    (void)begin;
    (void)object;
}

void __deregister_frame_info(const void* begin) {
    (void)begin;
}

// Fortify-style descriptor check used by the OpenSSL build. There is no
// bionic equivalent; return the descriptor unchanged.
int __fd_chk(int fd, ...) {
    return fd;
}

int getentropy(void* buffer, size_t length) {
    int fd = open("/dev/urandom", O_RDONLY);
    if (fd < 0) {
        return -1;
    }
    size_t done = 0;
    while (done < length) {
        ssize_t n = read(fd, (unsigned char*)buffer + done, length - done);
        if (n <= 0) {
            close(fd);
            return -1;
        }
        done += (size_t)n;
    }
    close(fd);
    return 0;
}



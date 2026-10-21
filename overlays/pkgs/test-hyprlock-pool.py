"""Exercise the actual patched allocation helper without starting a lock screen."""

import os
from pathlib import Path
import subprocess
import sys
import tempfile


source = Path(sys.argv[1]).read_text()
start = source.index("int createPoolFile(")
end = source.index("\n}\n", start) + 3
helper = source[start:end]

harness = r"""
#include <cassert>
#include <cerrno>
#include <cstdlib>
#include <cstring>
#include <fcntl.h>
#include <filesystem>
#include <iostream>
#include <string>
#include <sys/mman.h>
#include <sys/stat.h>
#include <unistd.h>

// The helper's only project dependency is logging.
namespace Log {
    constexpr int CRIT = 0;
    struct Logger {
        template<typename... Args> void log(int, const char*, Args...) {}
    };
    Logger instance;
    Logger* logger = &instance;
}

static int allocationError = 0;
static int interruptions = 0;
static int allocationFD = -1;
extern "C" int __real_posix_fallocate(int, off_t, off_t);
extern "C" int __wrap_posix_fallocate(int fd, off_t offset, off_t length) {
    allocationFD = fd;
    if (interruptions > 0) {
        --interruptions;
        return EINTR;
    }
    return allocationError ? allocationError : __real_posix_fallocate(fd, offset, length);
}

@HELPER@

int main() {
    const std::string runtime = getenv("XDG_RUNTIME_DIR");
    constexpr size_t size = 1024 * 1024;
    std::string name;
    auto capture = [&] {
        allocationFD = -1;
        const int fd = createPoolFile(size, name);
        assert(fd >= 0);
        assert(allocationFD == fd);
        assert((fcntl(fd, F_GETFD) & FD_CLOEXEC) != 0);
        struct stat info;
        assert(fstat(fd, &info) == 0);
        assert(info.st_size == size);
        assert(info.st_nlink == 0);
        assert(!std::filesystem::exists(name));

        // A consumer can still map and fill the anonymous file, including
        // after its descriptor closes. No display or screenshot is involved.
        void* pixels = mmap(nullptr, size, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
        assert(pixels != MAP_FAILED);
        assert(close(fd) == 0);
        memset(pixels, 0xa5, size);
        assert(static_cast<unsigned char*>(pixels)[size - 1] == 0xa5);
        assert(munmap(pixels, size) == 0);
        assert(std::filesystem::is_empty(runtime));
    };

    for (int i = 0; i < 16; ++i)
        capture();

    interruptions = 2;
    capture();
    assert(interruptions == 0);

    // ENOSPC must reject the buffer before it can be handed to Hyprland,
    // releasing both its descriptor and its directory entry.
    allocationError = ENOSPC;
    allocationFD = -1;
    assert(createPoolFile(size, name) == -1);
    assert(allocationFD >= 0);
    assert(fcntl(allocationFD, F_GETFD) == -1 && errno == EBADF);
    assert(std::filesystem::is_empty(runtime));

    unsetenv("XDG_RUNTIME_DIR");
    assert(createPoolFile(size, name) == -1);
    std::cout << "SHM pool: repeated capture, mapping lifetime, EINTR, ENOSPC, and missing runtime passed\n";
}
"""

with tempfile.TemporaryDirectory(prefix="hyprlock-pool-test-") as directory:
    directory = Path(directory)
    cpp = directory / "test.cpp"
    cpp.write_text(harness.replace("@HELPER@", helper))
    executable = directory / "test"
    subprocess.run(
        [os.environ.get("CXX", "c++"), "-std=c++17", "-Wall", "-Wextra", "-Werror",
         str(cpp), "-Wl,--wrap=posix_fallocate", "-o", str(executable)],
        check=True,
    )
    runtime = directory / "runtime"
    runtime.mkdir()
    subprocess.run(
        [str(executable)], env={**os.environ, "XDG_RUNTIME_DIR": str(runtime)}, check=True,
    )

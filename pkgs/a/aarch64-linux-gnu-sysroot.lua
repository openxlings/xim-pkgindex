package = {
    spec = "2",
    homepage = "https://www.gnu.org/software/libc/",

    name = "aarch64-linux-gnu-sysroot",
    description = "glibc 2.44.3 sysroot for aarch64-linux-gnu (arm64) for compiling and linking, with the kernel headers, libc++ and its std module sources, and gcc's libgcc",

    maintainers = {"https://github.com/xlings-res/aarch64-linux-gnu-sysroot"},
    licenses = {"LGPL-2.1-or-later", "Apache-2.0 WITH LLVM-exception"},
    repo = "https://github.com/xlings-res/aarch64-linux-gnu-sysroot",
    docs = "https://github.com/mcpp-community/mcpp/blob/main/docs/22-target-side.md",

    type = "package",
    -- Host arches, not target ones: the payload is target code and one archive
    -- serves every host.
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"library", "sysroot", "libc"},
    keywords = {"glibc", "sysroot", "libc", "libc++", "cross", "linux"},

    xvm_enable = true,

    -- No programs: a sysroot, not a tool. `config()` registers only the
    -- umbrella node so `xlings use aarch64-linux-gnu-sysroot@<ver>` works.
    --
    -- Assembled by `.agents/tools/build-aarch64-linux-gnu-sysroot.py` from
    -- published payloads, every input digest-pinned by the script: glibc
    -- 2.44.3-r4 (headers, libraries, lib/ld-linux-aarch64.so.1, crt objects,
    -- the C library's static archives), linux-headers 5.11.1 (linux, asm of
    -- arm64, asm-generic, scsi, drm, rdma, misc, mtd), the llvm 23.1.3
    -- linux-aarch64 carve's libc++ (include/c++/v1, lib/aarch64-unknown-
    -- linux-gnu: libc++, libc++abi, libunwind, libatomic), compiler-rt's
    -- builtins and share/libc++'s std module sources, and gcc 15.1.0's own
    -- libgcc/crtbegin/crtend objects from the aarch64-linux-musl-gcc payload
    -- (C-library-agnostic; musl-cross builds no libgcc_s, so the row that
    -- names this sysroot links libgcc statically). libc.so and libm.so are
    -- rewritten sysroot-relative -- a sysroot needs no install-time
    -- relocation, which the host glibc package's 255-byte placeholder exists
    -- for. MEASURED: clang --target=aarch64-unknown-linux-gnu
    -- --sysroot=<payload> -static-libgcc links, and the program runs under
    -- qemu-aarch64 -L <payload> with its exit code intact.
    --
    -- The version is glibc's; the asset name carries -r<N> for corrective
    -- repacks of the same inputs (the first published 2.44.3 archive named
    -- its manifest wrongly; -r1 is the correction, and the recipe pins the
    -- explicit URL rather than the ${version} template for the same reason
    -- glibc's own 2.39 entry does).

    xpm = {
        source = {
            GLOBAL = "https://github.com/xlings-res/aarch64-linux-gnu-sysroot/releases/download/${version}/aarch64-linux-gnu-sysroot-${version}.tar.xz",
            CN = "https://gitcode.com/xlings-res/aarch64-linux-gnu-sysroot/releases/download/${version}/aarch64-linux-gnu-sysroot-${version}.tar.xz",
        },
        linux = {
            ["latest"] = { ref = "2.44.3" },
            ["2.44.3"] = {
                url = {
                    GLOBAL = "https://github.com/xlings-res/aarch64-linux-gnu-sysroot/releases/download/2.44.3/aarch64-linux-gnu-sysroot-2.44.3-r1.tar.xz",
                    CN = "https://gitcode.com/xlings-res/aarch64-linux-gnu-sysroot/releases/download/2.44.3/aarch64-linux-gnu-sysroot-2.44.3-r1.tar.xz",
                },
                sha256 = "238017f88ee0fc880ccbbdd72bb6b44cc5a8e48d39e5cc1c0064cf8155a366cb",
            },
        },
        macosx = {
            ["latest"] = { ref = "2.44.3" },
            ["2.44.3"] = {
                url = {
                    GLOBAL = "https://github.com/xlings-res/aarch64-linux-gnu-sysroot/releases/download/2.44.3/aarch64-linux-gnu-sysroot-2.44.3-r1.tar.xz",
                    CN = "https://gitcode.com/xlings-res/aarch64-linux-gnu-sysroot/releases/download/2.44.3/aarch64-linux-gnu-sysroot-2.44.3-r1.tar.xz",
                },
                sha256 = "238017f88ee0fc880ccbbdd72bb6b44cc5a8e48d39e5cc1c0064cf8155a366cb",
            },
        },
        windows = {
            ["latest"] = { ref = "2.44.3" },
            ["2.44.3"] = {
                url = {
                    GLOBAL = "https://github.com/xlings-res/aarch64-linux-gnu-sysroot/releases/download/2.44.3/aarch64-linux-gnu-sysroot-2.44.3-r1.tar.xz",
                    CN = "https://gitcode.com/xlings-res/aarch64-linux-gnu-sysroot/releases/download/2.44.3/aarch64-linux-gnu-sysroot-2.44.3-r1.tar.xz",
                },
                sha256 = "238017f88ee0fc880ccbbdd72bb6b44cc5a8e48d39e5cc1c0064cf8155a366cb",
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")

function config()
    xvm.add(package.name)
    return true
end

function uninstall()
    xvm.remove(package.name)
    return true
end

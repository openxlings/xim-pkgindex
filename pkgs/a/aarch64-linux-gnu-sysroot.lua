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
    -- Revision 2 (same version key, new asset, the glibc 2.44.3 form):
    -- r1 compiled but could not link a program -- its manifest named no
    -- compiler_runtime_dir (so clang's link read the llvm payload's resource
    -- directory and found no aarch64 builtins there), its llvm carve lacked
    -- the per-target include directory (whose __config_site every libc++
    -- include reaches first), and its run-time archives sat only in llvm's
    -- triple directory where the link's -B/-L words do not look. Revision 2
    -- adds the three; MEASURED end to end with the engine that declares the
    -- row: a plain C program builds for aarch64-linux-gnu as a dynamic ELF
    -- and runs under qemu-aarch64 -L <payload> with its exit code (7)
    -- intact. The r1 assets stay published unchanged; a client that
    -- implements revision reinstalls and says why.
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
                revision = 2,
                url = {
                    GLOBAL = "https://github.com/xlings-res/aarch64-linux-gnu-sysroot/releases/download/2.44.3-r2/aarch64-linux-gnu-sysroot-2.44.3-r2.tar.xz",
                    CN = "https://gitcode.com/xlings-res/aarch64-linux-gnu-sysroot/releases/download/2.44.3-r2/aarch64-linux-gnu-sysroot-2.44.3-r2.tar.xz",
                },
                sha256 = "de7ab59692aff52a5ab118c6862e8929957fb3119fb59d5586c13b5e59bf70b4",
            },
        },
        macosx = {
            ["latest"] = { ref = "2.44.3" },
            ["2.44.3"] = {
                revision = 2,
                url = {
                    GLOBAL = "https://github.com/xlings-res/aarch64-linux-gnu-sysroot/releases/download/2.44.3-r2/aarch64-linux-gnu-sysroot-2.44.3-r2.tar.xz",
                    CN = "https://gitcode.com/xlings-res/aarch64-linux-gnu-sysroot/releases/download/2.44.3-r2/aarch64-linux-gnu-sysroot-2.44.3-r2.tar.xz",
                },
                sha256 = "de7ab59692aff52a5ab118c6862e8929957fb3119fb59d5586c13b5e59bf70b4",
            },
        },
        windows = {
            ["latest"] = { ref = "2.44.3" },
            ["2.44.3"] = {
                revision = 2,
                url = {
                    GLOBAL = "https://github.com/xlings-res/aarch64-linux-gnu-sysroot/releases/download/2.44.3-r2/aarch64-linux-gnu-sysroot-2.44.3-r2.tar.xz",
                    CN = "https://gitcode.com/xlings-res/aarch64-linux-gnu-sysroot/releases/download/2.44.3-r2/aarch64-linux-gnu-sysroot-2.44.3-r2.tar.xz",
                },
                sha256 = "de7ab59692aff52a5ab118c6862e8929957fb3119fb59d5586c13b5e59bf70b4",
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

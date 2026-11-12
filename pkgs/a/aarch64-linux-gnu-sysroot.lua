package = {
    spec = "2",
    homepage = "https://www.gnu.org/software/libc/",

    name = "aarch64-linux-gnu-sysroot",
    description = "glibc 2.44.3 sysroot for aarch64-linux-gnu (arm64) for compiling and linking, with the kernel headers, libc++ and its std module sources, compiler-rt's builtins and gcc's libgcc",

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
    -- Revision 3 (same version key, new asset, the same inputs): revision 2
    -- linked a C program and nothing else. Its archive's top directory was
    -- not the asset's file name without the extension; libm.a kept the
    -- install-time placeholder of the host glibc package, and libm.so had
    -- been rewritten to name it, so no C++ link and no static link resolved
    -- libm; llvm's per-target library directory was named at the library
    -- root for the archives and the `.so` names alone, so libc++.so's
    -- INPUT(libc++.so.1 ...) found nothing; the manifest stated no
    -- std-module; and `provides` named libgcc where the link takes
    -- compiler-rt. Revision 3 corrects the five, and the assembly is
    -- reproducible (two runs give the same bytes). MEASURED with the engine
    -- that declares the row's cross provider, on linux-x86_64: a C program, a
    -- C++ program over the headers and one that imports std each build for
    -- aarch64-linux-gnu dynamically and statically, name
    -- /lib/ld-linux-aarch64.so.1 as their interpreter, carry no RUNPATH and no
    -- path of the build machine, and run under qemu-aarch64 -L <payload>
    -- with their exit status.
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
                revision = 3,
                url = {
                    GLOBAL = "https://github.com/xlings-res/aarch64-linux-gnu-sysroot/releases/download/2.44.3-r3/aarch64-linux-gnu-sysroot-2.44.3-r3.tar.xz",
                    CN = "https://gitcode.com/xlings-res/aarch64-linux-gnu-sysroot/releases/download/2.44.3-r3/aarch64-linux-gnu-sysroot-2.44.3-r3.tar.xz",
                },
                sha256 = "4202782881a8349c78951259b3191d92964ffa62419d9912895ce2a8d4c6f9c1",
            },
        },
        macosx = {
            ["latest"] = { ref = "2.44.3" },
            ["2.44.3"] = {
                revision = 3,
                url = {
                    GLOBAL = "https://github.com/xlings-res/aarch64-linux-gnu-sysroot/releases/download/2.44.3-r3/aarch64-linux-gnu-sysroot-2.44.3-r3.tar.xz",
                    CN = "https://gitcode.com/xlings-res/aarch64-linux-gnu-sysroot/releases/download/2.44.3-r3/aarch64-linux-gnu-sysroot-2.44.3-r3.tar.xz",
                },
                sha256 = "4202782881a8349c78951259b3191d92964ffa62419d9912895ce2a8d4c6f9c1",
            },
        },
        windows = {
            ["latest"] = { ref = "2.44.3" },
            ["2.44.3"] = {
                revision = 3,
                url = {
                    GLOBAL = "https://github.com/xlings-res/aarch64-linux-gnu-sysroot/releases/download/2.44.3-r3/aarch64-linux-gnu-sysroot-2.44.3-r3.tar.xz",
                    CN = "https://gitcode.com/xlings-res/aarch64-linux-gnu-sysroot/releases/download/2.44.3-r3/aarch64-linux-gnu-sysroot-2.44.3-r3.tar.xz",
                },
                sha256 = "4202782881a8349c78951259b3191d92964ffa62419d9912895ce2a8d4c6f9c1",
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")

-- What a C link, a C++ link and `import std` each read first, by the names
-- that are files of the archive on every host (the names beside them at the
-- library root are links). A payload without one of them is not this
-- package, whatever its digest says.
local required = {
    "mcpp.toml",
    "lib/crt1.o", "lib/libc.so.6", "lib/libm.a", "lib/ld-linux-aarch64.so.1",
    "lib/aarch64-unknown-linux-gnu/libc++.a", "lib/aarch64-unknown-linux-gnu/libc++.so.1.0",
    "lib/aarch64-unknown-linux-gnu/libunwind.a",
    "lib/clang/23/lib/aarch64-unknown-linux-gnu/libclang_rt.builtins.a",
    "include/aarch64-unknown-linux-gnu/c++/v1/__config_site",
    "share/libc++/v1/std.cppm",
}

-- The archive's top directory is the asset's file name without its extension;
-- it becomes the install directory, so the package root is the sysroot. Said
-- here and not left to the client's default unwrapping, which recognises
-- `<name>-<version>` and nests a revision's directory inside the install
-- directory (measured in CI: revision 3 installed "successfully" one level
-- too deep, and only the recipe's own verify tests said so).
function install()
    local dir = pkginfo.install_dir()
    os.tryrm(dir)
    local extracted = pkginfo.install_file():replace(".tar.xz", "")
    if not os.isdir(extracted) then
        raise("aarch64-linux-gnu-sysroot payload not found at " .. extracted)
    end
    os.mv(extracted, dir)
    for _, f in ipairs(required) do
        if not os.isfile(path.join(dir, f)) then
            raise("aarch64-linux-gnu-sysroot payload is missing " .. f)
        end
    end
    return true
end

function config()
    xvm.add(package.name)
    return true
end

function uninstall()
    xvm.remove(package.name)
    return true
end

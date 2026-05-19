package = {
    spec = "1",

    homepage = "https://gcc.gnu.org",
    name = "gcc-runtime",
    description = "GCC runtime libraries (libstdc++, libgcc_s, libgomp, libatomic, libitm, libquadmath, libssp) — required by virtually every C++ binary on Linux, including Clang-built ones",

    authors = {"GNU"},
    licenses = {"GPL-3.0-with-GCC-exception", "LGPL-2.1+"},
    repo = "https://gcc.gnu.org/git/?p=gcc.git",
    docs = "https://gcc.gnu.org/onlinedocs/libstdc++/",

    type = "package",
    archs = {"x86_64"},
    status = "stable",
    categories = {"libc++", "runtime", "lib"},
    keywords = {"libstdc++", "libgcc", "gcc-runtime", "cxx-runtime"},

    -- Pure runtime library bundle: no executables to shim, so no
    -- `programs` and no `xvm_enable`. Consumers (ninja, cmake, node, ...)
    -- pick up the lib64 dir via xlings predicate-driven elfpatch — see
    -- `exports.runtime.libdirs` below.
    --
    -- Why a separate package instead of leaving callers depending on
    -- xim:gcc:
    --   * xim:gcc is the full compiler (~1.1 GB)
    --   * The runtime libs are ~25 MB
    --   * Tools that only need to *run* C++ binaries (ninja, cmake,
    --     node, mdbook, fd, ...) don't need cc1/cc1plus/headers/*.a
    --   * libstdc++ is forward-compatible; one gcc-runtime version
    --     covers every binary built against an equal-or-older GCC

    xpm = {
        linux = {
            -- Tracks GCC main version. libstdc++ ABI is forward-
            -- compatible (versioned symbols GLIBCXX_3.4.x), so a single
            -- modern gcc-runtime covers all consumers.
            ["latest"] = { ref = "15.1.0" },
            ["15.1.0"] = "XLINGS_RES",

            deps = {
                runtime = { "xim:glibc@2.39" },
            },
            exports = {
                runtime = {
                    -- xlings install-time elfpatch reads this and
                    -- appends `<install_dir>/lib64` to consumers' RPATH
                    -- so libstdc++.so.6 / libgcc_s.so.1 / ... resolve
                    -- without the consumer hardcoding paths. Per the
                    -- libxpkg ExportsRuntime schema (xpkg.cppm), the
                    -- field for lib search dirs is `libdirs` (string
                    -- list). `abi` is reserved for a single-string ABI
                    -- disambiguation tag (e.g. "linux-x86_64-glibc"),
                    -- only meaningful when multiple libc providers
                    -- coexist — gcc-runtime doesn't need it.
                    libdirs = { "lib64" },
                },
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")

function install()
    -- Tarball extracts to gcc-runtime-<ver>-linux-x86_64/lib64/. Move
    -- the whole tree to install_dir as-is; the .so RPATHs were stripped
    -- at build time, so the consumer's RPATH (set by elfpatch via
    -- exports.runtime.libdirs) is what ld.so uses to resolve transitive
    -- deps (libc/libm via xim:glibc).
    local srcdir = pkginfo.install_file():replace(".tar.gz", "")
    os.tryrm(pkginfo.install_dir())
    os.mv(srcdir, pkginfo.install_dir())
    return true
end

function config()
    xvm.add(package.name)
    return true
end

function uninstall()
    return true
end

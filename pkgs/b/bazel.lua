package = {
    spec = "1",
    homepage = "https://bazel.build",

    name = "bazel",
    description = "Bazel — a fast, scalable, multi-language and extensible build system",
    authors = {"The Bazel Authors"},
    licenses = {"Apache-2.0"},
    repo = "https://github.com/bazelbuild/bazel",
    docs = "https://bazel.build/docs",
    ci = { update = true },

    type = "package",

    -- x86_64 only, and the reason is a dependency-resolution constraint rather
    -- than an upstream gap: bazel publishes linux-arm64 / darwin-arm64 /
    -- windows-arm64 assets too.
    --
    -- The linux binary is glibc-dynamic (measured below), so it needs
    -- `xim:glibc` and `xim:gcc-runtime`. xim resolves deps PER-OS, not per-arch
    -- (the same constraint ninja.lua records), and both of those packages are
    -- `archs = {"x86_64"}` — so declaring them while also claiming aarch64 would
    -- make every linux/aarch64 install fail at dependency resolution rather than
    -- at a missing asset. Adding aarch64 is a follow-up gated on aarch64 payloads
    -- for glibc + gcc-runtime; the macOS and Windows arm64 assets have no such
    -- blocker and can be added independently.
    archs = {"x86_64"},
    status = "stable",
    categories = {"build-system", "tools"},
    keywords = {"bazel", "build", "buildsystem", "starlark", "monorepo"},

    programs = {"bazel"},
    xvm_enable = true,

    -- WHY THIS PACKAGE EXISTS
    --
    -- Build-engine benchmarking (mcpp-community/mcpp `bench/`) compares mcpp
    -- against the mainstream engines on the same C++ sources. cmake, ninja,
    -- meson and xmake were already in this index; bazel was the one named
    -- comparison point with no way to install it from xlings.
    --
    -- SHAPE — a single 66 MB self-extracting binary, not an archive. It carries
    -- its own JDK and unpacks into the user's cache on first run; there is no
    -- external JDK dependency to declare. Verified locally:
    --
    --     $ ./bazel-9.2.0-linux-x86_64 --version
    --     bazel 9.2.0
    --     $ ./bazel-9.2.0-linux-x86_64 --help
    --     Extracting Bazel installation...
    --     OpenJDK 64-Bit Server VM warning: ...      <- its own bundled JVM
    --
    -- NOT musl-static, and there is no upstream musl build. Measured with
    -- readelf on bazel-9.2.0-linux-x86_64:
    --
    --     Type: EXEC (non-PIE)
    --     NEEDED: librt.so.1, libdl.so.2, libpthread.so.0, libm.so.6,
    --             libstdc++.so.6, libgcc_s.so.1, libc.so.6
    --
    -- Hence the two runtime deps below: glibc supplies libc/libm/librt/libdl/
    -- libpthread, gcc-runtime supplies libstdc++.so.6 + libgcc_s.so.1. In form H
    -- those resolve from the host and the deps look redundant; in form X there is
    -- no host fallback and they are exactly what keeps the closure complete
    -- (ecosystem-closure rule D).
    --
    -- bazelisk is deliberately NOT used as the payload. It is a Go static binary
    -- and would look like the musl-friendly choice, but it is only a launcher:
    -- it downloads this same glibc-dynamic bazel at first run, moving the same
    -- dependency to a place where the index cannot declare it, and adding a
    -- network fetch to every cold environment.
    -- GLOBAL points at upstream bazelbuild rather than an xlings-res copy: the
    -- release assets are large (57-66 MB each) and upstream is already a stable,
    -- checksummed source, so mirroring them a second time on GitHub buys
    -- immutability we can get from the pinned sha256 instead. CN is a real
    -- mirror, because that is the leg where reaching GitHub is the problem.
    --
    -- The CN assets were uploaded with `gtc release upload` and each was then
    -- re-downloaded and compared against the upstream bytes — the sha256 below
    -- is the SAME value for both legs by construction.
    xpm = {
        linux = {
            deps = {
                runtime = { "xim:glibc", "xim:gcc-runtime" },
            },
            ["latest"] = { ref = "9.2.0" },
            ["9.2.0"] = {
                url = {
                    GLOBAL = "https://github.com/bazelbuild/bazel/releases/download/9.2.0/bazel-9.2.0-linux-x86_64",
                    CN     = "https://gitcode.com/xlings-res/bazel/releases/download/9.2.0/bazel-9.2.0-linux-x86_64",
                },
                sha256 = "7668a95db1250f12c40407251e4e203b4ec8bf39bc495d2f485b2d8c99048694",
            },
        },
        macosx = {
            ["latest"] = { ref = "9.2.0" },
            ["9.2.0"] = {
                url = {
                    GLOBAL = "https://github.com/bazelbuild/bazel/releases/download/9.2.0/bazel-9.2.0-darwin-x86_64",
                    CN     = "https://gitcode.com/xlings-res/bazel/releases/download/9.2.0/bazel-9.2.0-darwin-x86_64",
                },
                sha256 = "14c9bcb01303b38192e0e2895051c1bcf19bf89d7e416f5aeeeb48b6b624cfbf",
            },
        },
        windows = {
            ["latest"] = { ref = "9.2.0" },
            ["9.2.0"] = {
                url = {
                    GLOBAL = "https://github.com/bazelbuild/bazel/releases/download/9.2.0/bazel-9.2.0-windows-x86_64.exe",
                    CN     = "https://gitcode.com/xlings-res/bazel/releases/download/9.2.0/bazel-9.2.0-windows-x86_64.exe",
                },
                sha256 = "5fc2f2805b8c697a54732558576938d06bab63aa0f9b6610cc01d2cae0388705",
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")

function install()
    -- The download is the program itself; there is nothing to extract.
    os.tryrm(pkginfo.install_dir())
    os.mkdir(pkginfo.install_dir())

    local exe_name = is_host("windows") and "bazel.exe" or "bazel"
    if not is_host("windows") then
        os.exec("chmod +x " .. pkginfo.install_file())
    end

    os.mv(pkginfo.install_file(), path.join(pkginfo.install_dir(), exe_name))
    return true
end

function config()
    -- Explicit bindir, matching bat.lua / fzf.lua. (A bare `xvm.add("bazel")`
    -- also works — this is convention, not a fix.)
    xvm.add("bazel", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("bazel")
    return true
end

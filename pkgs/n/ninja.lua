package = {
    spec = "1",
    -- base info
    name = "ninja",
    description = "a small build system with a focus on speed",

    maintainers = {"https://github.com/ninja-build/ninja/graphs/contributors"},
    licenses = {"Apache-2.0"},
    repo = "https://github.com/ninja-build/ninja",
    docs = "https://ninja-build.org/manual.html",

    -- xim pkg info
    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable", -- dev, stable, deprecated
    categories = {"build-system", "ninja"},
    keywords = {"ninja", "build-system", "cross-platform"},

    -- xvm: xlings version management
    xvm_enable = true,

    xpm = {
        linux = {
            -- Self-contained, no runtime deps (mirrors patchelf.lua, the other
            -- bootstrap tool). Both Linux assets are statically linked, so they
            -- carry their own libc/libstdc++ and need no INTERP/RPATH patching:
            --   x86_64  → ninja-1.12.1-linux-x86_64.tar.gz   (glibc-static)
            --   aarch64 → ninja-1.12.1-linux-aarch64.tar.gz  (musl-static)
            -- This is why no glibc/gcc-runtime deps are declared: xim resolves
            -- deps per-OS (not per-arch), so a glibc dep would 404 on aarch64
            -- (no glibc asset for arm). A static ninja sidesteps that entirely
            -- and is the right shape for a bootstrap build tool regardless.
            ["latest"] = { ref = "1.12.1" },
            ["1.12.1"] = "XLINGS_RES",
        },
        macosx = {
            ["latest"] = { ref = "1.12.1" },
            ["1.12.1"] = "XLINGS_RES",
        },
        windows = {
            ["latest"] = { ref = "1.12.1" },
            ["1.12.1"] = "XLINGS_RES",
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")

function install()
    -- XLINGS_RES ships the platform-native binary: `ninja` on Linux/macOS,
    -- `ninja.exe` on Windows. Handle both forms so the move doesn't fail
    -- on a fresh Windows install where the source file has the extension.
    local exe = is_host("windows") and "ninja.exe" or "ninja"
    os.mv(exe, path.join(pkginfo.install_dir(), exe))
    return true
end

function config()
    xvm.add("ninja")
    return true
end

function uninstall()
    xvm.remove("ninja")
    return true
end
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
            -- A CHECKSUM, BECAUSE "ninja 1.12.1" HAS NAMED MORE THAN ONE
            -- BINARY ON MORE THAN ONE MACHINE.
            --
            -- Measured 2026-09-04: two installs at the same package path and
            -- the same version, one 2202320 bytes and statically linked (what
            -- the asset above contains, BuildID 787c36ad…), the other 273768
            -- bytes and dynamically linked against a 2014-era glibc — the shape
            -- of upstream's own `ninja-linux.zip`. Their SHA-256 differ and both
            -- answer `--version` with 1.12.1.
            --
            -- WHERE THE SECOND ONE CAME FROM IS NOT ESTABLISHED. What is
            -- established is that nothing here would have said so: a bare
            -- `XLINGS_RES` entry carries no checksum, so whatever the asset
            -- happens to be is what is installed, and two machines can disagree
            -- with nothing to notice. A build tool is the wrong place for that:
            -- ninja is what every other package is built WITH.
            ["latest"] = { ref = "1.12.1" },
            ["1.12.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64  = "0508ca82eb54792f5a416b5e2fbb7bc6b94e355bb715019276c37c78a30f8d32",
                    aarch64 = "5ccb8b80267f2ab9d22c2fbe868f36ccef9462af99652995e9efad16f27d631a",
                },
            },
        },
        macosx = {
            ["latest"] = { ref = "1.12.1" },
            ["1.12.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    aarch64 = "6b50dbcafd7304101a1e72ab50f08f0be6c7e5a882e833a6a21d927aa7b3e617",
                },
            },
        },
        windows = {
            ["latest"] = { ref = "1.12.1" },
            ["1.12.1"] = {
                url = "XLINGS_RES",
                sha256 = {
                    x86_64 = "f550fec705b6d6ff58f2db3c374c2277a37691678d6aba463adcbb129108467a",
                },
            },
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
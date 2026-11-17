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



    extensions = {
        autoupdate = {
            source = "https://github.com/xlings-res/ninja/releases",
            resources = {
                GLOBAL = {
                    url = {
                        linux = {
                            x86_64 = "https://github.com/xlings-res/ninja/releases/download/${version}/ninja-${version}-linux-x86_64.tar.gz",
                            aarch64 = "https://github.com/xlings-res/ninja/releases/download/${version}/ninja-${version}-linux-aarch64.tar.gz",
                        },
                        macosx = {
                            aarch64 = "https://github.com/xlings-res/ninja/releases/download/${version}/ninja-${version}-macosx-arm64.tar.gz",
                        },
                        windows = {
                            x86_64 = "https://github.com/xlings-res/ninja/releases/download/${version}/ninja-${version}-windows-x86_64.zip",
                        },
                    },
                    required = true,
                },
                CN = {
                    url = {
                        linux = {
                            x86_64 = "https://gitcode.com/xlings-res/ninja/releases/download/${version}/ninja-${version}-linux-x86_64.tar.gz",
                            aarch64 = "https://gitcode.com/xlings-res/ninja/releases/download/${version}/ninja-${version}-linux-aarch64.tar.gz",
                        },
                        macosx = {
                            aarch64 = "https://gitcode.com/xlings-res/ninja/releases/download/${version}/ninja-${version}-macosx-arm64.tar.gz",
                        },
                        windows = {
                            x86_64 = "https://gitcode.com/xlings-res/ninja/releases/download/${version}/ninja-${version}-windows-x86_64.zip",
                        },
                    },
                    required = true,
                },
            },
            verify = "sha256-sidecar",
        },
    },

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
            -- 1.12.1-mcpp.1 IS ANOTHER SOURCE, NOT A REVISION OF 1.12.1: ninja
            -- v1.12.1 with the first commit of ninja-build/ninja#2840, which
            -- corrects ninja-build/ninja#2662 (loading a dyndep file while an
            -- edge finishes invalidated the iterators of the loops finishing
            -- it), built from mcpp-community/ninja, branch mcpp/1.12.1. mcpp
            -- pins it. `revision` would replace what `ninja@1.12.1` and
            -- `latest` install for every consumer, so it has a key of its own;
            -- the marker reads as a prerelease, below 1.12.1, and `latest`
            -- stays. `ninja --version` answers 1.12.1-mcpp.1. The key ends
            -- when an upstream release carries the correction.
            ["1.12.1-mcpp.1"] = {
                x86_64 = {
                    url = {
                        GLOBAL = "https://github.com/xlings-res/ninja/releases/download/1.12.1-mcpp.1/ninja-1.12.1-mcpp.1-linux-x86_64.tar.gz",
                        CN     = "https://gitcode.com/xlings-res/ninja/releases/download/1.12.1-mcpp.1/ninja-1.12.1-mcpp.1-linux-x86_64.tar.gz",
                    },
                    sha256 = "248ef3a655137b4668003886faf3b3f0e0d0f5bcf90b34d4dabcae37a4889058",
                },
                aarch64 = {
                    url = {
                        GLOBAL = "https://github.com/xlings-res/ninja/releases/download/1.12.1-mcpp.1/ninja-1.12.1-mcpp.1-linux-aarch64.tar.gz",
                        CN     = "https://gitcode.com/xlings-res/ninja/releases/download/1.12.1-mcpp.1/ninja-1.12.1-mcpp.1-linux-aarch64.tar.gz",
                    },
                    sha256 = "d5a1b08eb56f0c0222e9925e572fcc65cfca863be85ce3046403f6b7387ac9bc",
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
            ["1.12.1-mcpp.1"] = {
                aarch64 = {
                    url = {
                        GLOBAL = "https://github.com/xlings-res/ninja/releases/download/1.12.1-mcpp.1/ninja-1.12.1-mcpp.1-macosx-arm64.tar.gz",
                        CN     = "https://gitcode.com/xlings-res/ninja/releases/download/1.12.1-mcpp.1/ninja-1.12.1-mcpp.1-macosx-arm64.tar.gz",
                    },
                    sha256 = "3b419ec5380a7341d33ac9950a2939e7a0345d569397879fad4af537d4289d34",
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
            ["1.12.1-mcpp.1"] = {
                x86_64 = {
                    url = {
                        GLOBAL = "https://github.com/xlings-res/ninja/releases/download/1.12.1-mcpp.1/ninja-1.12.1-mcpp.1-windows-x86_64.zip",
                        CN     = "https://gitcode.com/xlings-res/ninja/releases/download/1.12.1-mcpp.1/ninja-1.12.1-mcpp.1-windows-x86_64.zip",
                    },
                    sha256 = "4e85b62c5732ca80682358a10430a6edc18b8c52a74e601ceb03f7605501baf8",
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
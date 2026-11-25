package = {
    spec = "2",

    name = "clice",
    description = "A C/C++, Objective-C and CUDA language server built on Clang, with a CLI that shares its configuration, caches and index",

    maintainers = {"clice-io"},
    licenses = {"Apache-2.0"},
    repo = "https://github.com/clice-io/clice",
    docs = "https://docs.clice.io",

    -- xim pkg info
    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"cpp", "language-server", "lsp"},
    keywords = {"clice", "lsp", "language-server", "clang", "cpp", "clangd", "cuda"},

    programs = {"clice"},
    xvm_enable = true,

    -- Upstream GitHub releases ship one asset per platform/arch, with Rust
    -- target-triple names and a `v`-prefixed tag. Measured matrix of v1.0.0:
    -- linux x86_64+aarch64 (`-unknown-linux-gnu`), macos x86_64+aarch64
    -- (`-apple-darwin`), windows x86_64+aarch64 (`-w64-mingw32`). Every
    -- archive extracts to a fixed top-level `clice/` directory regardless of
    -- platform, so one install() covers the whole matrix. No CN mirror has
    -- been verified, so autoupdate declares GLOBAL only.
    extensions = {
        autoupdate = {
            source = "https://github.com/clice-io/clice/releases",
            resources = {
                GLOBAL = {
                    required = true,
                    url = {
                        linux = {
                            x86_64 = "https://github.com/clice-io/clice/releases/download/v${version}/clice-${version}.x86_64-unknown-linux-gnu.tar.gz",
                            aarch64 = "https://github.com/clice-io/clice/releases/download/v${version}/clice-${version}.aarch64-unknown-linux-gnu.tar.gz",
                        },
                        macosx = {
                            x86_64 = "https://github.com/clice-io/clice/releases/download/v${version}/clice-${version}.x86_64-apple-darwin.tar.gz",
                            aarch64 = "https://github.com/clice-io/clice/releases/download/v${version}/clice-${version}.aarch64-apple-darwin.tar.gz",
                        },
                        windows = {
                            x86_64 = "https://github.com/clice-io/clice/releases/download/v${version}/clice-${version}.x86_64-w64-mingw32.zip",
                            aarch64 = "https://github.com/clice-io/clice/releases/download/v${version}/clice-${version}.aarch64-w64-mingw32.zip",
                        },
                    },
                },
            },
        },
    },

    xpm = {
        linux = {
            -- bin/clice is a glibc-linked ELF whose measured DT_NEEDED closure
            -- is libdl/librt/libpthread/libm/libc (libstdc++ is statically
            -- linked in); its own symbol-version floor is GLIBC_2.16, but
            -- >=2.39 is deliberately the index's glibc baseline (glibc.lua
            -- ships 2.39 and 2.44) — there is nothing older to resolve to.
            deps = {
                runtime = {
                    "xim:glibc@>=2.39",
                },
            },
            source = "https://github.com/clice-io/clice/releases/download/v${version}/clice-${version}.${arch_alias}-unknown-linux-gnu.${ext}",
            ["latest"] = { ref = "1.0.0" },
            ["1.0.0"] = {
                arch_alias = { x86_64 = "x86_64", aarch64 = "aarch64" },
                sha256 = {
                    x86_64 = "9dd181aac9c81cae76b255e953da21c9e603fc5b406447eb26c95eaf67ed969a",
                    aarch64 = "b7eb6ce65afb9cdc5229dadf1b1a561485dcdb292a06d68857cd6097716f08ba",
                },
            },
        },
        macosx = {
            source = "https://github.com/clice-io/clice/releases/download/v${version}/clice-${version}.${arch_alias}-apple-darwin.${ext}",
            ["latest"] = { ref = "1.0.0" },
            ["1.0.0"] = {
                arch_alias = { x86_64 = "x86_64", aarch64 = "aarch64" },
                sha256 = {
                    x86_64 = "28a941dad640cf24b6d7d76477ee178353e67a8490ec7b87bfe5b612e999ece2",
                    aarch64 = "941acd6ec4c746444a54006452209cd0ef98f5a34eee5089520016c40a41f82c",
                },
            },
        },
        windows = {
            source = "https://github.com/clice-io/clice/releases/download/v${version}/clice-${version}.${arch_alias}-w64-mingw32.${ext}",
            ["latest"] = { ref = "1.0.0" },
            ["1.0.0"] = {
                arch_alias = { x86_64 = "x86_64", aarch64 = "aarch64" },
                sha256 = {
                    x86_64 = "4c236c9aa107f52ecfe958a141690364bb225feb23c9b9d967cfa1911b47dedb",
                    aarch64 = "0893adddb2969916a8a9bfdcb1957eda1687d2d989f6241d99dd74e29394d9e5",
                },
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")

-- Every upstream archive (tar.gz and zip alike) extracts to a top-level
-- `clice/` directory: bin/clice[.exe], the lib/clang resource headers and the
-- default clice.toml. install() asserts the real payload landed, because a
-- failed extraction would otherwise still report a successful install.
function install()
    os.tryrm(pkginfo.install_dir())
    os.mv("clice", pkginfo.install_dir())
    if not os.isfile(pkginfo.install_dir() .. "/bin/clice") and
       not os.isfile(pkginfo.install_dir() .. "/bin/clice.exe") then
        error("clice payload missing after install: " .. pkginfo.install_dir() .. "/bin/clice")
    end
    return true
end

function config()
    xvm.add("clice", { bindir = pkginfo.install_dir() .. "/bin" })
    return true
end

function uninstall()
    xvm.remove("clice")
    return true
end

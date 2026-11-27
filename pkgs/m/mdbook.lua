package = {

    -- Platform version sets differ ON PURPOSE:
    -- macosx has no 0.4.40 entry; the platforms' current `latest` agree.
    -- Declared so `tests/check_platform_version_parity.lua` can tell this
    -- apart from a bump that landed in one section and was forgotten in the
    -- others -- which reads as `<pkg>@<ver> not found` on the platforms that
    -- lack it, against a file that contains the version string.
    platform_versions_diverge = true,
    spec = "1",
    -- base info
    name = "mdbook",
    description = "Create book from markdown files. Like Gitbook but implemented in Rust",

    authors = {"Mathieu David", "Michael-F-Bryan", "Matt Ickstadt"},
    contributors = "https://github.com/rust-lang/mdBook/graphs/contributors",
    licenses = {"MPL-2.0"},
    repo = "https://github.com/rust-lang/mdBook",
    docs = "https://rust-lang.github.io/mdBook",

    -- xim pkg info
    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable", -- dev, stable, deprecated
    categories = {"book", "markdown"},
    keywords = {"book", "gitbook", "rustbook", "markdown"},

    -- xvm: xlings version management
    xvm_enable = true,



    extensions = {
        autoupdate = {
            source = "https://github.com/rust-lang/mdBook/releases",
            resources = {
                GLOBAL = {
                    url = {
                        windows = "https://github.com/rust-lang/mdBook/releases/download/v${version}/mdbook-v${version}-x86_64-pc-windows-msvc.zip",
                        linux = {
                            x86_64 = "https://github.com/rust-lang/mdBook/releases/download/v${version}/mdbook-v${version}-x86_64-unknown-linux-musl.tar.gz",
                            aarch64 = "https://github.com/rust-lang/mdBook/releases/download/v${version}/mdbook-v${version}-aarch64-unknown-linux-musl.tar.gz",
                        },
                        macosx = "https://github.com/rust-lang/mdBook/releases/download/v${version}/mdbook-v${version}-aarch64-apple-darwin.tar.gz",
                    },
                    required = true,
                },
            },
        },
    },

    xpm = {
        windows = {
            ["latest"] = { ref = "0.5.4" },
            ["0.5.2"] = {
                url = "https://github.com/rust-lang/mdBook/releases/download/v0.5.2/mdbook-v0.5.2-x86_64-pc-windows-msvc.zip",
                sha256 = nil
            },
            ["0.4.43"] = {
                url = "https://github.com/rust-lang/mdBook/releases/download/v0.4.43/mdbook-v0.4.43-x86_64-pc-windows-msvc.zip",
                sha256 = nil
            },
            ["0.4.40"] = {
                url = "https://gitee.com/sunrisepeak/xlings-pkg/releases/download/mdbook/mdbook-v0.4.40-x86_64-pc-windows-msvc.zip",
                sha256 = nil
            },
            ["0.5.4"] = {
                url = "https://github.com/rust-lang/mdBook/releases/download/v0.5.4/mdbook-v0.5.4-x86_64-pc-windows-msvc.zip",
                sha256 = "8a6b2421aa522de06d746871d2b8fff9c8d71773467e310a4516d2566e7f2de4",
            },
        },
        linux = {
            -- No runtime deps. Upstream rust-lang/mdBook publishes
            -- both `-linux-gnu` and `-linux-musl` Linux x86_64 builds;
            -- we use the musl variant which is `static-pie linked`
            -- with empty DT_NEEDED and no .interp section (verified
            -- locally via readelf). Hermetic — runs on Alpine /
            -- distroless without glibc or gcc-runtime.
            -- Earlier versions of this package pinned the gnu build
            -- and declared deps on xim:glibc + xim:gcc-runtime
            -- (PR #117). Switching the artifact source eliminates
            -- both deps.
            ["latest"] = { ref = "0.5.4" },
            ["0.5.2"] = {
                x86_64 = {
                    url = "https://github.com/rust-lang/mdBook/releases/download/v0.5.2/mdbook-v0.5.2-x86_64-unknown-linux-musl.tar.gz",
                    sha256 = "8e9d802bbecea34380aabfc65bec4fdba23c07453ef2c7e06fa34c282082e2c4",
                },
                aarch64 = {
                    url = "https://github.com/rust-lang/mdBook/releases/download/v0.5.2/mdbook-v0.5.2-aarch64-unknown-linux-musl.tar.gz",
                    sha256 = "fb229bfdc68dd6c93692e64c502a67a8d3d2fc35c37c61fc72768843e6476add",
                },
            },
            ["0.4.43"] = {
                x86_64 = {
                    url = "https://github.com/rust-lang/mdBook/releases/download/v0.4.43/mdbook-v0.4.43-x86_64-unknown-linux-musl.tar.gz",
                    sha256 = "3058914071a6f22dbd1b8ea734a96d8e86489743ae0bc8d6bbd9e923f191b038",
                },
                aarch64 = {
                    url = "https://github.com/rust-lang/mdBook/releases/download/v0.4.43/mdbook-v0.4.43-aarch64-unknown-linux-musl.tar.gz",
                    sha256 = "647d71951fc696adc8c499a4363bb1a21045a0c734818f077add8ec4477ad814",
                },
            },
            ["0.4.40"] = {
                x86_64 = {
                    url = "https://github.com/rust-lang/mdBook/releases/download/v0.4.40/mdbook-v0.4.40-x86_64-unknown-linux-musl.tar.gz",
                    sha256 = "f7520ad60d1a6fe81c667d0da876a9ddd736f874eb61c01b025eafdc83381227",
                },
                aarch64 = {
                    url = "https://github.com/rust-lang/mdBook/releases/download/v0.4.40/mdbook-v0.4.40-aarch64-unknown-linux-musl.tar.gz",
                    sha256 = "d5ebfd2e31755726f8c0988a423b1ab5d950bb894fbba170355bb7d1cb852586",
                },
            },
            ["0.5.4"] = {
                x86_64 = {
                    url = "https://github.com/rust-lang/mdBook/releases/download/v0.5.4/mdbook-v0.5.4-x86_64-unknown-linux-musl.tar.gz",
                    sha256 = "5222beabd3e37dc5be0d18ff99b79058469354db5c220153a1b92db5ba12be89",
                },
                aarch64 = {
                    url = "https://github.com/rust-lang/mdBook/releases/download/v0.5.4/mdbook-v0.5.4-aarch64-unknown-linux-musl.tar.gz",
                    sha256 = "753e5c5c363ee8a56972344dcf91466f005a51db84a7aeffe427ae3ef83d6d44",
                },
            },
        },
        macosx = {
            ["latest"] = { ref = "0.5.4" },
            ["0.5.2"] = {
                url = "https://github.com/rust-lang/mdBook/releases/download/v0.5.2/mdbook-v0.5.2-aarch64-apple-darwin.tar.gz",
                sha256 = nil
            },
            ["0.4.43"] = "XLINGS_RES",
            ["0.5.4"] = {
                url = "https://github.com/rust-lang/mdBook/releases/download/v0.5.4/mdbook-v0.5.4-aarch64-apple-darwin.tar.gz",
                sha256 = "03e8a6d8b13a2971e0b3280affd03b388373c1485e26f73407c3a76b0b1838df",
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")

local mdbook_file = {
    windows = "mdbook.exe",
    linux = "mdbook",
    macosx = "mdbook"
}

function install()
    return os.trymv(mdbook_file[os.host()], pkginfo.install_dir())
end

function config()
    -- config xvm
    xvm.add("mdbook")
    return true
end

function uninstall()
    xvm.remove("mdbook")
    return true
end
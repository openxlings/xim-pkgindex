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
    archs = {"x86_64"},
    status = "stable", -- dev, stable, deprecated
    categories = {"book", "markdown"},
    keywords = {"book", "gitbook", "rustbook", "markdown"},

    -- xvm: xlings version management
    xvm_enable = true,

    xpm = {
        windows = {
            ["latest"] = { ref = "0.5.2" },
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
            ["latest"] = { ref = "0.5.2" },
            ["0.5.2"] = {
                url = "https://github.com/rust-lang/mdBook/releases/download/v0.5.2/mdbook-v0.5.2-x86_64-unknown-linux-musl.tar.gz",
                sha256 = nil
            },
            ["0.4.43"] = {
                url = "https://github.com/rust-lang/mdBook/releases/download/v0.4.43/mdbook-v0.4.43-x86_64-unknown-linux-musl.tar.gz",
                sha256 = nil
            },
            ["0.4.40"] = {
                url = "https://github.com/rust-lang/mdBook/releases/download/v0.4.40/mdbook-v0.4.40-x86_64-unknown-linux-musl.tar.gz",
                sha256 = nil
            },
        },
        macosx = {
            ["latest"] = { ref = "0.5.2" },
            ["0.5.2"] = {
                url = "https://github.com/rust-lang/mdBook/releases/download/v0.5.2/mdbook-v0.5.2-aarch64-apple-darwin.tar.gz",
                sha256 = nil
            },
            ["0.4.43"] = "XLINGS_RES",
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
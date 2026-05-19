package = {
    -- base info
    name = "mdbook",
    description = "Create book from markdown files. Like Gitbook but implemented in Rust",

    authors = "Mathieu David, Michael-F-Bryan, Matt Ickstadt",
    contributors = "https://github.com/rust-lang/mdBook/graphs/contributors",
    licenses = "MPL-2.0",
    repo = "https://github.com/rust-lang/mdBook",
    docs = "https://rust-lang.github.io/mdBook",

    -- xim pkg info
    archs = {"x86_64"},
    status = "stable", -- dev, stable, deprecated
    categories = {"book", "markdown"},
    keywords = {"book", "gitbook", "rustbook", "markdown"},

    -- xvm: xlings version management
    xvm_enable = true,

    xpm = {
        windows = {
            ["latest"] = { ref = "0.4.40" },
            ["0.4.43"] = {
                url = "https://github.com/rust-lang/mdBook/releases/download/v0.4.43/mdbook-v0.4.43-x86_64-pc-windows-msvc.zip",
                sha256 = nil
            },
            ["0.4.40"] = {
                url = "https://gitee.com/sunrisepeak/xlings-pkg/releases/download/mdbook/mdbook-v0.4.40-x86_64-pc-windows-msvc.zip",
                sha256 = nil
            },
        },
        debain = {
            ["latest"] = { ref = "0.4.43" },
            ["0.4.43"] = {
                url = "https://github.com/rust-lang/mdBook/releases/download/v0.4.43/mdbook-v0.4.43-x86_64-unknown-linux-gnu.tar.gz",
                sha256 = "d20c2f20eb1c117dc5ebeec120e2d2f6455c90fe8b4f21b7466625d8b67b9e60"
            },
            ["0.4.40"] = {
                url = "https://github.com/rust-lang/mdBook/releases/download/v0.4.40/mdbook-v0.4.40-x86_64-unknown-linux-gnu.tar.gz",
                sha256 = "9ef07fd288ba58ff3b99d1c94e6d414d431c9a61fdb20348e5beb74b823d546b"
            },
        },
        ubuntu = { ref = "debain" },
        archlinux = { ref = "debain" },
        manjaro = { ref = "debain" },
    },
}

import("xim.base.runtime")

local pkginfo = runtime.get_pkginfo()

local mdbook_file = {
    windows = "mdbook.exe",
    linux = "mdbook",
}

function installed()
    return os.iorun("xvm list mdbook")
end

function install()
    return os.trymv(mdbook_file[os.host()], pkginfo.install_dir)
end

function config()
    -- config xvm
    os.exec(format(
        "xvm add mdbook %s --path %s",
        pkginfo.version, pkginfo.install_dir
    ))
    return true
end

function uninstall()
    os.exec("xvm remove mdbook " .. pkginfo.version)
    return true
end
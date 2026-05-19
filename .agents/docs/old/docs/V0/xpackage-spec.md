> **⚠️ 本文档已废弃。** 请使用 [V1 规范](../V1/xpackage-spec.md)。V0 使用的 `import("xim.base.runtime")` 和 `os.exec("xvm add ...")` 已被替换为 `import("xim.libxpkg.pkginfo")` 和 `xvm.add()` API。

# [已废弃] XPackage Spec & Example

## XPackage Spec

> format: `name-maintainer.lua`

```lua
package = {
    -- base info
    homepage = "https://example.com",

    name = "package-name",
    description = "Package description",

    authors = "Author Name",
    maintainers = "Maintainer Name or url",
    contributors = "Contributor Name or url",
    licenses = "MIT",
    repo = "https://example.com/repo",
    docs = "https://example.com/docs",

    -- xim pkg info
    type = "package", -- package, config
    archs = {"x86_64"},
    status = "stable", -- dev, stable, deprecated
    categories = {"category1", "category2"},
    keywords = {"keyword1", "keyword2"},
    date = "2024-12-01",

    -- env info - todo
    xvm_type = "", -- unused
    xvm_support = false, -- unused
    xvm_default = false,

    xpm = {
        windows = {
            deps = {"dep1", "dep2"},
            ["1.0.1"] = {"url", "sha256"},
            ["1.0.0"] = {"url", "sha256"},
        },
        ubuntu = {
            deps = {"dep3", "dep4"},
            ["latest"] = { ref = "1.0.1"},
            ["1.0.1"] = {"url", "sha256"},
            ["1.0.0"] = {"url", "sha256"},
        },
    },
}

-- xim: hooks for package manager

import("xim.base.runtime")

-- pkginfo = runtime.get_pkginfo()
-- pkginfo = {install_file = "", version = "x.x.x"}

-- step 1: support check - package attribute

-- step 2: installed check
function installed()
    print("xpackage-spec: installed")
    return true
end

-- step 2.5: download resources/package
-- step 3: process dependencies - package attribute

-- step 4: build package
function build()
    print("xpackage-spec: build")
    return true
end

-- step 5: install package
function install()
    print("xpackage-spec: install")
    return true
end

-- step 6: configure package
function config()
    print("xpackage-spec: config")
    return true
end

-- step 7: uninstall package
function uninstall()
    print("xpackage-spec: uninstall")
    return true
end
```

## Examples

> mdbook's xpakcage file - [latest](https://github.com/openxlings/xim-pkgindex/blob/main/pkgs/m/mdbook.lua)

```lua
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
```
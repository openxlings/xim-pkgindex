local _rustup_tpl = "https://static.rust-lang.org/rustup/archive/%s/%s/rustup-init"

package = {
    spec = "1",

    homepage = "https://rustup.rs",

    -- base info
    name = "rustup",
    description = "An installer init tool for Rustup, the Rust toolchain installer",

    licenses = {"MIT", "Apache-2.0"},
    repo = "https://github.com/rust-lang/rustup",
    docs = "https://rust-lang.github.io/rustup/installation/other.html",

    -- xim pkg info
    type = "package",
    archs = {"x86_64"},
    status = "stable", -- dev, stable, deprecated
    categories = {"rust", "toolchain"},
    keywords = {"rust", "cross-platform", "version-management"},
    programs = {"rustup-init"},

    xpm = {
        windows = {
            ["latest"] = { ref = "1.28.2" },
            ["1.28.2"] = {
                url = string.format(_rustup_tpl, "1.28.2", "x86_64-pc-windows-msvc") .. ".exe",
                sha256 = nil,
            }
        },
        linux = {
            ["latest"] = { ref = "1.28.2" },
            ["1.28.2"] = {
                url = string.format(_rustup_tpl, "1.28.2", "x86_64-unknown-linux-gnu"),
                sha256 = nil,
            }
        },
        macosx = {
            ["latest"] = { ref = "1.28.2" },
            ["1.28.2"] = {
                url = string.format(_rustup_tpl, "1.28.2", "x86_64-apple-darwin"),
                sha256 = nil,
            }
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.libxpkg.system")

local rustup_init_file = {
    windows = "rustup-init.exe",
    linux = "rustup-init",
    macosx = "rustup-init"
}

function installed()
    return xvm.has("rustup-init")
end

function install()
    if os.host() == "linux" or os.host() == "macosx" then
        system.exec("chmod +x " .. rustup_init_file[os.host()])
    end
    os.mv(rustup_init_file[os.host()], pkginfo.install_dir())
    return true
end

function config()
    xvm.add("rustup-init")
    -- Group placeholder: the package ships only the `rustup-init` bootstrap
    -- binary, but xlings searches for a `rustup` entry on `xim:rustup`
    -- install detection. Empty placeholder so the lookup succeeds.
    xvm.add("rustup", { type = "group" })
    return true
end

function uninstall()
    xvm.remove("rustup-init")
    xvm.remove("rustup")
    return true
end

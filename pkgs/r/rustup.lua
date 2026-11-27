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
    archs = {"x86_64", "aarch64"},
    status = "stable", -- dev, stable, deprecated
    categories = {"rust", "toolchain"},
    keywords = {"rust", "cross-platform", "version-management"},
    programs = {"rustup-init"},

    extensions = {
        autoupdate = {
            source = "https://github.com/rust-lang/rustup/releases",
            resources = {
                GLOBAL = {
                    url = {
                        linux = {
                            x86_64 = "https://static.rust-lang.org/rustup/archive/${version}/x86_64-unknown-linux-gnu/rustup-init",
                            aarch64 = "https://static.rust-lang.org/rustup/archive/${version}/aarch64-unknown-linux-gnu/rustup-init",
                        },
                        macosx = "https://static.rust-lang.org/rustup/archive/${version}/x86_64-apple-darwin/rustup-init",
                        windows = "https://static.rust-lang.org/rustup/archive/${version}/x86_64-pc-windows-msvc/rustup-init.exe",
                    },
                    required = true,
                },
                CN = {
                    url = {
                        linux = {
                            x86_64 = "https://mirrors.ustc.edu.cn/rust-static/rustup/archive/${version}/x86_64-unknown-linux-gnu/rustup-init",
                            aarch64 = "https://mirrors.ustc.edu.cn/rust-static/rustup/archive/${version}/aarch64-unknown-linux-gnu/rustup-init",
                        },
                        macosx = "https://mirrors.ustc.edu.cn/rust-static/rustup/archive/${version}/x86_64-apple-darwin/rustup-init",
                        windows = "https://mirrors.ustc.edu.cn/rust-static/rustup/archive/${version}/x86_64-pc-windows-msvc/rustup-init.exe",
                    },
                    required = true,
                },
            },
        },
    },

    xpm = {
        windows = {
            ["latest"] = { ref = "1.29.3" },
            ["1.28.2"] = {
                url = string.format(_rustup_tpl, "1.28.2", "x86_64-pc-windows-msvc") .. ".exe",
                sha256 = nil,
            },
            ["1.29.2"] = {
                url = {
                    GLOBAL = "https://static.rust-lang.org/rustup/archive/1.29.2/x86_64-pc-windows-msvc/rustup-init.exe",
                    CN = "https://mirrors.ustc.edu.cn/rust-static/rustup/archive/1.29.2/x86_64-pc-windows-msvc/rustup-init.exe",
                },
                sha256 = "00f139da614dced87d3c3d4121c43eebdac3c1bf8a5ee86b9d80dfd71c8d70fd",
            },
            ["1.29.3"] = {
                url = {
                    GLOBAL = "https://static.rust-lang.org/rustup/archive/1.29.3/x86_64-pc-windows-msvc/rustup-init.exe",
                    CN = "https://mirrors.ustc.edu.cn/rust-static/rustup/archive/1.29.3/x86_64-pc-windows-msvc/rustup-init.exe",
                },
                sha256 = "38027d51d69a5d05493627a0634dbea52d6cd793c8f072d2373d3f4163eec7db",
            },
        },
        linux = {
            ["latest"] = { ref = "1.29.3" },
            ["1.28.2"] = {
                x86_64 = {
                    url = "https://static.rust-lang.org/rustup/archive/1.28.2/x86_64-unknown-linux-gnu/rustup-init",
                    sha256 = "20a06e644b0d9bd2fbdbfd52d42540bdde820ea7df86e92e533c073da0cdd43c",
                },
                aarch64 = {
                    url = "https://static.rust-lang.org/rustup/archive/1.28.2/aarch64-unknown-linux-gnu/rustup-init",
                    sha256 = "e3853c5a252fca15252d07cb23a1bdd9377a8c6f3efa01531109281ae47f841c",
                },
            },
            ["1.29.2"] = {
                x86_64 = {
                    url = {
                        GLOBAL = "https://static.rust-lang.org/rustup/archive/1.29.2/x86_64-unknown-linux-gnu/rustup-init",
                        CN = "https://mirrors.ustc.edu.cn/rust-static/rustup/archive/1.29.2/x86_64-unknown-linux-gnu/rustup-init",
                    },
                    sha256 = "5be191e8c70a5007074254cb74d78dbfdd25cd5a61c27de7b8e5410122ec24f4",
                },
                aarch64 = {
                    url = {
                        GLOBAL = "https://static.rust-lang.org/rustup/archive/1.29.2/aarch64-unknown-linux-gnu/rustup-init",
                        CN = "https://mirrors.ustc.edu.cn/rust-static/rustup/archive/1.29.2/aarch64-unknown-linux-gnu/rustup-init",
                    },
                    sha256 = "a9c168dbea81a84671c6b7a5c1795cb0eb699020110d107ddfca427bd797e697",
                },
            },
            ["1.29.3"] = {
                x86_64 = {
                    url = {
                        GLOBAL = "https://static.rust-lang.org/rustup/archive/1.29.3/x86_64-unknown-linux-gnu/rustup-init",
                        CN = "https://mirrors.ustc.edu.cn/rust-static/rustup/archive/1.29.3/x86_64-unknown-linux-gnu/rustup-init",
                    },
                    sha256 = "b1c8cb14e30889e7e2999e6b69e62d9e9b9ffc0f4df8180564d306d9680e6c55",
                },
                aarch64 = {
                    url = {
                        GLOBAL = "https://static.rust-lang.org/rustup/archive/1.29.3/aarch64-unknown-linux-gnu/rustup-init",
                        CN = "https://mirrors.ustc.edu.cn/rust-static/rustup/archive/1.29.3/aarch64-unknown-linux-gnu/rustup-init",
                    },
                    sha256 = "9f608c142e0e38a78957d0661ba1dfaf0b6fb37184cfaa4b9a0aa57af6184282",
                },
            },
        },
        macosx = {
            ["latest"] = { ref = "1.29.3" },
            ["1.28.2"] = {
                url = string.format(_rustup_tpl, "1.28.2", "x86_64-apple-darwin"),
                sha256 = nil,
            },
            ["1.29.2"] = {
                url = {
                    GLOBAL = "https://static.rust-lang.org/rustup/archive/1.29.2/x86_64-apple-darwin/rustup-init",
                    CN = "https://mirrors.ustc.edu.cn/rust-static/rustup/archive/1.29.2/x86_64-apple-darwin/rustup-init",
                },
                sha256 = "b9610730ddeef52765723847866fd1e3540b2bf7d5ab0c324aa143a5edf25ba0",
            },
            ["1.29.3"] = {
                url = {
                    GLOBAL = "https://static.rust-lang.org/rustup/archive/1.29.3/x86_64-apple-darwin/rustup-init",
                    CN = "https://mirrors.ustc.edu.cn/rust-static/rustup/archive/1.29.3/x86_64-apple-darwin/rustup-init",
                },
                sha256 = "bc107f1fb0228de7fa32413c89c1b305cea9cd256e94b01150cd054128145429",
            },
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
    -- `group` is the only kind that both avoids a bogus shim under the
    -- package name and lets `xlings remove` find the package; removal of a
    -- group root needs xlings >= 2026.7.x, which is why CI pins a current
    -- client (older ones refuse the remove and leak the shims).
    xvm.add("rustup", { type = "group" })
    return true
end

function uninstall()
    xvm.remove("rustup-init")
    xvm.remove("rustup")
    return true
end

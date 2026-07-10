package = {
    spec = "1",

    name = "yazi",
    description = "Blazing fast terminal file manager written in Rust, based on async I/O",
    homepage = "https://github.com/sxyazi/yazi",
    maintainers = {"sxyazi"},
    licenses = {"MIT"},
    repo = "https://github.com/sxyazi/yazi",
    docs = "https://yazi-rs.github.io/docs/introduction/",

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"cli", "file-manager", "tools"},
    keywords = {"yazi", "file-manager", "tui", "rust"},

    programs = {"yazi", "ya"},
    xvm_enable = true,

    xpm = {
        linux = {
            url_template = "https://github.com/sxyazi/yazi/releases/download/v{version}/yazi-x86_64-unknown-linux-musl.zip",
            ["latest"] = { ref = "26.5.6" },
            ["26.5.6"] = {
                url = {
                    GLOBAL = "https://github.com/sxyazi/yazi/releases/download/v26.5.6/yazi-x86_64-unknown-linux-musl.zip",
                    CN = "https://gitcode.com/xlings-res/yazi/releases/download/26.5.6/yazi-x86_64-unknown-linux-musl.zip",
                },
                sha256 = "1031a02560d053301537195a6661d227c15cb4ce5c30481050b31e2b88681bff",
            },
        },
        macosx = {
            url_template = "https://github.com/sxyazi/yazi/releases/download/v{version}/yazi-aarch64-apple-darwin.zip",
            ["latest"] = { ref = "26.5.6" },
            ["26.5.6"] = {
                url = {
                    GLOBAL = "https://github.com/sxyazi/yazi/releases/download/v26.5.6/yazi-aarch64-apple-darwin.zip",
                    CN = "https://gitcode.com/xlings-res/yazi/releases/download/26.5.6/yazi-aarch64-apple-darwin.zip",
                },
                sha256 = "7abd71725e2fe27bed036becbf6ce79fa17964eb68491d34190011c94b8c7ca8",
            },
        },
        windows = {
            url_template = "https://github.com/sxyazi/yazi/releases/download/v{version}/yazi-x86_64-pc-windows-msvc.zip",
            ["latest"] = { ref = "26.5.6" },
            ["26.5.6"] = {
                url = {
                    GLOBAL = "https://github.com/sxyazi/yazi/releases/download/v26.5.6/yazi-x86_64-pc-windows-msvc.zip",
                    CN = "https://gitcode.com/xlings-res/yazi/releases/download/26.5.6/yazi-x86_64-pc-windows-msvc.zip",
                },
                sha256 = "6c6c52a4b2648e179f917bdaa7c57e793d18561b380a8bfa025f10cd1b9b2ad1",
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")

-- Archives extract into `yazi-<triple>/` containing the `yazi` / `yazi.exe`
-- (file manager) and `ya` / `ya.exe` (companion CLI for plugins/IPC)
-- binaries, alongside completions and docs.
function install()
    os.tryrm(pkginfo.install_dir())
    os.mkdir(pkginfo.install_dir())

    local extracted = pkginfo.install_file():replace(".zip", "")
    local suffix = is_host("windows") and ".exe" or ""

    for _, exe in ipairs({"yazi", "ya"}) do
        local name = exe .. suffix
        os.mv(path.join(extracted, name), path.join(pkginfo.install_dir(), name))
    end
    os.tryrm(extracted)
    return true
end

function config()
    local bindir = pkginfo.install_dir()
    xvm.add("yazi", { bindir = bindir })
    xvm.add("ya", { bindir = bindir, binding = "yazi@" .. pkginfo.version() })
    return true
end

function uninstall()
    xvm.remove("yazi")
    xvm.remove("ya")
    return true
end

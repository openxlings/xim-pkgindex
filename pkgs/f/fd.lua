package = {
    spec = "1",

    name = "fd",
    description = "Simple, fast, user-friendly alternative to find",
    homepage = "https://github.com/sharkdp/fd",
    maintainers = {"David Peter"},
    licenses = {"MIT", "Apache-2.0"},
    repo = "https://github.com/sharkdp/fd",
    ci = { mirror = true, update = true },
    docs = "https://github.com/sharkdp/fd#readme",

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"cli", "search", "tools"},
    keywords = {"find", "fd", "search", "rust"},

    programs = {"fd"},
    xvm_enable = true,

    xpm = {
        linux = {
            url_template = "https://github.com/sharkdp/fd/releases/download/v{version}/fd-v{version}-x86_64-unknown-linux-musl.tar.gz",
            ["latest"] = { ref = "10.4.2" },
            ["10.4.2"] = {
                url = "https://github.com/sharkdp/fd/releases/download/v10.4.2/fd-v10.4.2-x86_64-unknown-linux-musl.tar.gz",
                sha256 = "e3257d48e29a6be965187dbd24ce9af564e0fe67b3e73c9bdcd180f4ec11bdde",
            },
        },
        macosx = {
            url_template = "https://github.com/sharkdp/fd/releases/download/v{version}/fd-v{version}-aarch64-apple-darwin.tar.gz",
            ["latest"] = { ref = "10.4.2" },
            ["10.4.2"] = {
                url = "https://github.com/sharkdp/fd/releases/download/v10.4.2/fd-v10.4.2-aarch64-apple-darwin.tar.gz",
                sha256 = "623dc0afc81b92e4d4606b380d7bc91916ba7b97814263e554d50923a39e480a",
            },
        },
        windows = {
            url_template = "https://github.com/sharkdp/fd/releases/download/v{version}/fd-v{version}-x86_64-pc-windows-msvc.zip",
            ["latest"] = { ref = "10.4.2" },
            ["10.4.2"] = {
                url = "https://github.com/sharkdp/fd/releases/download/v10.4.2/fd-v10.4.2-x86_64-pc-windows-msvc.zip",
                sha256 = "b2816e506390a89941c63c9187d58a3cc10e9a55f2ef0685f9ea0eccaf7c98c8",
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")

-- Archives extract into `fd-v<ver>-<triple>/` containing the `fd` /
-- `fd.exe` binary alongside autocomplete scripts and docs.
function install()
    os.tryrm(pkginfo.install_dir())
    os.mkdir(pkginfo.install_dir())

    local extracted = pkginfo.install_file()
        :replace(".tar.gz", "")
        :replace(".zip", "")

    local exe = is_host("windows") and "fd.exe" or "fd"
    os.mv(path.join(extracted, exe), path.join(pkginfo.install_dir(), exe))
    os.tryrm(extracted)
    return true
end

function config()
    xvm.add("fd", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("fd")
    return true
end

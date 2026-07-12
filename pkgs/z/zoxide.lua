package = {
    spec = "1",

    name = "zoxide",
    description = "A smarter cd command — jump to your most-used directories",
    homepage = "https://github.com/ajeetdsouza/zoxide",
    maintainers = {"ajeetdsouza"},
    licenses = {"MIT"},
    repo = "https://github.com/ajeetdsouza/zoxide",
    ci = { mirror = true, update = true },
    docs = "https://github.com/ajeetdsouza/zoxide#readme",

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"cli", "navigation", "tools"},
    keywords = {"cd", "navigation", "zoxide", "rust"},

    programs = {"zoxide"},
    xvm_enable = true,

    xpm = {
        linux = {
            url_template = "https://github.com/ajeetdsouza/zoxide/releases/download/v{version}/zoxide-{version}-x86_64-unknown-linux-musl.tar.gz",
            ["latest"] = { ref = "0.9.9" },
            ["0.9.9"] = {
                url = "https://github.com/ajeetdsouza/zoxide/releases/download/v0.9.9/zoxide-0.9.9-x86_64-unknown-linux-musl.tar.gz",
                sha256 = "4ff057d3c4d957946937274c2b8be7af2a9bbae7f90a1b5e9baaa7cb65a20caa",
            },
            ["0.9.7"] = {
                url = "https://github.com/ajeetdsouza/zoxide/releases/download/v0.9.7/zoxide-0.9.7-x86_64-unknown-linux-musl.tar.gz",
                sha256 = "ee53a42c11fe8a175ef7b136bb91f588aef76e1ae7133e58a695b1199588ee7e",
            },
        },
        macosx = {
            url_template = "https://github.com/ajeetdsouza/zoxide/releases/download/v{version}/zoxide-{version}-aarch64-apple-darwin.tar.gz",
            ["latest"] = { ref = "0.9.9" },
            ["0.9.9"] = {
                url = "https://github.com/ajeetdsouza/zoxide/releases/download/v0.9.9/zoxide-0.9.9-aarch64-apple-darwin.tar.gz",
                sha256 = "57e733d0436309dae2ed97e46bba43937209395298e1d88812d4e893900cb40a",
            },
            ["0.9.7"] = {
                url = "https://github.com/ajeetdsouza/zoxide/releases/download/v0.9.7/zoxide-0.9.7-aarch64-apple-darwin.tar.gz",
                sha256 = "4ce19ad9ea0fdf92265ef73b1cb38c605fbccfda815157c1e99c0af99115c4e4",
            },
        },
        windows = {
            url_template = "https://github.com/ajeetdsouza/zoxide/releases/download/v{version}/zoxide-{version}-x86_64-pc-windows-msvc.zip",
            ["latest"] = { ref = "0.9.9" },
            ["0.9.9"] = {
                url = "https://github.com/ajeetdsouza/zoxide/releases/download/v0.9.9/zoxide-0.9.9-x86_64-pc-windows-msvc.zip",
                sha256 = "5af00d0916f05631e3030537289eac56605e7c1733318c4d525c8e847f12496d",
            },
            ["0.9.7"] = {
                url = "https://github.com/ajeetdsouza/zoxide/releases/download/v0.9.7/zoxide-0.9.7-x86_64-pc-windows-msvc.zip",
                sha256 = "d2f7640e977170d58c3f7057a9ecbfe6597de1a3dbbd992fb2fea1255e6098e4",
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")

-- Archive layout: every platform's archive (.tar.gz / .zip) drops files
-- directly into the extraction dir with no enclosing folder — `zoxide`
-- (or `zoxide.exe`) sits at the top alongside CHANGELOG / man / completions.
-- So we always pull the binary out of `download_dir`, not a sub-extracted
-- folder (unlike fd/bat which DO have an enclosing dir).
function install()
    os.tryrm(pkginfo.install_dir())
    os.mkdir(pkginfo.install_dir())

    local download_dir = path.directory(pkginfo.install_file())
    local exe = is_host("windows") and "zoxide.exe" or "zoxide"
    os.mv(path.join(download_dir, exe), path.join(pkginfo.install_dir(), exe))
    return true
end

function config()
    xvm.add("zoxide", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("zoxide")
    return true
end

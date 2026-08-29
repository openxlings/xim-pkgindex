package = {
    spec = "1",

    name = "fzf",
    description = "A command-line fuzzy finder",
    homepage = "https://junegunn.github.io/fzf/",
    maintainers = {"Junegunn Choi"},
    licenses = {"MIT"},
    repo = "https://github.com/junegunn/fzf",
    ci = { mirror = true, update = true },
    docs = "https://junegunn.github.io/fzf/",

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"cli", "search", "tools"},
    keywords = {"fzf", "fuzzy", "finder", "search", "go"},

    programs = {"fzf"},
    xvm_enable = true,

    xpm = {
        linux = {
            url_template = "https://github.com/junegunn/fzf/releases/download/v{version}/fzf-{version}-linux_amd64.tar.gz",
            ["latest"] = { ref = "0.74.3" },
            ["0.74.3"] = {
                url = "https://github.com/junegunn/fzf/releases/download/v0.74.3/fzf-0.74.3-linux_amd64.tar.gz",
                sha256 = "3501a595e4b5c40a6b047340a0e8f805c46fd4e61ef95ef8a136ba8c61cf6f22",
            },
            ["0.72.0"] = {
                url = "https://github.com/junegunn/fzf/releases/download/v0.72.0/fzf-0.72.0-linux_amd64.tar.gz",
                sha256 = "0e58e4bd0b3c5d68c56b54c460a6863d0de79633ed18d388575a960ab447b006",
            },
            ["0.71.0"] = {
                url = "https://github.com/junegunn/fzf/releases/download/v0.71.0/fzf-0.71.0-linux_amd64.tar.gz",
                sha256 = "22639bb38489dbca8acef57850cbb50231ab714d0e8e855ac52fae8b41233df4",
            },
        },
        macosx = {
            url_template = "https://github.com/junegunn/fzf/releases/download/v{version}/fzf-{version}-darwin_arm64.tar.gz",
            ["latest"] = { ref = "0.74.3" },
            ["0.74.3"] = {
                url = "https://github.com/junegunn/fzf/releases/download/v0.74.3/fzf-0.74.3-darwin_arm64.tar.gz",
                sha256 = "1f8501cea4f9c0c2d6110d0ff75d0ec9451cd9d7524d9a26244a154ea89f3bd5",
            },
            ["0.72.0"] = {
                url = "https://github.com/junegunn/fzf/releases/download/v0.72.0/fzf-0.72.0-darwin_arm64.tar.gz",
                sha256 = "4cbf87e8e8a342614c1e3e74670ceb18c2af998c4d4d0c379cfee9b520774e90",
            },
            ["0.71.0"] = {
                url = "https://github.com/junegunn/fzf/releases/download/v0.71.0/fzf-0.71.0-darwin_arm64.tar.gz",
                sha256 = "02dfb11de8773cb79aa4fc5bfc77e75c6604ee14728bc849fc162dd91a9714c4",
            },
        },
        windows = {
            url_template = "https://github.com/junegunn/fzf/releases/download/v{version}/fzf-{version}-windows_amd64.zip",
            ["latest"] = { ref = "0.74.3" },
            ["0.74.3"] = {
                url = "https://github.com/junegunn/fzf/releases/download/v0.74.3/fzf-0.74.3-windows_amd64.zip",
                sha256 = "cf5c137d9b391c3988c54af8f5fc490ffbef6f70444651e7d57fdb45ad04c8bd",
            },
            ["0.72.0"] = {
                url = "https://github.com/junegunn/fzf/releases/download/v0.72.0/fzf-0.72.0-windows_amd64.zip",
                sha256 = "cce66ae7e442030334927bfbfd917690713e63d215aba93027f99807828fe239",
            },
            ["0.71.0"] = {
                url = "https://github.com/junegunn/fzf/releases/download/v0.71.0/fzf-0.71.0-windows_amd64.zip",
                sha256 = "15bf30fa658c596d740f0ce9a9a97b6b5d90566124903657d09fd109dd0973d2",
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")

-- fzf archives are flat: the binary (`fzf` / `fzf.exe`) lands in the
-- runtime download dir directly, with no enclosing folder.
function install()
    os.tryrm(pkginfo.install_dir())
    os.mkdir(pkginfo.install_dir())

    local download_dir = path.directory(pkginfo.install_file())
    local exe = is_host("windows") and "fzf.exe" or "fzf"
    os.mv(path.join(download_dir, exe), path.join(pkginfo.install_dir(), exe))
    return true
end

function config()
    xvm.add("fzf", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("fzf")
    return true
end

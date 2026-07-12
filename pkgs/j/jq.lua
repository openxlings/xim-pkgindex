package = {
    spec = "1",

    name = "jq",
    description = "Command-line JSON processor",
    homepage = "https://jqlang.org/",
    maintainers = {"jqlang"},
    licenses = {"MIT"},
    repo = "https://github.com/jqlang/jq",
    docs = "https://jqlang.org/manual/",

    -- mirror only: jq ships raw-binary assets (jq-linux-amd64 etc.) which the
    -- mirror tool now handles; its release tag is jq-<version> with no
    -- url_template, so auto-update is not wired here.
    ci = { mirror = true },

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"cli", "json", "tools"},
    keywords = {"jq", "json", "parser", "filter"},

    programs = {"jq"},
    xvm_enable = true,

    -- jq publishes single-file binaries (no archive). xlings's auto-extract
    -- skips files whose extension isn't a recognised compressed format, so
    -- the install_file landing in runtimedir is the binary itself — we just
    -- need to move it into install_dir and chmod +x it on Unix.
    xpm = {
        linux = {
            ["latest"] = { ref = "1.8.1" },
            ["1.8.1"] = {
                url = "https://github.com/jqlang/jq/releases/download/jq-1.8.1/jq-linux-amd64",
                sha256 = "020468de7539ce70ef1bceaf7cde2e8c4f2ca6c3afb84642aabc5c97d9fc2a0d",
            },
        },
        macosx = {
            ["latest"] = { ref = "1.8.1" },
            ["1.8.1"] = {
                url = "https://github.com/jqlang/jq/releases/download/jq-1.8.1/jq-macos-arm64",
                sha256 = "a9fe3ea2f86dfc72f6728417521ec9067b343277152b114f4e98d8cb0e263603",
            },
        },
        windows = {
            ["latest"] = { ref = "1.8.1" },
            ["1.8.1"] = {
                url = "https://github.com/jqlang/jq/releases/download/jq-1.8.1/jq-windows-amd64.exe",
                sha256 = "23cb60a1354eed6bcc8d9b9735e8c7b388cd1fdcb75726b93bc299ef22dd9334",
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.libxpkg.system")

function install()
    os.tryrm(pkginfo.install_dir())
    os.mkdir(pkginfo.install_dir())

    local exe = is_host("windows") and "jq.exe" or "jq"
    local target = path.join(pkginfo.install_dir(), exe)
    os.mv(pkginfo.install_file(), target)
    if not is_host("windows") then
        system.exec(string.format([[chmod +x "%s"]], target))
    end
    return true
end

function config()
    xvm.add("jq", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("jq")
    return true
end

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
    extensions = {
        autoupdate = {
            source = "https://github.com/jqlang/jq/releases",
            resources = {
                GLOBAL = {
                    url = {
                        linux = {
                            aarch64 = "https://github.com/jqlang/jq/releases/download/jq-${version}/jq-linux-arm64",
                            x86_64 = "https://github.com/jqlang/jq/releases/download/jq-${version}/jq-linux-amd64",
                        },
                        macosx = "https://github.com/jqlang/jq/releases/download/jq-${version}/jq-macos-arm64",
                        windows = "https://github.com/jqlang/jq/releases/download/jq-${version}/jq-windows-amd64.exe",
                    },
                    required = true,
                },
            },
            tag = "jq-${version}",
        },
    },

    xpm = {
        linux = {
            ["latest"] = { ref = "1.8.2" },
            ["1.8.2"] = {
                x86_64 = {
                    url = "https://github.com/jqlang/jq/releases/download/jq-1.8.2/jq-linux-amd64",
                    sha256 = "b1c22172dd303f3be49e935aa56aa48a8b7a46e0bc838b4997d3bb451495870f",
                },
                aarch64 = {
                    url = "https://github.com/jqlang/jq/releases/download/jq-1.8.2/jq-linux-arm64",
                    sha256 = "8b85c817833814ddca00a144c33705546355afccf0cf39b188f3cdb48b852309",
                },
            },
            ["1.8.1"] = {
                url = "https://github.com/jqlang/jq/releases/download/jq-1.8.1/jq-linux-amd64",
                sha256 = "020468de7539ce70ef1bceaf7cde2e8c4f2ca6c3afb84642aabc5c97d9fc2a0d",
            },
        },
        macosx = {
            ["latest"] = { ref = "1.8.2" },
            ["1.8.2"] = {
                url = "https://github.com/jqlang/jq/releases/download/jq-1.8.2/jq-macos-arm64",
                sha256 = "2d75340ba57a4b4b4c8708a21c2dc8e958a48aaa8bba13b27f77f6e4c0eca07e",
            },
            ["1.8.1"] = {
                url = "https://github.com/jqlang/jq/releases/download/jq-1.8.1/jq-macos-arm64",
                sha256 = "a9fe3ea2f86dfc72f6728417521ec9067b343277152b114f4e98d8cb0e263603",
            },
        },
        windows = {
            ["latest"] = { ref = "1.8.2" },
            ["1.8.2"] = {
                url = "https://github.com/jqlang/jq/releases/download/jq-1.8.2/jq-windows-amd64.exe",
                sha256 = "a6fc67fedaf9128a3309a1e2ebb8b986aeccf70122ee46d2cb4849e423f0c627",
            },
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

-- lf r42: official single-binary terminal file manager (MIT).
-- All five archives are flat: lf on Unix, lf.exe on Windows. SHA-256 values
-- match GitHub release asset digests and downloaded bytes. Both Linux ELFs
-- are static (no interpreter or DT_NEEDED); Windows imports kernel32.dll only.
-- Upstream does not publish Windows ARM64. Optional openers/previewers are
-- user choices, not dependencies; no shell integration or config is installed.

package = {
    spec = "2",
    name = "lf",
    description = "Terminal file manager with a small, fast, extensible interface",
    homepage = "https://github.com/gokcehan/lf",
    authors = {"Gökçehan Kara"},
    maintainers = {"gokcehan"},
    licenses = {"MIT"},
    repo = "https://github.com/gokcehan/lf",
    docs = "https://github.com/gokcehan/lf/blob/master/doc.md",
    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"cli", "tools", "file-manager"},
    keywords = {"lf", "file-manager", "terminal", "tui", "go"},
    programs = {"lf"},
    xvm_enable = true,
    ci = { mirror = true },

    extensions = {
        autoupdate = {
            source = "https://github.com/gokcehan/lf/releases",
            -- Numeric resolver version 42 corresponds to upstream tag r42.
            tag = "r${version}",
            resources = {
                GLOBAL = {
                    required = true,
                    url = {
                        linux = {
                            x86_64 = "https://github.com/gokcehan/lf/releases/download/${tag}/lf-linux-amd64.tar.gz",
                            aarch64 = "https://github.com/gokcehan/lf/releases/download/${tag}/lf-linux-arm64.tar.gz",
                        },
                        macosx = {
                            x86_64 = "https://github.com/gokcehan/lf/releases/download/${tag}/lf-darwin-amd64.tar.gz",
                            aarch64 = "https://github.com/gokcehan/lf/releases/download/${tag}/lf-darwin-arm64.tar.gz",
                        },
                        windows = {
                            x86_64 = "https://github.com/gokcehan/lf/releases/download/${tag}/lf-windows-amd64.zip",
                        },
                    },
                },
            },
        },
    },

    xpm = {
        linux = {
            ["latest"] = { ref = "42" },
            ["42"] = {
                x86_64 = {
                    url = "https://github.com/gokcehan/lf/releases/download/r42/lf-linux-amd64.tar.gz",
                    sha256 = "c6abe6c0c11a0a4ae89754884aad67de18decc113935cbc5eaa57dc0d1850fb4",
                },
                aarch64 = {
                    url = "https://github.com/gokcehan/lf/releases/download/r42/lf-linux-arm64.tar.gz",
                    sha256 = "b8095f4f9d2561340bea019a21ce5a7ac671f4c76402b7039732c003b6c03951",
                },
            },
        },
        macosx = {
            ["latest"] = { ref = "42" },
            ["42"] = {
                x86_64 = {
                    url = "https://github.com/gokcehan/lf/releases/download/r42/lf-darwin-amd64.tar.gz",
                    sha256 = "3a3c2180cce9274d5c4713b092cff2b1169db9d9df4334e1c40d485eab1e565a",
                },
                aarch64 = {
                    url = "https://github.com/gokcehan/lf/releases/download/r42/lf-darwin-arm64.tar.gz",
                    sha256 = "b08f3249cc9536fe7d9a29746a2de322c247f81cd543db541a770fe49b53bd37",
                },
            },
        },
        windows = {
            ["latest"] = { ref = "42" },
            ["42"] = {
                x86_64 = {
                    url = "https://github.com/gokcehan/lf/releases/download/r42/lf-windows-amd64.zip",
                    sha256 = "13bb576b02373610dbcfb97e483272198a1b94cada66298a302954d87613465c",
                },
            },
        },
    },
}

import("xim.libxpkg.fs")
import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.pkgindex.payload")
import("xim.pkgindex.shell")

function installed()
    return payload.present({ "lf" }) or payload.present({ "lf.exe" })
end

function install()
    local archive = tostring(pkginfo.install_file() or "")
    local dir = pkginfo.install_dir()
    local windows = archive:match("%.zip$") ~= nil
    local exe = windows and "lf.exe" or "lf"

    -- Unix archives have no enclosing directory: unpack only this archive,
    -- not the shared runtime directory which may contain other downloads.
    if windows then
        payload.unpack{}
    else
        os.tryrm(dir)
        fs.mkdir_p(dir)
        shell.exec({ "tar", "-xzf", archive, "-C", dir })
        shell.exec({ "chmod", "+x", dir .. "/" .. exe })
    end
    payload.require({ exe })
    return true
end

function config()
    xvm.add("lf", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("lf")
    return true
end

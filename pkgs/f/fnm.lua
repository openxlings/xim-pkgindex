-- Installs fnm only: no Node download, shell-profile edits, or automatic shell setup.
-- fnm env remains opt-in. macOS uses the upstream universal binary; Windows
-- ARM64 has no native release asset and is deliberately not advertised.
package = {
    spec = "2",
    name = "fnm",
    description = "Fast and simple Node.js version manager",
    homepage = "https://github.com/Schniz/fnm",
    authors = {"Gal Schlezinger and contributors"},
    maintainers = {"Schniz"},
    licenses = {"GPL-3.0"},
    repo = "https://github.com/Schniz/fnm",
    docs = "https://github.com/Schniz/fnm#usage",
    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"tools", "development"},
    keywords = {"fnm", "node", "nodejs", "version-manager"},
    programs = {"fnm"},
    xvm_enable = true,

    extensions = {
        autoupdate = {
            source = "https://github.com/Schniz/fnm/releases",
            resources = {
                GLOBAL = { url = {
                    linux = {
                        x86_64 = "https://github.com/Schniz/fnm/releases/download/v${version}/fnm-linux.zip",
                        aarch64 = "https://github.com/Schniz/fnm/releases/download/v${version}/fnm-arm64.zip",
                    },
                    macosx = {
                        x86_64 = "https://github.com/Schniz/fnm/releases/download/v${version}/fnm-macos.zip",
                        aarch64 = "https://github.com/Schniz/fnm/releases/download/v${version}/fnm-macos.zip",
                    },
                    windows = {
                        x86_64 = "https://github.com/Schniz/fnm/releases/download/v${version}/fnm-windows.zip",
                    },
                } },
            },
        },
    },

    xpm = {
        linux = {
            ["latest"] = { ref = "1.39.0" },
            ["1.39.0"] = {
                x86_64 = {
                    url = "https://github.com/Schniz/fnm/releases/download/v1.39.0/fnm-linux.zip",
                    sha256 = "7807664f39d39fc518da1c35ba0181e4b3267603c4b1dedeb4b5fc6ae440a224",
                },
                aarch64 = {
                    url = "https://github.com/Schniz/fnm/releases/download/v1.39.0/fnm-arm64.zip",
                    sha256 = "4eaff58b2c5bf30d0934027572dd0b5bbb60d2a1af309230b53662d4b1d45599",
                },
            },
        },
        macosx = {
            ["latest"] = { ref = "1.39.0" },
            ["1.39.0"] = {
                url = "https://github.com/Schniz/fnm/releases/download/v1.39.0/fnm-macos.zip",
                sha256 = {
                    x86_64 = "f046483e85c53b3278efe49a3620c8680f22efa58a8dabfd03eafc6b59b31a25",
                    aarch64 = "f046483e85c53b3278efe49a3620c8680f22efa58a8dabfd03eafc6b59b31a25",
                },
            },
        },
        windows = {
            ["latest"] = { ref = "1.39.0" },
            ["1.39.0"] = {
                x86_64 = {
                    url = "https://github.com/Schniz/fnm/releases/download/v1.39.0/fnm-windows.zip",
                    sha256 = "8183bed4348cb78fdfd8abb3d1247fbeab7b2082f941363929c61e747c001e10",
                },
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.pkgindex.payload")

local function required_files()
    local exe = os.isfile(pkginfo.install_dir() .. "/fnm.exe") and "fnm.exe" or "fnm"
    return {exe}
end

function installed()
    return payload.present(required_files())
end

function install()
    local archive = tostring(pkginfo.install_file()):gsub("\\", "/")
    local parent = archive:match("^(.*)/[^/]+$") or "."
    local exe = archive:match("fnm%-windows%.zip$") and "fnm.exe" or "fnm"
    local source = parent .. "/" .. exe
    if os.isfile(source) then
        os.tryrm(pkginfo.install_dir())
        os.mkdir(pkginfo.install_dir())
        os.mv(source, pkginfo.install_dir() .. "/" .. exe)
    else
        -- Windows does not pre-extract flat ZIPs; use the system-tar helper.
        payload.unpack()
    end
    payload.require({exe})
    return true
end

function config()
    xvm.add("fnm", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("fnm")
    return true
end

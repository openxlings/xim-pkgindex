-- Official v1.6.1 assets: every archive was downloaded and matched against
-- the GitHub asset digest and upstream checksums. Layout: dist/<asset-stem>/spf
-- (spf.exe on Windows). Linux binaries are static; Windows imports kernel32.dll.
-- A Nerd Font is recommended; optional preview tools/plugins are not installed.
-- Only launching spf creates its own user configuration, never these hooks.
package = {
    spec = "2",
    name = "superfile",
    description = "Modern terminal file manager with a customizable TUI (spf)",
    homepage = "https://superfile.dev",
    repo = "https://github.com/yorukot/superfile",
    docs = "https://superfile.dev/getting-started/installation/",
    authors = { "Yorukot" },
    licenses = { "MIT" },
    type = "package",
    archs = { "x86_64", "aarch64" },
    status = "stable",
    categories = { "tools", "cli", "filesystem" },
    keywords = { "superfile", "spf", "file-manager", "tui" },
    programs = { "spf" },
    xvm_enable = true,
    extensions = {
        autoupdate = {
            source = "https://github.com/yorukot/superfile/releases",
            resources = {
                GLOBAL = {
                    url = {
                        linux = {
                            x86_64 = "https://github.com/yorukot/superfile/releases/download/${tag}/superfile-linux-${tag}-amd64.tar.gz",
                            aarch64 = "https://github.com/yorukot/superfile/releases/download/${tag}/superfile-linux-${tag}-arm64.tar.gz",
                        },
                        macosx = {
                            x86_64 = "https://github.com/yorukot/superfile/releases/download/${tag}/superfile-darwin-${tag}-amd64.tar.gz",
                            aarch64 = "https://github.com/yorukot/superfile/releases/download/${tag}/superfile-darwin-${tag}-arm64.tar.gz",
                        },
                        windows = {
                            x86_64 = "https://github.com/yorukot/superfile/releases/download/${tag}/superfile-windows-${tag}-amd64.zip",
                            aarch64 = "https://github.com/yorukot/superfile/releases/download/${tag}/superfile-windows-${tag}-arm64.zip",
                        },
                    },
                },
            },
        },
    },
    xpm = {
        linux = {
            source = "https://github.com/yorukot/superfile/releases/download/v${version}/superfile-linux-v${version}-${arch_alias}.tar.gz",
            ["latest"] = { ref = "1.6.1" },
            ["1.6.1"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "2ab6872fee8fb2d6d120503f964cc693cf5ce328afedbe3988729593870c570e",
                    aarch64 = "643d123cc957b23f871cf9fca873e7bf22452640b8dc0fb87d2bd51722ddf5ed",
                },
            },
        },
        macosx = {
            source = "https://github.com/yorukot/superfile/releases/download/v${version}/superfile-darwin-v${version}-${arch_alias}.tar.gz",
            ["latest"] = { ref = "1.6.1" },
            ["1.6.1"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "506aae6c8fa53c3ddd5816428740cf176fd456d2f67656fdeec92b36a398b673",
                    aarch64 = "4d2e4c028b5cc870d0b3afcef88dd501fcf0d4d982ea3301f687ffd446821cb9",
                },
            },
        },
        windows = {
            source = "https://github.com/yorukot/superfile/releases/download/v${version}/superfile-windows-v${version}-${arch_alias}.zip",
            ["latest"] = { ref = "1.6.1" },
            ["1.6.1"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "dd7156c51bbbba7a0a0d1fcb10ebf60560762c4917729c40450641e27e2cb7c5",
                    aarch64 = "55b25919f7adc8bdafbb47e0cdda10b8d285347a8505f6071f359ea190391965",
                },
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.pkgindex.payload")

local function required_files()
    return { os.getenv("OS") == "Windows_NT" and "spf.exe" or "spf" }
end

function installed()
    return payload.present(required_files())
end

function install()
    local archive = tostring(pkginfo.install_file()):gsub("\\", "/"):match("([^/]+)$")
    local stem = archive:gsub("%.tar%.gz$", ""):gsub("%.zip$", "")
    payload.unpack({ extracted = "dist/" .. stem, strip = 2 })
    payload.require(required_files())
    return true
end

function config()
    xvm.add("spf", { bindir = pkginfo.install_dir() })
    xvm.add(package.name, { type = "group" })
    return true
end

function uninstall()
    xvm.remove("spf")
    xvm.remove(package.name)
    return true
end

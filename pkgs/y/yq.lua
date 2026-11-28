-- yq — a lightweight and portable command-line YAML, JSON, XML, INI, CSV, TOML,
-- HCL, and properties processor written in Go (mikefarah/yq).
--
-- Distribution: upstream publishes raw single-file binaries alongside .tar.gz / .zip
-- archives for every supported platform and architecture. We use the raw standalone
-- binaries directly (CGO_ENABLED=0 static executables on Linux — verified with
-- `readelf -d`: no dynamic section, so no glibc or runtime dependency is required),
-- moving `pkginfo.install_file()` to `<install_dir>/yq` (or `yq.exe` on Windows)
-- and setting executable permissions on Unix.
--
-- Verified against mikefarah/yq release v4.54.3 (SHA-256 matched upstream `checksums`):
--   linux/x86_64    yq_linux_amd64
--   linux/aarch64   yq_linux_arm64
--   macosx/x86_64   yq_darwin_amd64
--   macosx/aarch64  yq_darwin_arm64
--   windows/x86_64  yq_windows_amd64.exe
--   windows/aarch64 yq_windows_arm64.exe

package = {
    spec = "2",

    name = "yq",
    description = "yq is a portable command-line YAML, JSON, XML, CSV, TOML, HCL and properties processor",
    homepage = "https://mikefarah.gitbook.io/yq/",
    maintainers = {"mikefarah"},
    licenses = {"MIT"},
    repo = "https://github.com/mikefarah/yq",
    docs = "https://mikefarah.gitbook.io/yq/",

    ci = { mirror = true },

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"cli", "yaml", "json", "tools"},
    keywords = {"yq", "yaml", "json", "toml", "xml", "cli", "processor"},

    programs = {"yq"},
    xvm_enable = true,

    -- Verified upstream release assets; no CN mirror has been verified.
    extensions = {
        autoupdate = {
            source = "https://github.com/mikefarah/yq/releases",
            resources = {
                GLOBAL = {
                    required = true,
                    url = {
                        linux = {
                            x86_64 = "https://github.com/mikefarah/yq/releases/download/v${version}/yq_linux_amd64",
                            aarch64 = "https://github.com/mikefarah/yq/releases/download/v${version}/yq_linux_arm64",
                        },
                        macosx = {
                            x86_64 = "https://github.com/mikefarah/yq/releases/download/v${version}/yq_darwin_amd64",
                            aarch64 = "https://github.com/mikefarah/yq/releases/download/v${version}/yq_darwin_arm64",
                        },
                        windows = {
                            x86_64 = "https://github.com/mikefarah/yq/releases/download/v${version}/yq_windows_amd64.exe",
                            aarch64 = "https://github.com/mikefarah/yq/releases/download/v${version}/yq_windows_arm64.exe",
                        },
                    },
                },
            },
        },
    },

    xpm = {
        linux = {
            source = "https://github.com/mikefarah/yq/releases/download/v${version}/yq_linux_${arch_alias}",
            ["latest"] = { ref = "4.54.3" },
            ["4.54.3"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "129534601871538efe0ba4c5e62a34fb1d5f469bcb975c4fddeb467d82974973",
                    aarch64 = "89f69310b61b68d1245065a1241d1fc843f7a36cd6103ffd77ad987613bd1b67",
                },
            },
        },
        macosx = {
            source = "https://github.com/mikefarah/yq/releases/download/v${version}/yq_darwin_${arch_alias}",
            ["latest"] = { ref = "4.54.3" },
            ["4.54.3"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "96d5105ffd693d6845c54fbd825b2d1bbdb8619e0a2ce6af95e5654e841e0984",
                    aarch64 = "a2aebb93b5bdcb61bb76f630e42a0ef6a3ee10842a6516cd7b9e4080786ec593",
                },
            },
        },
        windows = {
            source = "https://github.com/mikefarah/yq/releases/download/v${version}/yq_windows_${arch_alias}.exe",
            ["latest"] = { ref = "4.54.3" },
            ["4.54.3"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "066ea0a09a282e47588ec1e1867280ff5ede458f7183617a2d99012e4e34f18a",
                    aarch64 = "a0c37ad85f4dafdabeaaf46127e408356fd480b7096e3a41e5dede2f3e46080d",
                },
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.libxpkg.system")

local function _is_windows_payload(file)
    return tostring(file):lower():match("%.exe$") ~= nil
end

function installed()
    local dir = pkginfo.install_dir()
    return os.isfile(dir .. "/yq") or os.isfile(dir .. "/yq.exe")
end

function install()
    local src = pkginfo.install_file()
    local dir = pkginfo.install_dir()
    local is_win = _is_windows_payload(src)
    local target = dir .. (is_win and "/yq.exe" or "/yq")

    os.tryrm(dir)
    os.mkdir(dir)
    os.mv(src, target)
    if not is_win then
        system.exec(string.format([[chmod +x "%s"]], target))
    end
    if not os.isfile(target) then
        error("yq: executable missing after install at " .. target)
    end
    return true
end

function config()
    xvm.add("yq", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("yq")
    return true
end

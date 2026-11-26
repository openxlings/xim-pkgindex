-- Kopia - Fast and secure open source backup.
--
-- Verified against official upstream GitHub release v0.23.1 (`kopia/kopia`).
-- Every SHA-256 digest below was computed from the downloaded release assets:
--   * linux   x86_64, aarch64   `kopia-<ver>-linux-{x64,arm64}.tar.gz`
--                               (tarball with top-level `kopia-<ver>-linux-<arch>/`
--                               containing static Go ELF64 `kopia`, `LICENSE`, `README.md`;
--                               no .dynamic section via `readelf -d` and `ldd`,
--                               so no runtime dependencies are needed).
--   * macosx  x86_64, aarch64   `kopia-<ver>-macOS-{x64,arm64}.tar.gz`
--                               (tarball with top-level `kopia-<ver>-macOS-<arch>/`
--                               containing Mach-O `kopia`, `LICENSE`, `README.md`).
--   * windows x86_64            `kopia-<ver>-windows-x64.zip`
--                               (zip with top-level `kopia-<ver>-windows-x64/`
--                               containing `kopia.exe`, `LICENSE`, `README.md`;
--                               PE32+ executable importing only `kernel32.dll`,
--                               no VCRUNTIME DLL dependency; upstream publishes
--                               no `windows-arm64` asset).

package = {
    spec = "2",

    name = "kopia",
    description = "Fast and secure open source backup",
    homepage = "https://kopia.io",
    authors = {"Kopia Authors"},
    maintainers = {"https://github.com/kopia/kopia/graphs/contributors"},
    licenses = {"Apache-2.0"},
    repo = "https://github.com/kopia/kopia",
    docs = "https://kopia.io/docs/",

    ci = { mirror = true },

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"backup", "cli", "security", "tools"},
    keywords = {"kopia", "backup", "encryption", "snapshot", "deduplication", "cli"},

    programs = {"kopia"},
    xvm_enable = true,

    extensions = {
        autoupdate = {
            source = "https://github.com/kopia/kopia/releases",
            resources = {
                GLOBAL = {
                    url = {
                        linux = {
                            x86_64 = "https://github.com/kopia/kopia/releases/download/${tag}/kopia-${version}-linux-x64.tar.gz",
                            aarch64 = "https://github.com/kopia/kopia/releases/download/${tag}/kopia-${version}-linux-arm64.tar.gz",
                        },
                        macosx = {
                            x86_64 = "https://github.com/kopia/kopia/releases/download/${tag}/kopia-${version}-macOS-x64.tar.gz",
                            aarch64 = "https://github.com/kopia/kopia/releases/download/${tag}/kopia-${version}-macOS-arm64.tar.gz",
                        },
                        windows = {
                            x86_64 = "https://github.com/kopia/kopia/releases/download/${tag}/kopia-${version}-windows-x64.zip",
                        },
                    },
                    required = true,
                },
            },
        },
    },

    xpm = {
        linux = {
            source = "https://github.com/kopia/kopia/releases/download/v${version}/kopia-${version}-linux-${arch_alias}.tar.gz",
            ["latest"] = { ref = "0.23.1" },
            ["0.23.1"] = {
                arch_alias = { x86_64 = "x64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "416d0f84a3dbb321a8b2d8f0997b1a0a6e915babe79ee76fa6e4d2bd1e1c5178",
                    aarch64 = "a4ffbc019e0b0f932e2632054e73ec521dc1e80172a00095369c53ecf4e5a6cb",
                },
            },
        },
        macosx = {
            source = "https://github.com/kopia/kopia/releases/download/v${version}/kopia-${version}-macOS-${arch_alias}.tar.gz",
            ["latest"] = { ref = "0.23.1" },
            ["0.23.1"] = {
                arch_alias = { x86_64 = "x64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "89dd7160a1266413c73bd0aa92459c5e739fcaed2ba30a4cca30aef179f11042",
                    aarch64 = "19e6ed637221f4dfd46a46e978ec4c509c386b522d746db2cd6762b217478111",
                },
            },
        },
        windows = {
            source = "https://github.com/kopia/kopia/releases/download/v${version}/kopia-${version}-windows-${arch_alias}.zip",
            ["latest"] = { ref = "0.23.1" },
            ["0.23.1"] = {
                arch_alias = { x86_64 = "x64" },
                sha256 = {
                    x86_64 = "f0369d9657dbe47a1b8b6ff4e308c5958a4813b405d4e32ae9d81b3f2b3d8251",
                },
            },
        },
    },
}

import("xim.libxpkg.fs")
import("xim.libxpkg.pkginfo")
import("xim.libxpkg.system")
import("xim.libxpkg.xvm")
import("xim.pkgindex.payload")

function installed()
    return payload.present({ "kopia" }) or payload.present({ "kopia.exe" })
end

function install()
    local archive = tostring(pkginfo.install_file() or "")
    if archive == "" then
        error("kopia: install_file is empty")
    end

    local dir = pkginfo.install_dir()
    local normalized = archive:gsub("\\", "/")
    local parent = normalized:match("^(.*)/[^/]+$") or "."
    local filename = normalized:match("([^/]+)$") or ""
    local stem = filename:gsub("%.tar%.gz$", ""):gsub("%.zip$", "")
    local is_win = normalized:lower():match("%.zip$") ~= nil
        or normalized:match("windows") ~= nil
        or os.getenv("OS") == "Windows_NT"
        or tostring(dir):match("^[A-Za-z]:") ~= nil
    local exe = is_win and "kopia.exe" or "kopia"

    if is_win or os.isdir(parent .. "/" .. stem) then
        payload.unpack{ extracted = stem, strip = 1 }
    elseif os.isfile(archive) then
        os.tryrm(dir)
        fs.mkdir_p(dir)
        system.exec(string.format('tar -xzf "%s" --strip-components=1 -C "%s"', archive, dir))
    else
        error("kopia: archive or extracted directory (" .. stem .. ") not found in " .. parent)
    end

    if not is_win and os.isfile(dir .. "/kopia") then
        system.exec(string.format('chmod +x "%s"', dir .. "/kopia"))
    end

    payload.require({ exe })
    return true
end

function config()
    xvm.add("kopia", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("kopia")
    return true
end

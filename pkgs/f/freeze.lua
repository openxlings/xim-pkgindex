-- Freeze: generate images of code and terminal output (charmbracelet/freeze).
-- Verified 2026-11-27 against v0.2.2 checksums.txt and all five downloaded archives.
-- Linux x86_64/aarch64: static ELF, no dynamic section. macOS x86_64/arm64:
-- Mach-O, only system libSystem/libresolv. Windows x86_64: PE32+, kernel32 only.
-- No Windows arm64 archive is published for this release.
-- Each archive has a freeze_<version>_<OS>_<arch>/ root with the executable,
-- LICENSE, and README.md. Default SVG rendering embeds JetBrains Mono (OFL-1.1)
-- and needs neither installed fonts nor network access. Freeze itself is MIT.
-- PNG can use optional rsvg-convert or upstream's embedded resvg/WASM fallback;
-- neither renderer nor a config wizard is invoked by package hooks.

package = {
    spec = "2",
    name = "freeze",
    description = "Generate images of code and terminal output",
    homepage = "https://github.com/charmbracelet/freeze",
    authors = { "Charmbracelet" },
    maintainers = { "https://github.com/charmbracelet/freeze/graphs/contributors" },
    licenses = { "MIT", "OFL-1.1" },
    repo = "https://github.com/charmbracelet/freeze",
    docs = "https://github.com/charmbracelet/freeze/tree/v0.2.2#readme",
    ci = { mirror = true },
    type = "package",
    archs = { "x86_64", "aarch64" },
    status = "stable",
    categories = { "tools", "graphics" },
    keywords = { "freeze", "code", "screenshot", "svg", "charm", "go" },
    programs = { "freeze" },
    xvm_enable = true,

    extensions = {
        autoupdate = {
            source = "https://github.com/charmbracelet/freeze/releases",
            resources = {
                GLOBAL = {
                    url = {
                        linux = {
                            x86_64 = "https://github.com/charmbracelet/freeze/releases/download/${tag}/freeze_${version}_Linux_x86_64.tar.gz",
                            aarch64 = "https://github.com/charmbracelet/freeze/releases/download/${tag}/freeze_${version}_Linux_arm64.tar.gz",
                        },
                        macosx = {
                            x86_64 = "https://github.com/charmbracelet/freeze/releases/download/${tag}/freeze_${version}_Darwin_x86_64.tar.gz",
                            aarch64 = "https://github.com/charmbracelet/freeze/releases/download/${tag}/freeze_${version}_Darwin_arm64.tar.gz",
                        },
                        windows = {
                            x86_64 = "https://github.com/charmbracelet/freeze/releases/download/${tag}/freeze_${version}_Windows_x86_64.zip",
                        },
                    },
                    required = true,
                },
            },
        },
    },

    xpm = {
        linux = {
            source = "https://github.com/charmbracelet/freeze/releases/download/v${version}/freeze_${version}_Linux_${arch_alias}.tar.gz",
            ["latest"] = { ref = "0.2.2" },
            ["0.2.2"] = {
                arch_alias = { x86_64 = "x86_64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "012fdbdd16c0c19570f9052aac34d16d93d7d0d3b565b05374cc59492f53539b",
                    aarch64 = "ba1164c2e6d573af32df13ddc5868f7cdfc8b9992f26f53695787ca5f4274023",
                },
            },
        },
        macosx = {
            source = "https://github.com/charmbracelet/freeze/releases/download/v${version}/freeze_${version}_Darwin_${arch_alias}.tar.gz",
            ["latest"] = { ref = "0.2.2" },
            ["0.2.2"] = {
                arch_alias = { x86_64 = "x86_64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "7ba01bc3f7f255bee2fe84847e8beeb1caa84914a49f4cf32e0147693d5e385f",
                    aarch64 = "6936ebad96dda73a6c952d7e945106916c4d4345334828109b4db6ddbb9aabee",
                },
            },
        },
        windows = {
            source = "https://github.com/charmbracelet/freeze/releases/download/v${version}/freeze_${version}_Windows_${arch_alias}.zip",
            ["latest"] = { ref = "0.2.2" },
            ["0.2.2"] = {
                arch_alias = { x86_64 = "x86_64" },
                sha256 = {
                    x86_64 = "971fc4b83ca797835505929620012db39a9c5aa849dccca369e852575fb1d344",
                },
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.pkgindex.payload")
import("xim.pkgindex.shell")

local function required_files(exe)
    return { exe, "LICENSE", "README.md" }
end

function installed()
    return payload.present(required_files("freeze"))
        or payload.present(required_files("freeze.exe"))
end

function install()
    local archive = tostring(pkginfo.install_file() or ""):gsub("\\", "/")
    local stem = (archive:match("([^/]+)$") or ""):gsub("%.tar%.gz$", ""):gsub("%.zip$", "")
    local is_win = archive:match("%.zip$") ~= nil
    local exe = is_win and "freeze.exe" or "freeze"
    payload.unpack { extracted = stem, strip = 1 }
    if not is_win then
        shell.exec { "chmod", "+x", pkginfo.install_dir() .. "/" .. exe }
    end
    payload.require(required_files(exe))
    return true
end

function config()
    xvm.add("freeze", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("freeze")
    return true
end

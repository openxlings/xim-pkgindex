-- Glow - Render markdown on the CLI, with pizzazz! (charmbracelet/glow).
--
-- Verified 2026-11-26 against upstream GitHub release v3.0.0 and
-- `checksums.txt`: every SHA256 below matched both upstream `checksums.txt`
-- and locally downloaded release archive bytes:
--   linux/x86_64    glow_3.0.0_Linux_x86_64.tar.gz    (static Go ELF, no .dynamic section)
--   linux/aarch64   glow_3.0.0_Linux_arm64.tar.gz     (static Go ELF, no .dynamic section)
--   macosx/x86_64   glow_3.0.0_Darwin_x86_64.tar.gz   (Mach-O 64-bit x86_64)
--   macosx/aarch64  glow_3.0.0_Darwin_arm64.tar.gz    (Mach-O 64-bit arm64)
--   windows/x86_64  glow_3.0.0_Windows_x86_64.zip     (PE32+ x86-64, imports kernel32.dll only)
--   windows/aarch64 omitted (upstream v3.0.0 does not publish a Windows arm64 archive)
--
-- All archives extract into a top-level directory matching the archive stem
-- (`glow_<ver>_<OS>_<arch>/`) containing `glow` (or `glow.exe`), `LICENSE`,
-- `README.md`, `completions/`, and `manpages/`.

package = {
    spec = "2",

    name = "glow",
    description = "Render markdown on the CLI, with pizzazz!",
    homepage = "https://github.com/charmbracelet/glow",
    authors = {"Charmbracelet"},
    maintainers = {"https://github.com/charmbracelet/glow/graphs/contributors"},
    licenses = {"MIT"},
    repo = "https://github.com/charmbracelet/glow",
    docs = "https://github.com/charmbracelet/glow#readme",

    ci = { mirror = true },

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"cli", "markdown", "viewer", "tools"},
    keywords = {"glow", "markdown", "cli", "tui", "charm", "go"},

    programs = {"glow"},
    xvm_enable = true,

    extensions = {
        autoupdate = {
            source = "https://github.com/charmbracelet/glow/releases",
            resources = {
                GLOBAL = {
                    url = {
                        linux = {
                            x86_64 = "https://github.com/charmbracelet/glow/releases/download/${tag}/glow_${version}_Linux_x86_64.tar.gz",
                            aarch64 = "https://github.com/charmbracelet/glow/releases/download/${tag}/glow_${version}_Linux_arm64.tar.gz",
                        },
                        macosx = {
                            x86_64 = "https://github.com/charmbracelet/glow/releases/download/${tag}/glow_${version}_Darwin_x86_64.tar.gz",
                            aarch64 = "https://github.com/charmbracelet/glow/releases/download/${tag}/glow_${version}_Darwin_arm64.tar.gz",
                        },
                        windows = {
                            x86_64 = "https://github.com/charmbracelet/glow/releases/download/${tag}/glow_${version}_Windows_x86_64.zip",
                        },
                    },
                    required = true,
                },
            },
        },
    },

    -- Upstream builds static Go binaries; Linux ELFs have no dynamic section and
    -- Windows PE32+ imports only kernel32.dll, so no runtime deps are needed.
    xpm = {
        linux = {
            source = "https://github.com/charmbracelet/glow/releases/download/v${version}/glow_${version}_Linux_${arch_alias}.tar.gz",
            ["latest"] = { ref = "3.0.0" },
            ["3.0.0"] = {
                arch_alias = { x86_64 = "x86_64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "13e05e4b2acc18d2aee44291aefe6325b077ec321b631a0cfa780e8e3bc33f78",
                    aarch64 = "810c39f4691feb75e675a5f5f54b9fa091354e7599d9cf9c9fc9b97e47a99759",
                },
            },
        },
        macosx = {
            source = "https://github.com/charmbracelet/glow/releases/download/v${version}/glow_${version}_Darwin_${arch_alias}.tar.gz",
            ["latest"] = { ref = "3.0.0" },
            ["3.0.0"] = {
                arch_alias = { x86_64 = "x86_64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "b911b90622e686d44bc072112898584a601ed8353276b735835d8cdbcc27f660",
                    aarch64 = "4b8a9a32412c0525e4c239e65171706fc5beb6d423608d99fe16788d47b345d3",
                },
            },
        },
        windows = {
            source = "https://github.com/charmbracelet/glow/releases/download/v${version}/glow_${version}_Windows_${arch_alias}.zip",
            ["latest"] = { ref = "3.0.0" },
            ["3.0.0"] = {
                arch_alias = { x86_64 = "x86_64" },
                sha256 = {
                    x86_64 = "d8907e07436ecbb6738bc0e3bbf8aa6159e351f95082e9db3c3fc4200086f809",
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
    return { exe, "LICENSE" }
end

function installed()
    return payload.present(required_files("glow"))
        or payload.present(required_files("glow.exe"))
end

function install()
    local archive = tostring(pkginfo.install_file() or "")
    if archive == "" then
        error("glow: install_file is empty")
    end

    local normalized = archive:gsub("\\", "/")
    local stem = (normalized:match("([^/]+)$") or ""):gsub("%.tar%.gz$", ""):gsub("%.zip$", "")
    local is_win = normalized:match("%.zip$") ~= nil
    local exe = is_win and "glow.exe" or "glow"

    payload.unpack{ extracted = stem, strip = 1 }
    if not is_win then
        shell.exec({ "chmod", "+x", pkginfo.install_dir() .. "/" .. exe })
    end
    payload.require(required_files(exe))
    return true
end

function config()
    xvm.add("glow", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("glow")
    return true
end

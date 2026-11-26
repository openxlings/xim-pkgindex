-- soft-serve - The mighty, self-hostable Git server for the command line (charmbracelet/soft-serve).
--
-- Verified 2026-11-26 against upstream charmbracelet/soft-serve release v0.12.4.
-- Every SHA256 below matches checksums.txt, GitHub release asset digests, and
-- locally downloaded archive bytes:
--   * linux   x86_64, aarch64   `.tar.gz` (`soft-serve_0.12.4_Linux_{x86_64,arm64}/`
--                               top-level directory); `soft` is a statically
--                               linked Go ELF with no dynamic section or external
--                               libc dependency (`readelf -d`, `ldd`).
--   * macosx  x86_64, aarch64   `.tar.gz` (`soft-serve_0.12.4_Darwin_{x86_64,arm64}/`
--                               top-level directory).
--   * windows x86_64            `.zip` (`soft-serve_0.12.4_Windows_x86_64/`
--                               top-level directory); `soft.exe` is a PE32+
--                               console executable importing only `kernel32.dll`
--                               (no VCRUNTIME DLL dependency). Upstream does not
--                               publish a Windows arm64 archive.

package = {
    spec = "2",

    name = "soft-serve",
    description = "The mighty, self-hostable Git server for the command line",
    homepage = "https://charm.sh",
    authors = {"Charmbracelet"},
    maintainers = {"Charmbracelet"},
    licenses = {"MIT"},
    repo = "https://github.com/charmbracelet/soft-serve",
    docs = "https://github.com/charmbracelet/soft-serve#readme",

    ci = { mirror = true },

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"git", "server", "cli", "tui", "tools"},
    keywords = {"soft-serve", "soft", "git", "ssh", "tui", "charm", "server", "go"},

    programs = {"soft"},
    xvm_enable = true,

    extensions = {
        autoupdate = {
            source = "https://github.com/charmbracelet/soft-serve/releases",
            resources = {
                GLOBAL = {
                    required = true,
                    url = {
                        linux = {
                            x86_64 = "https://github.com/charmbracelet/soft-serve/releases/download/${tag}/soft-serve_${version}_Linux_x86_64.tar.gz",
                            aarch64 = "https://github.com/charmbracelet/soft-serve/releases/download/${tag}/soft-serve_${version}_Linux_arm64.tar.gz",
                        },
                        macosx = {
                            x86_64 = "https://github.com/charmbracelet/soft-serve/releases/download/${tag}/soft-serve_${version}_Darwin_x86_64.tar.gz",
                            aarch64 = "https://github.com/charmbracelet/soft-serve/releases/download/${tag}/soft-serve_${version}_Darwin_arm64.tar.gz",
                        },
                        windows = {
                            x86_64 = "https://github.com/charmbracelet/soft-serve/releases/download/${tag}/soft-serve_${version}_Windows_x86_64.zip",
                        },
                    },
                },
            },
        },
    },

    xpm = {
        linux = {
            source = "https://github.com/charmbracelet/soft-serve/releases/download/v${version}/soft-serve_${version}_Linux_${arch_alias}.tar.gz",
            ["latest"] = { ref = "0.12.4" },
            ["0.12.4"] = {
                arch_alias = { x86_64 = "x86_64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "bcf2e49bd95c34946708a7efe8ed5040125f84ed213bbc1a4a59982811af636b",
                    aarch64 = "9f70fbd02577abcad05c9bf2c91cf22f6026f92da6ae0f834dcead65271153eb",
                },
            },
        },
        macosx = {
            source = "https://github.com/charmbracelet/soft-serve/releases/download/v${version}/soft-serve_${version}_Darwin_${arch_alias}.tar.gz",
            ["latest"] = { ref = "0.12.4" },
            ["0.12.4"] = {
                arch_alias = { x86_64 = "x86_64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "0b4a74de31c1fd6f523392c4e4238daa2d6f9bdf4f44c9420b5d5cf68e4a46e4",
                    aarch64 = "563a59bc8df53c0bfee712713a1a88c11cc9e6cad7973e1361afb9deb35af7b3",
                },
            },
        },
        windows = {
            source = "https://github.com/charmbracelet/soft-serve/releases/download/v${version}/soft-serve_${version}_Windows_${arch_alias}.zip",
            ["latest"] = { ref = "0.12.4" },
            ["0.12.4"] = {
                arch_alias = { x86_64 = "x86_64" },
                sha256 = {
                    x86_64 = "120af747596a55b241cd1fbff5923d913c578b1e39720a0cb894908c9ff72ee3",
                },
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.pkgindex.payload")

local function is_windows()
    if os.getenv("OS") == "Windows_NT" then return true end
    local dir = tostring(pkginfo.install_dir() or "")
    if dir:match("^[A-Za-z]:") or dir:find("\\", 1, true) then return true end
    local archive = tostring(pkginfo.install_file() or "")
    return archive:match("%.zip$") ~= nil
end

local function archive_stem(file)
    local basename = tostring(file or ""):gsub("\\", "/"):match("([^/]+)$") or ""
    return (basename:gsub("%.tar%.gz$", ""):gsub("%.zip$", ""))
end

function installed()
    return payload.present({ "soft", "LICENSE" })
        or payload.present({ "soft.exe", "LICENSE" })
end

function install()
    local archive = tostring(pkginfo.install_file() or "")
    if archive == "" then
        error("soft-serve: install_file is empty")
    end

    local stem = archive_stem(archive)
    local exe = is_windows() and "soft.exe" or "soft"

    payload.unpack{
        extracted = stem,
        strip = 1,
    }

    payload.require({ exe, "LICENSE" })
    return true
end

function config()
    xvm.add("soft", { bindir = pkginfo.install_dir() })
    -- Group placeholder: the binary is `soft`, while the package name is
    -- `soft-serve`. Registering `package.name` with `type = "group"` lets
    -- `xvm info soft-serve` and `xlings remove` locate the package without
    -- creating an orphan `soft-serve` shim in `bin/`.
    xvm.add(package.name, { type = "group" })
    return true
end

function uninstall()
    xvm.remove("soft")
    xvm.remove(package.name)
    return true
end

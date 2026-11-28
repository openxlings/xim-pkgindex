-- Mods - GPT on the command line. Built for pipelines. (charmbracelet/mods).
--
-- Verified 2026-11-26 against upstream GitHub release v1.8.1 and
-- `checksums.txt`: every SHA256 below matched both upstream `checksums.txt`
-- and locally downloaded release archive bytes:
--   linux/x86_64     mods_1.8.1_Linux_x86_64.tar.gz     (static Go ELF, no .dynamic section)
--   linux/aarch64    mods_1.8.1_Linux_arm64.tar.gz      (static Go ELF, no .dynamic section)
--   macosx/x86_64    mods_1.8.1_Darwin_x86_64.tar.gz    (Mach-O 64-bit x86_64)
--   macosx/aarch64   mods_1.8.1_Darwin_arm64.tar.gz     (Mach-O 64-bit arm64)
--   windows/x86_64   mods_1.8.1_Windows_x86_64.zip      (PE32+ x86-64)
--   windows/aarch64  mods_1.8.1_Windows_arm64.zip       (PE32+ ARM64)
--
-- All archives extract into a top-level directory matching the archive stem
-- (`mods_<ver>_<OS>_<arch>/`) containing `mods` (or `mods.exe`), `LICENSE`,
-- `README.md`, `completions/`, and `manpages/`.

package = {
    spec = "2",

    name = "mods",
    description = "GPT on the command line. Built for pipelines.",
    homepage = "https://github.com/charmbracelet/mods",
    authors = {"Charmbracelet"},
    maintainers = {"https://github.com/charmbracelet/mods/graphs/contributors"},
    licenses = {"MIT"},
    repo = "https://github.com/charmbracelet/mods",
    docs = "https://github.com/charmbracelet/mods#readme",

    ci = { mirror = true },

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"cli", "ai", "llm", "tools"},
    keywords = {"mods", "ai", "llm", "gpt", "cli", "charm", "go"},

    programs = {"mods"},
    xvm_enable = true,

    extensions = {
        autoupdate = {
            source = "https://github.com/charmbracelet/mods/releases",
            resources = {
                GLOBAL = {
                    url = {
                        linux = {
                            x86_64 = "https://github.com/charmbracelet/mods/releases/download/${tag}/mods_${version}_Linux_x86_64.tar.gz",
                            aarch64 = "https://github.com/charmbracelet/mods/releases/download/${tag}/mods_${version}_Linux_arm64.tar.gz",
                        },
                        macosx = {
                            x86_64 = "https://github.com/charmbracelet/mods/releases/download/${tag}/mods_${version}_Darwin_x86_64.tar.gz",
                            aarch64 = "https://github.com/charmbracelet/mods/releases/download/${tag}/mods_${version}_Darwin_arm64.tar.gz",
                        },
                        windows = {
                            x86_64 = "https://github.com/charmbracelet/mods/releases/download/${tag}/mods_${version}_Windows_x86_64.zip",
                            aarch64 = "https://github.com/charmbracelet/mods/releases/download/${tag}/mods_${version}_Windows_arm64.zip",
                        },
                    },
                    required = true,
                },
            },
        },
    },

    -- Upstream builds static Go binaries; Linux ELFs have no dynamic section.
    xpm = {
        linux = {
            source = "https://github.com/charmbracelet/mods/releases/download/v${version}/mods_${version}_Linux_${arch_alias}.tar.gz",
            ["latest"] = { ref = "1.8.1" },
            ["1.8.1"] = {
                arch_alias = { x86_64 = "x86_64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "a3313f3064f7c104835e1f9c53788524cfafc1675c1e18fca786b7051766745d",
                    aarch64 = "448d205e27e1ec0cb4e185275ff826e93b16182d35977652db01e4d475b1b671",
                },
            },
        },
        macosx = {
            source = "https://github.com/charmbracelet/mods/releases/download/v${version}/mods_${version}_Darwin_${arch_alias}.tar.gz",
            ["latest"] = { ref = "1.8.1" },
            ["1.8.1"] = {
                arch_alias = { x86_64 = "x86_64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "0ae5f55ae1764fd47c347a7b4e75b71dbcdbb41e56c64bf90be4f1481dba0377",
                    aarch64 = "a09528a438487fbda43809d5adcbc4211a5020bd69372ff0d319a8f28bd900b2",
                },
            },
        },
        windows = {
            source = "https://github.com/charmbracelet/mods/releases/download/v${version}/mods_${version}_Windows_${arch_alias}.zip",
            ["latest"] = { ref = "1.8.1" },
            ["1.8.1"] = {
                arch_alias = { x86_64 = "x86_64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "ecad2f4d526bcb853b91136c2b40a123b0127edaca20945378986ceb6d89a52a",
                    aarch64 = "6b409c753dfe9d5d35c4bf3ff7fba8d34508dbe2f8e38b092c6d7539abe0910d",
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
    return payload.present(required_files("mods"))
        or payload.present(required_files("mods.exe"))
end

function install()
    local archive = tostring(pkginfo.install_file() or "")
    if archive == "" then
        error("mods: install_file is empty")
    end

    local normalized = archive:gsub("\\", "/")
    local stem = (normalized:match("([^/]+)$") or ""):gsub("%.tar%.gz$", ""):gsub("%.zip$", "")
    local is_win = normalized:match("%.zip$") ~= nil
    local exe = is_win and "mods.exe" or "mods"

    payload.unpack{ extracted = stem, strip = 1 }
    if not is_win then
        shell.exec({ "chmod", "+x", pkginfo.install_dir() .. "/" .. exe })
    end
    payload.require(required_files(exe))
    return true
end

function config()
    xvm.add("mods", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("mods")
    return true
end

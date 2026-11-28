-- Crush: upstream portable archives, verified against v0.103.0 checksums.txt.
-- Linux x86_64/aarch64 are CGO-disabled static ELF (no interpreter/DT_NEEDED);
-- SQLite does not require a host library. Darwin and Windows ship both arches.
-- Archives wrap all files in crush_<version>_<Linux|Darwin|Windows>_<arch>/.
-- Preserve LICENSE.md, README, completions and manpage inside the package;
-- no shell integration, provider credentials or user configuration is installed.
-- LICENSE.md is FSL-1.1-MIT (non-competing purposes only; MIT after two years),
-- plus inherited MIT notices. Redistribution must retain the terms/link and
-- copyright notices. This release is NOT presently MIT-only/open-source.

package = {
    spec = "2",
    name = "crush",
    description = "A terminal-first AI assistant for software development",
    homepage = "https://charm.sh/crush",
    authors = {"Charmbracelet, Inc."},
    maintainers = {"charmbracelet"},
    licenses = {"FSL-1.1-MIT", "MIT"},
    repo = "https://github.com/charmbracelet/crush",
    docs = "https://github.com/charmbracelet/crush#readme",
    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"cli", "development", "ai", "tools"},
    keywords = {"crush", "charm", "ai", "coding", "assistant"},
    programs = {"crush"},
    xvm_enable = true,

    -- Only official upstream resources; no unverified regional mirror.
    extensions = {
        autoupdate = {
            source = "https://github.com/charmbracelet/crush/releases",
            resources = {
                GLOBAL = {
                    required = true,
                    url = {
                        linux = {
                            x86_64 = "https://github.com/charmbracelet/crush/releases/download/${tag}/crush_${version}_Linux_x86_64.tar.gz",
                            aarch64 = "https://github.com/charmbracelet/crush/releases/download/${tag}/crush_${version}_Linux_arm64.tar.gz",
                        },
                        macosx = {
                            x86_64 = "https://github.com/charmbracelet/crush/releases/download/${tag}/crush_${version}_Darwin_x86_64.tar.gz",
                            aarch64 = "https://github.com/charmbracelet/crush/releases/download/${tag}/crush_${version}_Darwin_arm64.tar.gz",
                        },
                        windows = {
                            x86_64 = "https://github.com/charmbracelet/crush/releases/download/${tag}/crush_${version}_Windows_x86_64.zip",
                            aarch64 = "https://github.com/charmbracelet/crush/releases/download/${tag}/crush_${version}_Windows_arm64.zip",
                        },
                    },
                },
            },
        },
    },

    xpm = {
        linux = {
            source = "https://github.com/charmbracelet/crush/releases/download/v${version}/crush_${version}_Linux_${arch_alias}.tar.gz",
            ["latest"] = { ref = "0.103.0" },
            ["0.103.0"] = {
                arch_alias = { x86_64 = "x86_64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "ecdec661e2936844fe988499a4f5dfbf0cba259cba6bdef5ad9052a9d92c0897",
                    aarch64 = "5758bf5bcf24476c0eaf55e0f244cf847fcef0782f5f149abbba1f1db5dc6eea",
                },
            },
        },
        macosx = {
            source = "https://github.com/charmbracelet/crush/releases/download/v${version}/crush_${version}_Darwin_${arch_alias}.tar.gz",
            ["latest"] = { ref = "0.103.0" },
            ["0.103.0"] = {
                arch_alias = { x86_64 = "x86_64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "4c0d57c8ffa2d7ad3bb453c9514842773bca2b489ec5186eccb3f03019a7f6de",
                    aarch64 = "d09bbdab30fc09498a29c096551f4acf53eb7d6abad87a0c1a408855342aab1f",
                },
            },
        },
        windows = {
            source = "https://github.com/charmbracelet/crush/releases/download/v${version}/crush_${version}_Windows_${arch_alias}.zip",
            ["latest"] = { ref = "0.103.0" },
            ["0.103.0"] = {
                arch_alias = { x86_64 = "x86_64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "e5845ae5cc160c7ea47c33fd96035d5361246db9efb2ed7a22ea6c1cfe718753",
                    aarch64 = "5d7d154fc2da4375a71e46a5383c5ba77943864720e8f9b8aa0e803a4147ddba",
                },
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.pkgindex.payload")

function installed()
    return payload.present({"crush", "LICENSE.md"})
        or payload.present({"crush.exe", "LICENSE.md"})
end

function install()
    local archive = tostring(pkginfo.install_file()):gsub("\\", "/")
    local name = archive:match("([^/]+)$")
    local is_zip = name:match("%.zip$") ~= nil
    local root = name:gsub("%.tar%.gz$", ""):gsub("%.zip$", "")
    -- The shared helper moves the pre-extracted root, or uses Windows system
    -- tar with one component stripped. Keep the upstream executable mode.
    payload.unpack{ extracted = root, strip = 1 }
    payload.require({is_zip and "crush.exe" or "crush", "LICENSE.md"})
    return true
end

function config()
    xvm.add("crush", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("crush")
    return true
end

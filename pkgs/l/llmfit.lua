-- llmfit recommends local LLMs for a machine's hardware; it also ships an
-- offline model catalog and CLI/TUI. No model or service is started by hooks.
-- Verified upstream v1.1.21 (2026-11-23): all six archive SHA256 values match
-- GitHub release digests, official .sha256 sidecars, and downloaded bytes.
-- Each archive has one llmfit-v<version>-<target>/ directory containing the
-- executable, LICENSE and README.md. Linux musl binaries have no PT_INTERP or
-- DT_NEEDED entries (x86_64 static PIE; aarch64 static ELF).
-- Installation only lands this payload; config/uninstall only add/remove the
-- llmfit xvm route. Shell profiles and system configuration are untouched.
package = {
    spec = "2",
    name = "llmfit",
    description = "Find which local LLMs fit your hardware",
    homepage = "https://github.com/AlexsJones/llmfit",
    authors = {"Alex Jones"},
    maintainers = {"https://github.com/AlexsJones/llmfit/graphs/contributors"},
    licenses = {"MIT"},
    repo = "https://github.com/AlexsJones/llmfit",
    docs = "https://github.com/AlexsJones/llmfit/blob/main/docs/cli.md",

    ci = { mirror = true },
    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"cli", "ai", "tools"},
    keywords = {"llmfit", "llm", "hardware", "models", "tui"},
    programs = {"llmfit"},
    xvm_enable = true,

    extensions = {
        autoupdate = {
            source = "https://github.com/AlexsJones/llmfit/releases",
            resources = {
                GLOBAL = {
                    url = {
                        linux = {
                            x86_64 = "https://github.com/AlexsJones/llmfit/releases/download/${tag}/llmfit-v${version}-x86_64-unknown-linux-musl.tar.gz",
                            aarch64 = "https://github.com/AlexsJones/llmfit/releases/download/${tag}/llmfit-v${version}-aarch64-unknown-linux-musl.tar.gz",
                        },
                        macosx = {
                            x86_64 = "https://github.com/AlexsJones/llmfit/releases/download/${tag}/llmfit-v${version}-x86_64-apple-darwin.tar.gz",
                            aarch64 = "https://github.com/AlexsJones/llmfit/releases/download/${tag}/llmfit-v${version}-aarch64-apple-darwin.tar.gz",
                        },
                        windows = {
                            x86_64 = "https://github.com/AlexsJones/llmfit/releases/download/${tag}/llmfit-v${version}-x86_64-pc-windows-msvc.zip",
                            aarch64 = "https://github.com/AlexsJones/llmfit/releases/download/${tag}/llmfit-v${version}-aarch64-pc-windows-msvc.zip",
                        },
                    },
                    required = true,
                },
            },
        },
    },

    xpm = {
        linux = {
            source = "https://github.com/AlexsJones/llmfit/releases/download/v${version}/llmfit-v${version}-${arch}-unknown-linux-musl.tar.gz",
            ["latest"] = { ref = "1.1.21" },
            ["1.1.21"] = {
                sha256 = {
                    x86_64 = "5cb718af4ff5b38ed128dbb484be72aded58d40068bf3b8428d0726ce9c7d748",
                    aarch64 = "bd981b81a953e252cebb23207bacda43563a1e35358aabb25b182883a2e039cf",
                },
            },
        },
        macosx = {
            source = "https://github.com/AlexsJones/llmfit/releases/download/v${version}/llmfit-v${version}-${arch}-apple-darwin.tar.gz",
            ["latest"] = { ref = "1.1.21" },
            ["1.1.21"] = {
                sha256 = {
                    x86_64 = "4b372792c9064260e032b5398311b8c268017e86e7391cb8455049e40f205ca6",
                    aarch64 = "7aa7aba256ded3697dfaf66d5f177c1b6fbfa8c83683bd6f4d2a9ce821c491f7",
                },
            },
        },
        windows = {
            source = "https://github.com/AlexsJones/llmfit/releases/download/v${version}/llmfit-v${version}-${arch}-pc-windows-msvc.zip",
            ["latest"] = { ref = "1.1.21" },
            ["1.1.21"] = {
                sha256 = {
                    x86_64 = "c2f98f41121d01df68eb2dd4b86c3269537c8c96d24dd22de3e07e093c329d43",
                    aarch64 = "4c839f2b8f4567e9ea73b6167726c0107d7382595c5cc78045c36d81cd774167",
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
    return payload.present(required_files("llmfit"))
        or payload.present(required_files("llmfit.exe"))
end

function install()
    local archive = tostring(pkginfo.install_file() or "")
    if archive == "" then error("llmfit: install_file is empty") end
    local normalized = archive:gsub("\\", "/")
    local stem = (normalized:match("([^/]+)$") or ""):gsub("%.tar%.gz$", ""):gsub("%.zip$", "")
    local is_win = normalized:match("%.zip$") ~= nil
    local exe = is_win and "llmfit.exe" or "llmfit"
    payload.unpack{ extracted = stem, strip = 1 }
    if not is_win then
        shell.exec({ "chmod", "+x", pkginfo.install_dir() .. "/" .. exe })
    end
    payload.require(required_files(exe))
    return true
end

function config()
    xvm.add("llmfit", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("llmfit")
    return true
end

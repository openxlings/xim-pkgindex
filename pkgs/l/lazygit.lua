-- lazygit - simple terminal UI for git commands.
--
-- Platform and architecture coverage (upstream v0.66.3 release):
--   linux    x86_64, aarch64   static Go ELF binary (`lazygit` at archive root)
--   macosx   x86_64, aarch64   official Mach-O binary (`lazygit` at archive root)
--   windows  x86_64, aarch64   official PE binary (`lazygit.exe` at archive root)
--
-- All archives are flat (LICENSE, README.md, and lazygit/lazygit.exe sit
-- directly at the archive root with no enclosing folder). Linux binaries are
-- statically linked Go executables with no dynamic section (no runtime deps).

package = {
    spec = "2",

    name = "lazygit",
    description = "Simple terminal UI for git commands",
    homepage = "https://github.com/jesseduffield/lazygit",
    authors = {"Jesse Duffield"},
    maintainers = {"Jesse Duffield"},
    licenses = {"MIT"},
    repo = "https://github.com/jesseduffield/lazygit",
    docs = "https://github.com/jesseduffield/lazygit#readme",

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"git", "tui", "cli", "tools"},
    keywords = {"git", "lazygit", "tui", "cli", "go"},

    programs = {"lazygit"},
    xvm_enable = true,
    ci = { mirror = true },

    extensions = {
        autoupdate = {
            source = "https://github.com/jesseduffield/lazygit/releases",
            resources = {
                GLOBAL = {
                    url = {
                        linux = {
                            x86_64 = "https://github.com/jesseduffield/lazygit/releases/download/v${version}/lazygit_${version}_linux_x86_64.tar.gz",
                            aarch64 = "https://github.com/jesseduffield/lazygit/releases/download/v${version}/lazygit_${version}_linux_arm64.tar.gz",
                        },
                        macosx = {
                            x86_64 = "https://github.com/jesseduffield/lazygit/releases/download/v${version}/lazygit_${version}_darwin_x86_64.tar.gz",
                            aarch64 = "https://github.com/jesseduffield/lazygit/releases/download/v${version}/lazygit_${version}_darwin_arm64.tar.gz",
                        },
                        windows = {
                            x86_64 = "https://github.com/jesseduffield/lazygit/releases/download/v${version}/lazygit_${version}_windows_x86_64.zip",
                            aarch64 = "https://github.com/jesseduffield/lazygit/releases/download/v${version}/lazygit_${version}_windows_arm64.zip",
                        },
                    },
                    required = true,
                },
            },
        },
    },

    xpm = {
        linux = {
            ["latest"] = { ref = "0.66.3" },
            ["0.66.3"] = {
                x86_64 = {
                    url = "https://github.com/jesseduffield/lazygit/releases/download/v0.66.3/lazygit_0.66.3_linux_x86_64.tar.gz",
                    sha256 = "0a23f429a95f0d09db298b3c291536d818de066aa5a85c255806f0490ff6656b",
                },
                aarch64 = {
                    url = "https://github.com/jesseduffield/lazygit/releases/download/v0.66.3/lazygit_0.66.3_linux_arm64.tar.gz",
                    sha256 = "ac0b48237f3d0283813e7154ec063237e519532feb0470c0881a1793ee78fd42",
                },
            },
        },
        macosx = {
            ["latest"] = { ref = "0.66.3" },
            ["0.66.3"] = {
                x86_64 = {
                    url = "https://github.com/jesseduffield/lazygit/releases/download/v0.66.3/lazygit_0.66.3_darwin_x86_64.tar.gz",
                    sha256 = "f6c116c09b960842351e3e142cc8be1784de611f19d09920421bd7639cccd30b",
                },
                aarch64 = {
                    url = "https://github.com/jesseduffield/lazygit/releases/download/v0.66.3/lazygit_0.66.3_darwin_arm64.tar.gz",
                    sha256 = "6873e6b7a538b521c4d7ff3f76ec49e6dcafa41e6053a6aae33c12f62663e163",
                },
            },
        },
        windows = {
            ["latest"] = { ref = "0.66.3" },
            ["0.66.3"] = {
                x86_64 = {
                    url = "https://github.com/jesseduffield/lazygit/releases/download/v0.66.3/lazygit_0.66.3_windows_x86_64.zip",
                    sha256 = "a76fe17339fd387c20addc09060f07c240e4b20a9f55fee4ad7c86a251c0741e",
                },
                aarch64 = {
                    url = "https://github.com/jesseduffield/lazygit/releases/download/v0.66.3/lazygit_0.66.3_windows_arm64.zip",
                    sha256 = "c8b3b7141387f9c317b098147cf674166154a98dcad3fcd322b07c882ba1eed4",
                },
            },
        },
    },
}

import("xim.libxpkg.fs")
import("xim.libxpkg.pkginfo")
import("xim.libxpkg.system")
import("xim.libxpkg.xvm")
import("xim.pkgindex.winpath")

function installed()
    local dir = pkginfo.install_dir()
    return os.isfile(dir .. "/lazygit.exe") or os.isfile(dir .. "/lazygit")
end

function install()
    local archive = tostring(pkginfo.install_file() or "")
    if archive == "" then
        error("lazygit: install_file is empty")
    end

    local dir = pkginfo.install_dir()
    local normalized = archive:gsub("\\", "/")
    local download_dir = normalized:match("^(.*)/[^/]+$") or "."
    local is_win = normalized:match("%.zip$") ~= nil
    local exe = is_win and "lazygit.exe" or "lazygit"
    local pre_extracted = download_dir .. "/" .. exe

    os.tryrm(dir)
    fs.mkdir_p(dir)

    if os.isfile(pre_extracted) then
        os.mv(pre_extracted, dir .. "/" .. exe)
    elseif os.isfile(archive) then
        if is_win then
            local sysroot = winpath.native(os.getenv("SystemRoot") or "C:\\Windows"):gsub("\\+$", "")
            local systar = sysroot .. "\\System32\\tar.exe"
            -- exec-quoting-ok: the first token is the system's tar.exe, which cmd.exe must see unquoted
            system.exec(string.format('%s -xf "%s" -C "%s"', systar, winpath.native(archive), winpath.native(dir)))
        else
            system.exec(string.format([[tar -xzf "%s" -C "%s"]], normalized, dir))
        end
    else
        error("lazygit: neither extracted binary (" .. pre_extracted .. ") nor archive (" .. archive .. ") exists")
    end

    if not is_win and os.isfile(dir .. "/" .. exe) then
        system.exec(string.format([[chmod +x "%s"]], dir .. "/" .. exe))
    end

    if not installed() then
        error("lazygit: " .. exe .. " is missing after install in " .. dir)
    end
    return true
end

function config()
    xvm.add("lazygit", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("lazygit")
    return true
end

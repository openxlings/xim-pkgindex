-- grex generates regular expressions from user-provided test cases.
-- Verified v1.4.6 against GitHub asset digests and all six downloaded archives.
-- Archives are flat and contain only grex/grex.exe (no bundled license docs).
-- Upstream LICENSE and Cargo.toml identify Apache-2.0, not a dual license.
-- Linux musl binaries are static; macOS has native x86_64/aarch64 Mach-O.
-- Both Windows binaries import VCRUNTIME140.dll. Only x86_64 is advertised:
-- xim:vcruntime currently supplies x64 DLLs, not the upstream ARM64 binary's CRT.

package = {
    spec = "2",
    name = "grex",
    description = "Generate regular expressions from user-provided test cases",
    homepage = "https://github.com/pemistahl/grex",
    authors = {"Peter M. Stahl"},
    maintainers = {"https://github.com/pemistahl/grex/graphs/contributors"},
    licenses = {"Apache-2.0"},
    repo = "https://github.com/pemistahl/grex",
    docs = "https://github.com/pemistahl/grex#readme",
    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"tools", "cli"},
    keywords = {"grex", "regex", "regular-expression", "generator", "rust"},
    programs = {"grex"},
    xvm_enable = true,
    ci = { mirror = true },

    extensions = {
        autoupdate = {
            source = "https://github.com/pemistahl/grex/releases",
            resources = {
                GLOBAL = {
                    required = true,
                    url = {
                        linux = {
                            x86_64 = "https://github.com/pemistahl/grex/releases/download/${tag}/grex-v${version}-x86_64-unknown-linux-musl.tar.gz",
                            aarch64 = "https://github.com/pemistahl/grex/releases/download/${tag}/grex-v${version}-aarch64-unknown-linux-musl.tar.gz",
                        },
                        macosx = {
                            x86_64 = "https://github.com/pemistahl/grex/releases/download/${tag}/grex-v${version}-x86_64-apple-darwin.tar.gz",
                            aarch64 = "https://github.com/pemistahl/grex/releases/download/${tag}/grex-v${version}-aarch64-apple-darwin.tar.gz",
                        },
                        windows = {
                            x86_64 = "https://github.com/pemistahl/grex/releases/download/${tag}/grex-v${version}-x86_64-pc-windows-msvc.zip",
                        },
                    },
                },
            },
        },
    },

    xpm = {
        linux = {
            source = "https://github.com/pemistahl/grex/releases/download/v${version}/grex-v${version}-${arch}-unknown-linux-musl.tar.gz",
            ["latest"] = { ref = "1.4.6" },
            ["1.4.6"] = {
                sha256 = {
                    x86_64 = "8f02f4ebe72d9e3098c646b77f7bc53ec8a8c1fb51ed042db06b739d08e56af8",
                    aarch64 = "65ac2010ffc4a02690b091819f2971c0b26081b2ce7cb717a0de3f10409010b9",
                },
            },
        },
        macosx = {
            source = "https://github.com/pemistahl/grex/releases/download/v${version}/grex-v${version}-${arch}-apple-darwin.tar.gz",
            ["latest"] = { ref = "1.4.6" },
            ["1.4.6"] = {
                sha256 = {
                    x86_64 = "a7d347a83fe600f0078dd539e316b5789200305f0707d60ae8964c36c24d9600",
                    aarch64 = "5a249c9c7866835f8b0be95475fc49189da412c09f95266ffa8401b85c094078",
                },
            },
        },
        windows = {
            deps = { runtime = { "xim:vcruntime" } },
            source = "https://github.com/pemistahl/grex/releases/download/v${version}/grex-v${version}-${arch}-pc-windows-msvc.zip",
            ["latest"] = { ref = "1.4.6" },
            ["1.4.6"] = {
                sha256 = {
                    x86_64 = "7691dbb8e46339a15d8362b79b2456f508266cf00a55fe685ed69a6259577485",
                },
            },
        },
    },
}

import("xim.libxpkg.fs")
import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.pkgindex.payload")
import("xim.pkgindex.shell")

local function required_files(exe)
    local files, crt = { exe }, nil
    if exe == "grex.exe" then
        crt = pkginfo.dep_install_dir("xim:vcruntime")
        local dlls = crt and fs.files(crt .. "/bin") or {}
        if not dlls or #dlls == 0 then return nil end
        -- The runtime provider owns its filenames; require its complete set.
        for _, dll in ipairs(dlls) do
            files[#files + 1] = dll:gsub("\\", "/"):match("([^/]+)$")
        end
    end
    return files, crt
end

function installed()
    if payload.present(required_files("grex")) then return true end
    local required = required_files("grex.exe")
    return required ~= nil and payload.present(required)
end

function install()
    local archive = tostring(pkginfo.install_file() or "")
    if archive == "" then error("grex: install_file is empty") end
    local dir = pkginfo.install_dir()
    local normalized = archive:gsub("\\", "/")
    local parent = normalized:match("^(.*)/[^/]+$") or "."
    local is_win = normalized:match("%.zip$") ~= nil
    local exe = is_win and "grex.exe" or "grex"
    local required, crt = required_files(exe)
    assert(required, "grex: xim:vcruntime payload directory is missing or empty")

    -- Extract just this archive, never move the shared download directory.
    if is_win then
        payload.unpack{}
        for i = 2, #required do
            os.cp(crt .. "/bin/" .. required[i], dir)
        end
    else
        os.tryrm(dir)
        fs.mkdir_p(dir)
        if os.isfile(archive) then
            shell.exec({ "tar", "-xzf", archive, "-C", dir })
        elseif os.isfile(parent .. "/" .. exe) then
            -- libxpkg may have already unpacked and removed the tarball.
            os.mv(parent .. "/" .. exe, dir .. "/" .. exe)
        else
            error("grex: archive and pre-extracted executable are missing")
        end
        shell.exec({ "chmod", "+x", dir .. "/" .. exe })
    end
    payload.require(required)
    return true
end

function config()
    xvm.add("grex", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("grex")
    return true
end

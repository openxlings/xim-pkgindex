-- Dufs - a distinctive utility file server (sigoden/dufs).
--
-- Platform and architecture coverage (verified 2026-11-26 against v0.47.0):
--   linux    x86_64    dufs-v<ver>-x86_64-unknown-linux-musl.tar.gz   (static-pie ELF, zero DT_NEEDED)
--   linux    aarch64   dufs-v<ver>-aarch64-unknown-linux-musl.tar.gz  (statically linked ELF, no .dynamic section)
--   macosx   x86_64    dufs-v<ver>-x86_64-apple-darwin.tar.gz         (Mach-O 64-bit x86_64)
--   macosx   aarch64   dufs-v<ver>-aarch64-apple-darwin.tar.gz        (Mach-O 64-bit arm64)
--   windows  x86_64    dufs-v<ver>-x86_64-pc-windows-msvc.zip         (PE32+ CUI; imports VCRUNTIME140.dll -> xim:vcruntime)
--   windows  aarch64   omitted: dufs-v<ver>-aarch64-pc-windows-msvc.zip also imports
--                      VCRUNTIME140.dll, while xim:vcruntime currently supports x86_64 only.
--
-- Every upstream archive is flat at root (single `dufs` or `dufs.exe` binary),
-- verified against GitHub release asset digests and locally computed SHA-256 checksums.

package = {
    spec = "2",

    name = "dufs",
    description = "A file server that supports static serving, uploading, searching, accessing control, webdav...",
    homepage = "https://github.com/sigoden/dufs",
    authors = {"sigoden"},
    maintainers = {"sigoden"},
    licenses = {"MIT", "Apache-2.0"},
    repo = "https://github.com/sigoden/dufs",
    docs = "https://github.com/sigoden/dufs#readme",

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"web", "server", "http", "webdav", "cli", "tools"},
    keywords = {"dufs", "file-server", "http", "webdav", "static-server", "rust"},

    programs = {"dufs"},
    xvm_enable = true,
    ci = { mirror = true },

    extensions = {
        autoupdate = {
            source = "https://github.com/sigoden/dufs/releases",
            resources = {
                GLOBAL = {
                    required = true,
                    url = {
                        linux = {
                            x86_64 = "https://github.com/sigoden/dufs/releases/download/${tag}/dufs-${tag}-x86_64-unknown-linux-musl.tar.gz",
                            aarch64 = "https://github.com/sigoden/dufs/releases/download/${tag}/dufs-${tag}-aarch64-unknown-linux-musl.tar.gz",
                        },
                        macosx = {
                            x86_64 = "https://github.com/sigoden/dufs/releases/download/${tag}/dufs-${tag}-x86_64-apple-darwin.tar.gz",
                            aarch64 = "https://github.com/sigoden/dufs/releases/download/${tag}/dufs-${tag}-aarch64-apple-darwin.tar.gz",
                        },
                        windows = {
                            x86_64 = "https://github.com/sigoden/dufs/releases/download/${tag}/dufs-${tag}-x86_64-pc-windows-msvc.zip",
                        },
                    },
                },
            },
        },
    },

    xpm = {
        linux = {
            source = "https://github.com/sigoden/dufs/releases/download/v${version}/dufs-v${version}-${arch}-unknown-linux-musl.tar.gz",
            ["latest"] = { ref = "0.47.0" },
            ["0.47.0"] = {
                sha256 = {
                    x86_64 = "c715c44b195f6133ca0f47e6fdc8d6015ec64b7fd9ac8e1c578ca23a92206aa4",
                    aarch64 = "faf1c961ad47c5d636b14956b6279e1278453517cd5d3c274d21d522b495800a",
                },
            },
        },
        macosx = {
            source = "https://github.com/sigoden/dufs/releases/download/v${version}/dufs-v${version}-${arch}-apple-darwin.tar.gz",
            ["latest"] = { ref = "0.47.0" },
            ["0.47.0"] = {
                sha256 = {
                    x86_64 = "f7df8da364ea46aefbc456855ac44bbfbbd05972ab99f966d09e2b4541d55039",
                    aarch64 = "8a9dd5f67f1d32e5808ca3cf1b5499322cd48d2cc82562b1984b49ebaef331ee",
                },
            },
        },
        windows = {
            deps = {
                runtime = { "xim:vcruntime" },
            },
            source = "https://github.com/sigoden/dufs/releases/download/v${version}/dufs-v${version}-${arch}-pc-windows-msvc.zip",
            -- Windows ARM64 imports VCRUNTIME140.dll and awaits `xim:vcruntime` ARM64 support.
            ["latest"] = { ref = "0.47.0" },
            ["0.47.0"] = {
                sha256 = {
                    x86_64 = "39a000b70de423b7200f17099fa734cb6e154d8c6ef6a7d4ec9b2961cb66d0f1",
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

local function is_windows()
    if os.getenv("OS") == "Windows_NT" then return true end
    local dir = tostring(pkginfo.install_dir() or "")
    if dir:match("^[A-Za-z]:") or dir:find("\\", 1, true) then return true end
    local archive = tostring(pkginfo.install_file() or "")
    return archive:match("%.zip$") ~= nil
end

function installed()
    return payload.present({ "dufs" })
        or payload.present({ "dufs.exe" })
end

function install()
    local archive = tostring(pkginfo.install_file() or "")
    if archive == "" then
        error("dufs: install_file is empty")
    end

    local dir = pkginfo.install_dir()
    local normalized = archive:gsub("\\", "/")
    local parent = normalized:match("^(.*)/[^/]+$") or "."
    local is_win = is_windows()
    local exe = is_win and "dufs.exe" or "dufs"

    os.tryrm(dir)

    -- Archives are flat (no enclosing directory): extract directly from
    -- install_file into a clean install_dir so unrelated files in the shared
    -- runtime download directory cannot leak into the payload.
    if is_win then
        payload.unpack{}
        if not pkginfo.dep_install_dir then
            error("dufs: xim:vcruntime runtime dep lookup is unavailable")
        end
        local crt = assert(pkginfo.dep_install_dir("xim:vcruntime"),
                           "dufs: xim:vcruntime payload directory is missing")
        local copied = 0
        for _, dll in ipairs(fs.files(crt .. "/bin") or {}) do
            os.cp(dll, dir)
            copied = copied + 1
        end
        if copied == 0 then
            error("dufs: no CRT DLLs found in " .. crt .. "/bin")
        end
    elseif os.isfile(archive) then
        fs.mkdir_p(dir)
        shell.exec({ "tar", "-xzf", archive, "-C", dir })
        shell.exec({ "chmod", "+x", dir .. "/" .. exe })
    elseif os.isfile(parent .. "/" .. exe) then
        fs.mkdir_p(dir)
        os.mv(parent .. "/" .. exe, dir .. "/" .. exe)
        shell.exec({ "chmod", "+x", dir .. "/" .. exe })
    else
        error("dufs: archive not found at " .. archive .. " and no extracted " .. exe .. " in " .. parent)
    end

    payload.require({ exe })
    return true
end

function config()
    xvm.add("dufs", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("dufs")
    return true
end

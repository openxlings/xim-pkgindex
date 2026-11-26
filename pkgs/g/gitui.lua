-- gitui - blazing fast terminal-ui for git written in Rust (gitui-org/gitui).
--
-- Platform and architecture coverage (verified against upstream v0.28.1):
--   linux    x86_64    gitui-linux-x86_64.tar.gz   (static-pie musl ELF, no PT_INTERP, zero DT_NEEDED)
--   linux    aarch64   gitui-linux-aarch64.tar.gz  (dynamic ELF: libgcc_s.so.1 [GCC_4.2.0],
--                                                   libpthread.so.0, libm.so.6, libdl.so.2,
--                                                   libc.so.6 [GLIBC_2.28] -> xim:glibc@>=2.39, xim:gcc-runtime)
--   macosx   x86_64    gitui-mac-x86.tar.gz        (Mach-O 64-bit x86_64)
--   macosx   aarch64   gitui-mac.tar.gz            (Mach-O 64-bit arm64)
--   windows  x86_64    gitui-win.tar.gz            (PE32+ x86-64; imports VCRUNTIME140.dll and UCRT API sets
--                                                   -> app-local xim:vcruntime beside gitui.exe)
--   windows  aarch64   omitted: upstream publishes no Windows ARM64 asset and xim:vcruntime is x86_64-only.
--
-- All archives are flat .tar.gz containing only `gitui` (or `gitui.exe`) at the archive root.
-- Note: `gitui /?` exits immediately (exit 2: unexpected argument '/?') without opening the TUI.

package = {
    spec = "2",

    name = "gitui",
    description = "Blazing fast terminal-ui for git written in Rust",
    homepage = "https://github.com/gitui-org/gitui",
    authors = {"Stephan Dilly"},
    maintainers = {"https://github.com/gitui-org/gitui/graphs/contributors"},
    licenses = {"MIT"},
    repo = "https://github.com/gitui-org/gitui",
    docs = "https://github.com/gitui-org/gitui#readme",

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"git", "tui", "cli", "tools"},
    keywords = {"git", "gitui", "tui", "cli", "rust"},

    programs = {"gitui"},
    xvm_enable = true,
    ci = { mirror = true },

    extensions = {
        autoupdate = {
            source = "https://github.com/gitui-org/gitui/releases",
            resources = {
                GLOBAL = {
                    required = true,
                    url = {
                        linux = {
                            x86_64 = "https://github.com/gitui-org/gitui/releases/download/${tag}/gitui-linux-x86_64.tar.gz",
                            aarch64 = "https://github.com/gitui-org/gitui/releases/download/${tag}/gitui-linux-aarch64.tar.gz",
                        },
                        macosx = {
                            x86_64 = "https://github.com/gitui-org/gitui/releases/download/${tag}/gitui-mac-x86.tar.gz",
                            aarch64 = "https://github.com/gitui-org/gitui/releases/download/${tag}/gitui-mac.tar.gz",
                        },
                        windows = {
                            x86_64 = "https://github.com/gitui-org/gitui/releases/download/${tag}/gitui-win.tar.gz",
                        },
                    },
                },
            },
        },
    },

    xpm = {
        linux = {
            deps = {
                runtime = { "xim:glibc@>=2.39", "xim:gcc-runtime" },
            },
            source = "https://github.com/gitui-org/gitui/releases/download/v${version}/gitui-linux-${arch}.tar.gz",
            ["latest"] = { ref = "0.28.1" },
            ["0.28.1"] = {
                sha256 = {
                    x86_64 = "f6149b9ae203397158b0c89c13cfde718e7121d3d3cd2ebc597f93d6628d9b5b",
                    aarch64 = "2a640da05b73e9152a7bf92bfd7c23acd9d60438f4f2cabb62357014a5fd7c28",
                },
            },
        },
        macosx = {
            source = "https://github.com/gitui-org/gitui/releases/download/v${version}/gitui-${arch_alias}.tar.gz",
            ["latest"] = { ref = "0.28.1" },
            ["0.28.1"] = {
                arch_alias = { x86_64 = "mac-x86", aarch64 = "mac" },
                sha256 = {
                    x86_64 = "27e2f558ca7ebbc7b5fc4c1f61285355d2ea4735610e906579e5b3c8736e7685",
                    aarch64 = "3b519a593383841289361bacf579d4a222169aa7ebbdeae6cc449d488d8bb967",
                },
            },
        },
        windows = {
            deps = {
                runtime = { "xim:vcruntime" },
            },
            source = "https://github.com/gitui-org/gitui/releases/download/v${version}/gitui-${arch_alias}.tar.gz",
            ["latest"] = { ref = "0.28.1" },
            ["0.28.1"] = {
                arch_alias = { x86_64 = "win" },
                sha256 = {
                    x86_64 = "fab116ccdf9ae4e17378db912d76cc26e60aefd2226f44e665120dea166867e4",
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
import("xim.pkgindex.winpath")

local function _is_windows(dir, normalized)
    return os.getenv("OS") == "Windows_NT"
        or dir:match("^[A-Za-z]:") ~= nil
        or dir:find("\\", 1, true) ~= nil
        or normalized:match("win%.tar%.gz$") ~= nil
end

function installed()
    return payload.present({ "gitui" })
        or payload.present({ "gitui.exe" })
end

function install()
    local archive = tostring(pkginfo.install_file() or "")
    if archive == "" then
        error("gitui: install_file is empty")
    end

    local dir = pkginfo.install_dir()
    local normalized = archive:gsub("\\", "/")
    local download_dir = normalized:match("^(.*)/[^/]+$") or "."
    local is_win = _is_windows(dir, normalized)
    local exe = is_win and "gitui.exe" or "gitui"
    local pre_extracted = download_dir .. "/" .. exe

    os.tryrm(dir)
    fs.mkdir_p(dir)

    if os.isfile(archive) then
        -- Extract flat .tar.gz directly into install_dir so files never mix
        -- with other flat archives in the shared runtimedir.
        if is_win then
            local sysroot = winpath.native(os.getenv("SystemRoot") or "C:\\Windows"):gsub("\\+$", "")
            local systar = sysroot .. "\\System32\\tar.exe"
            -- exec-quoting-ok: the first token is the system's tar.exe, which cmd.exe must see unquoted
            system.exec(string.format('%s -xzf "%s" -C "%s"', systar, winpath.native(archive), winpath.native(dir)))
        else
            system.exec(string.format([[tar -xzf "%s" -C "%s"]], normalized, dir))
        end
    elseif os.isfile(pre_extracted) then
        os.mv(pre_extracted, dir .. "/" .. exe)
    else
        error("gitui: neither archive (" .. archive .. ") nor extracted binary (" .. pre_extracted .. ") exists")
    end

    if is_win then
        if not pkginfo.dep_install_dir then
            error("gitui: xim:vcruntime runtime dep lookup is unavailable")
        end
        local crt = assert(pkginfo.dep_install_dir("xim:vcruntime"),
                           "gitui: xim:vcruntime payload directory is missing")
        local copied = 0
        for _, dll in ipairs(fs.files(crt .. "/bin") or {}) do
            os.cp(dll, dir)
            copied = copied + 1
        end
        if copied == 0 then
            error("gitui: no CRT DLLs found in " .. crt .. "/bin")
        end
    elseif os.isfile(dir .. "/" .. exe) then
        system.exec(string.format([[chmod +x "%s"]], dir .. "/" .. exe))
    end

    payload.require({ exe })
    return true
end

function config()
    xvm.add("gitui", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("gitui")
    return true
end

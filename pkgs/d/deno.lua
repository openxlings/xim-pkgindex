-- Deno: a modern runtime for JavaScript and TypeScript.
--
-- Upstream publishes single-binary `.zip` archives on every platform
-- (`deno` on Linux/macOS, `deno.exe` on Windows, with no enclosing directory).
--
-- Linux ELF inspection (v2.9.8, readelf -d):
--   x86_64:  INTERP /lib64/ld-linux-x86-64.so.2
--            NEEDED libdl.so.2, libgcc_s.so.1, librt.so.1, libpthread.so.0,
--                   libm.so.6, libc.so.6, ld-linux-x86-64.so.2
--   aarch64: INTERP /lib/ld-linux-aarch64.so.1
--            NEEDED libdl.so.2, libgcc_s.so.1, libpthread.so.0, libm.so.6,
--                   libc.so.6, ld-linux-aarch64.so.1
-- So Linux declares runtime deps on `xim:glibc` and `xim:gcc-runtime` (for
-- `libgcc_s.so.1`, same pattern as `nvim.lua`) so xlings elfpatch can rewrite
-- INTERP and RPATH into the subos closure.
--
-- Windows PE inspection (v2.9.8 x86_64 & aarch64):
--   Statically links the MSVC CRT; imports only Windows OS system DLLs
--   (kernel32, ntdll, advapi32, ws2_32, user32, shell32, userenv, crypt32,
--   bcrypt, bcryptprimitives, api-ms-win-core-synch-l1-2-0), so no
--   `xim:vcruntime` runtime dep is required.
--
-- All SHA256 digests below were verified against upstream `.zip.sha256sum`
-- files and by downloading and hashing each v2.9.8 release archive.

package = {
    spec = "2",

    name = "deno",
    description = "A modern runtime for JavaScript and TypeScript",
    homepage = "https://deno.com",
    authors = {"Deno Land Inc."},
    maintainers = {"https://github.com/denoland/deno/graphs/contributors"},
    licenses = {"MIT"},
    repo = "https://github.com/denoland/deno",
    docs = "https://docs.deno.com",
    ci = { mirror = true },

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"javascript", "typescript", "runtime", "tools"},
    keywords = {"deno", "javascript", "typescript", "v8", "runtime"},

    programs = {"deno"},
    xvm_enable = true,

    extensions = {
        autoupdate = {
            source = "https://github.com/denoland/deno/releases",
            resources = {
                GLOBAL = {
                    url = {
                        linux = {
                            x86_64 = "https://github.com/denoland/deno/releases/download/v${version}/deno-x86_64-unknown-linux-gnu.zip",
                            aarch64 = "https://github.com/denoland/deno/releases/download/v${version}/deno-aarch64-unknown-linux-gnu.zip",
                        },
                        macosx = {
                            x86_64 = "https://github.com/denoland/deno/releases/download/v${version}/deno-x86_64-apple-darwin.zip",
                            aarch64 = "https://github.com/denoland/deno/releases/download/v${version}/deno-aarch64-apple-darwin.zip",
                        },
                        windows = {
                            x86_64 = "https://github.com/denoland/deno/releases/download/v${version}/deno-x86_64-pc-windows-msvc.zip",
                            aarch64 = "https://github.com/denoland/deno/releases/download/v${version}/deno-aarch64-pc-windows-msvc.zip",
                        },
                    },
                    required = true,
                },
            },
        },
    },

    xpm = {
        linux = {
            deps = {
                runtime = { "xim:glibc@>=2.39", "xim:gcc-runtime@15.1.0" },
            },
            ["latest"] = { ref = "2.9.8" },
            ["2.9.8"] = {
                x86_64 = {
                    url = "https://github.com/denoland/deno/releases/download/v2.9.8/deno-x86_64-unknown-linux-gnu.zip",
                    sha256 = "e890975bc2549807bbcc0b584ffafda72cc7c93349dd99c80483dd784f6c4609",
                },
                aarch64 = {
                    url = "https://github.com/denoland/deno/releases/download/v2.9.8/deno-aarch64-unknown-linux-gnu.zip",
                    sha256 = "d49596c20b9788cf8f5d8ddf644103d4bde56ed239753f0bdb92ba9361d51905",
                },
            },
        },
        macosx = {
            ["latest"] = { ref = "2.9.8" },
            ["2.9.8"] = {
                x86_64 = {
                    url = "https://github.com/denoland/deno/releases/download/v2.9.8/deno-x86_64-apple-darwin.zip",
                    sha256 = "4b2f5edd2639b7470f034238b321d7002d8dfb4726d8558f52c17afac370eb2c",
                },
                aarch64 = {
                    url = "https://github.com/denoland/deno/releases/download/v2.9.8/deno-aarch64-apple-darwin.zip",
                    sha256 = "9f0bf660393da2eaff044cdc7444cb08c73f235849b61d224d825a194ce7c98e",
                },
            },
        },
        windows = {
            ["latest"] = { ref = "2.9.8" },
            ["2.9.8"] = {
                x86_64 = {
                    url = "https://github.com/denoland/deno/releases/download/v2.9.8/deno-x86_64-pc-windows-msvc.zip",
                    sha256 = "cba84b26e0df5ae7f74fc66b86a95b866872a86292ebd84fa1e959927edd93bf",
                },
                aarch64 = {
                    url = "https://github.com/denoland/deno/releases/download/v2.9.8/deno-aarch64-pc-windows-msvc.zip",
                    sha256 = "b413b92b735b50c198e8fe3b85af1aa50e29d5f72e229aab701d132286e14cef",
                },
            },
        },
    },
}

import("xim.libxpkg.fs")
import("xim.libxpkg.log")
import("xim.libxpkg.pkginfo")
import("xim.libxpkg.system")
import("xim.libxpkg.xvm")
import("xim.pkgindex.winpath")

local function exe_name()
    return os.host() == "windows" and "deno.exe" or "deno"
end

local function exe_path()
    return path.join(pkginfo.install_dir(), exe_name())
end

local function native_win_path(p)
    if type(winpath) == "table" and type(winpath.native) == "function" then
        return winpath.native(p)
    end
    return (tostring(p):gsub("/", "\\"))
end

function installed()
    return os.isfile(exe_path())
end

function install()
    local dir = pkginfo.install_dir()
    local name = exe_name()
    local dst = path.join(dir, name)

    -- Some xim engines extract directly into install_dir() before the hook runs.
    if not os.isfile(dst) then
        local archive = tostring(pkginfo.install_file() or "")
        local normalized = archive:gsub("\\", "/")
        local download_dir = normalized:match("^(.*)/[^/]+$") or "."
        local stem = normalized:match("([^/]+)%.zip$")

        local candidates = {
            path.join(download_dir, name),
            name,
        }
        if stem and stem ~= "" then
            table.insert(candidates, path.join(download_dir, stem, name))
            table.insert(candidates, path.join(stem, name))
        end

        local src = nil
        for _, cand in ipairs(candidates) do
            if os.isfile(cand) then
                src = cand
                break
            end
        end

        os.tryrm(dir)
        if type(fs) == "table" and type(fs.mkdir_p) == "function" then
            fs.mkdir_p(dir)
        else
            os.mkdir(dir)
        end

        if src then
            os.mv(src, dst)
        elseif os.host() == "windows" and normalized:match("%.zip$") and os.isfile(archive) then
            local sysroot = native_win_path(os.getenv("SystemRoot") or "C:\\Windows"):gsub("\\+$", "")
            local systar = sysroot .. "\\System32\\tar.exe"
            -- exec-quoting-ok: the first token is the system's tar.exe, which cmd.exe must see unquoted
            system.exec(string.format('%s -xf "%s" -C "%s"',
                                      systar, native_win_path(archive), native_win_path(dir)))
        elseif normalized:match("%.zip$") and os.isfile(archive) then
            system.exec(string.format('unzip -q -o "%s" -d "%s"', archive, dir))
        else
            error("deno: extracted binary not found (checked " .. table.concat(candidates, ", ") .. ")")
        end
    end

    if os.host() ~= "windows" and os.isfile(dst) then
        system.exec(string.format('chmod +x "%s"', dst))
    end

    if not os.isfile(dst) then
        error("deno: expected binary missing after install at " .. dst)
    end
    log.info("deno: installed %s", dst)
    return true
end

function config()
    xvm.add("deno", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("deno")
    return true
end

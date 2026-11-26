-- Evans - More expressive universal gRPC client (CLI and REPL).
--
-- Verified 2026-11-26 against upstream GitHub release v0.10.11 (ktr0731/evans):
--   linux    x86_64, aarch64   evans_linux_{amd64,arm64}.tar.gz
--   macosx   x86_64, aarch64   evans_darwin_{amd64,arm64}.tar.gz
--   windows  x86_64, aarch64   evans_windows_{amd64,arm64}.tar.gz
--
-- Every archive is flat at root containing only the single executable
-- (`evans` on Linux/macOS, `evans.exe` on Windows).
-- All six SHA-256 digests match upstream `checksums.txt` and downloaded archives.
-- Both Linux ELF binaries are statically linked Go executables (`readelf -d`:
-- no dynamic section; `ldd`: not a dynamic executable), so no runtime library
-- deps are required. Both Windows PE32+ binaries (`x86_64`, `aarch64`) import
-- only `kernel32.dll`.
package = {
    spec = "2",

    name = "evans",
    description = "More expressive universal gRPC client",
    homepage = "https://github.com/ktr0731/evans",
    authors = {"ktr0731"},
    maintainers = {"ktr0731"},
    licenses = {"MIT"},
    repo = "https://github.com/ktr0731/evans",
    docs = "https://github.com/ktr0731/evans#readme",

    ci = { mirror = true },

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"grpc", "network", "cli", "tools"},
    keywords = {"evans", "grpc", "protobuf", "cli", "repl", "rpc"},

    programs = {"evans"},
    xvm_enable = true,

    -- Verified upstream release assets; no CN mirror has been verified.
    extensions = {
        autoupdate = {
            source = "https://github.com/ktr0731/evans/releases",
            resources = {
                GLOBAL = {
                    required = true,
                    url = {
                        linux = {
                            x86_64 = "https://github.com/ktr0731/evans/releases/download/${tag}/evans_linux_amd64.tar.gz",
                            aarch64 = "https://github.com/ktr0731/evans/releases/download/${tag}/evans_linux_arm64.tar.gz",
                        },
                        macosx = {
                            x86_64 = "https://github.com/ktr0731/evans/releases/download/${tag}/evans_darwin_amd64.tar.gz",
                            aarch64 = "https://github.com/ktr0731/evans/releases/download/${tag}/evans_darwin_arm64.tar.gz",
                        },
                        windows = {
                            x86_64 = "https://github.com/ktr0731/evans/releases/download/${tag}/evans_windows_amd64.tar.gz",
                            aarch64 = "https://github.com/ktr0731/evans/releases/download/${tag}/evans_windows_arm64.tar.gz",
                        },
                    },
                },
            },
        },
    },

    xpm = {
        linux = {
            source = "https://github.com/ktr0731/evans/releases/download/v${version}/evans_linux_${arch_alias}.tar.gz",
            ["latest"] = { ref = "0.10.11" },
            ["0.10.11"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "0535a4161c6d5b9ff5dbe144e6b9e1c95f41b3078c993d1f04fcf0b699e997e6",
                    aarch64 = "fb90b5eefd300dc63ca768930db074b24df61d8b878c2c5997d6c912c0953cbd",
                },
            },
        },
        macosx = {
            source = "https://github.com/ktr0731/evans/releases/download/v${version}/evans_darwin_${arch_alias}.tar.gz",
            ["latest"] = { ref = "0.10.11" },
            ["0.10.11"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "4f687cf3497cabc6f68d40cf8e4f9819cda109aa3c3d8ca992ce4f3c082f0f54",
                    aarch64 = "c3d29409b1b4dbc86960a737f24f6acdc12bf175ea428dba24d59e1a10e5bcf9",
                },
            },
        },
        windows = {
            source = "https://github.com/ktr0731/evans/releases/download/v${version}/evans_windows_${arch_alias}.tar.gz",
            ["latest"] = { ref = "0.10.11" },
            ["0.10.11"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "064f455ec597d359e4c00448770f5eb237e4ab029e230cc4cd64d63751447e97",
                    aarch64 = "8fab21d03b060ebd4c27ffb06a7a2dcbc600adb5db3b1656d42a18cf29ced420",
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

function installed()
    return payload.present({ "evans" })
        or payload.present({ "evans.exe" })
end

function install()
    local archive = tostring(pkginfo.install_file())
    local dir = pkginfo.install_dir()
    local normalized = archive:gsub("\\", "/")
    local parent = normalized:match("^(.*)/[^/]+$") or "."
    local is_win = normalized:match("_windows_") ~= nil
        or normalized:match("windows") ~= nil
        or normalized:match("^[A-Za-z]:/") ~= nil
        or os.getenv("OS") == "Windows_NT"
    local exe = is_win and "evans.exe" or "evans"

    os.tryrm(dir)
    fs.mkdir_p(dir)

    if os.isfile(archive) then
        if is_win then
            local sysroot = winpath.native(os.getenv("SystemRoot") or "C:\\Windows"):gsub("\\+$", "")
            local systar = sysroot .. "\\System32\\tar.exe"
            -- exec-quoting-ok: the first token is the system's tar.exe, which cmd.exe must see unquoted
            system.exec(string.format('%s -xf "%s" -C "%s"',
                                      systar, winpath.native(archive), winpath.native(dir)))
        else
            -- Extract flat .tar.gz directly into install_dir so files never mix
            -- with other flat archives in the shared runtimedir.
            system.exec(string.format('tar -xf "%s" -C "%s"', archive, dir))
            system.exec(string.format('chmod +x "%s"', dir .. "/evans"))
        end
    elseif os.isfile(parent .. "/" .. exe) then
        os.mv(parent .. "/" .. exe, dir .. "/" .. exe)
        if not is_win then
            system.exec(string.format('chmod +x "%s"', dir .. "/evans"))
        end
    else
        error("evans: archive not found at " .. archive)
    end

    payload.require({ exe })
    return true
end

function config()
    xvm.add("evans", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("evans")
    return true
end

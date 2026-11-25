-- Gleam - a friendly language for building type-safe, scalable systems.
--
-- Platform and architecture coverage (verified against gleam-lang/gleam v1.19.2):
--   linux    x86_64   static-pie musl ELF binary (`gleam` at archive root, zero DT_NEEDED)
--   linux    aarch64  statically linked musl ELF binary (`gleam` at archive root, no .dynamic)
--   macosx   x86_64   official Mach-O binary (`gleam` at archive root)
--   macosx   aarch64  official Mach-O binary (`gleam` at archive root)
--   windows  x86_64   PE32+ binary (`gleam.exe` at archive root; static MSVC CRT, no VCRUNTIME140.dll)
--   windows  aarch64  PE32+ binary (`gleam.exe` at archive root; static MSVC CRT, no VCRUNTIME140.dll)
--
-- All archives are flat (only `gleam` or `gleam.exe` at root, no enclosing folder).
-- All SHA-256 digests match upstream `.sha256` files and locally downloaded archives.

package = {
    spec = "2",

    name = "gleam",
    description = "A friendly language for building type-safe, scalable systems",
    homepage = "https://gleam.run",
    authors = {"Louis Pilfold"},
    maintainers = {"gleam-lang"},
    licenses = {"Apache-2.0"},
    repo = "https://github.com/gleam-lang/gleam",
    docs = "https://gleam.run/documentation/",

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"language", "compiler", "beam", "tools"},
    keywords = {"gleam", "erlang", "beam", "javascript", "compiler", "functional"},

    programs = {"gleam"},
    xvm_enable = true,
    ci = { mirror = true },

    extensions = {
        autoupdate = {
            source = "https://github.com/gleam-lang/gleam/releases",
            resources = {
                GLOBAL = {
                    url = {
                        linux = {
                            x86_64 = "https://github.com/gleam-lang/gleam/releases/download/${tag}/gleam-v${version}-x86_64-unknown-linux-musl.tar.gz",
                            aarch64 = "https://github.com/gleam-lang/gleam/releases/download/${tag}/gleam-v${version}-aarch64-unknown-linux-musl.tar.gz",
                        },
                        macosx = {
                            x86_64 = "https://github.com/gleam-lang/gleam/releases/download/${tag}/gleam-v${version}-x86_64-apple-darwin.tar.gz",
                            aarch64 = "https://github.com/gleam-lang/gleam/releases/download/${tag}/gleam-v${version}-aarch64-apple-darwin.tar.gz",
                        },
                        windows = {
                            x86_64 = "https://github.com/gleam-lang/gleam/releases/download/${tag}/gleam-v${version}-x86_64-pc-windows-msvc.zip",
                            aarch64 = "https://github.com/gleam-lang/gleam/releases/download/${tag}/gleam-v${version}-aarch64-pc-windows-msvc.zip",
                        },
                    },
                    required = true,
                },
            },
        },
    },

    xpm = {
        linux = {
            ["latest"] = { ref = "1.19.2" },
            ["1.19.2"] = {
                x86_64 = {
                    url = "https://github.com/gleam-lang/gleam/releases/download/v1.19.2/gleam-v1.19.2-x86_64-unknown-linux-musl.tar.gz",
                    sha256 = "2ba2afb66ca9f6dcc01a4a6e9169b6942963bad6483bec9571ddc078cfe6f41f",
                },
                aarch64 = {
                    url = "https://github.com/gleam-lang/gleam/releases/download/v1.19.2/gleam-v1.19.2-aarch64-unknown-linux-musl.tar.gz",
                    sha256 = "d1d1a9d53f6b317c0563a4806873c8ccace54291ead023373728af379402d4f1",
                },
            },
        },
        macosx = {
            ["latest"] = { ref = "1.19.2" },
            ["1.19.2"] = {
                x86_64 = {
                    url = "https://github.com/gleam-lang/gleam/releases/download/v1.19.2/gleam-v1.19.2-x86_64-apple-darwin.tar.gz",
                    sha256 = "c578192530507b868c4a6c8cb7ad5d2ab0830890257f41036f17c82853f19d05",
                },
                aarch64 = {
                    url = "https://github.com/gleam-lang/gleam/releases/download/v1.19.2/gleam-v1.19.2-aarch64-apple-darwin.tar.gz",
                    sha256 = "fa7c6113e162ab1d979f72e7dde3e907b87e4b30c518af178768e577d180324d",
                },
            },
        },
        windows = {
            ["latest"] = { ref = "1.19.2" },
            ["1.19.2"] = {
                x86_64 = {
                    url = "https://github.com/gleam-lang/gleam/releases/download/v1.19.2/gleam-v1.19.2-x86_64-pc-windows-msvc.zip",
                    sha256 = "21744a7fb040f64142c1b45b7a0149bf2c46b4aa46b435abd35848f9821ce729",
                },
                aarch64 = {
                    url = "https://github.com/gleam-lang/gleam/releases/download/v1.19.2/gleam-v1.19.2-aarch64-pc-windows-msvc.zip",
                    sha256 = "f9bb658ab191bb0f85e21045dcef36c2900ce83be50aef84dcf2a88c88cd5e32",
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
    return os.isfile(dir .. "/gleam.exe") or os.isfile(dir .. "/gleam")
end

function install()
    local archive = tostring(pkginfo.install_file() or "")
    if archive == "" then
        error("gleam: install_file is empty")
    end

    local dir = pkginfo.install_dir()
    local normalized = archive:gsub("\\", "/")
    local download_dir = normalized:match("^(.*)/[^/]+$") or "."
    local is_win = normalized:match("%.zip$") ~= nil
    local exe = is_win and "gleam.exe" or "gleam"
    local pre_extracted = download_dir .. "/" .. exe

    os.tryrm(dir)
    fs.mkdir_p(dir)

    if os.isfile(archive) then
        if is_win then
            local sysroot = winpath.native(os.getenv("SystemRoot") or "C:\\Windows"):gsub("\\+$", "")
            local systar = sysroot .. "\\System32\\tar.exe"
            -- exec-quoting-ok: the first token is the system's tar.exe, which cmd.exe must see unquoted
            system.exec(string.format('%s -xf "%s" -C "%s"', systar, winpath.native(archive), winpath.native(dir)))
        else
            system.exec(string.format([[tar -xzf "%s" -C "%s"]], normalized, dir))
        end
    elseif os.isfile(pre_extracted) then
        os.mv(pre_extracted, dir .. "/" .. exe)
    else
        error("gleam: neither archive (" .. archive .. ") nor extracted binary (" .. pre_extracted .. ") exists")
    end

    if not is_win and os.isfile(dir .. "/" .. exe) then
        system.exec(string.format([[chmod +x "%s"]], dir .. "/" .. exe))
    end

    if not installed() then
        error("gleam: " .. exe .. " is missing after install in " .. dir)
    end
    return true
end

function config()
    xvm.add("gleam", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("gleam")
    return true
end

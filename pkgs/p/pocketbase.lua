-- PocketBase - Open Source realtime backend in 1 file.
--
-- Platform and architecture coverage (verified against v0.40.6 release):
--   linux    x86_64, aarch64   pocketbase_<ver>_linux_<arch>.zip   (static Go ELF, no .dynamic section)
--   macosx   x86_64, aarch64   pocketbase_<ver>_darwin_<arch>.zip
--   windows  x86_64, aarch64   pocketbase_<ver>_windows_<arch>.zip (imports kernel32.dll only)
--
-- All archives are flat `.zip` files (`pocketbase` / `pocketbase.exe`,
-- `LICENSE.md`, `CHANGELOG.md` at archive root). Linux binaries are statically
-- linked Go executables using pure-Go SQLite (no dynamic section, no runtime
-- deps); Windows executables import only `kernel32.dll` (no CRT runtime dep).
-- Every SHA256 below was verified against upstream `checksums.txt` and by
-- hashing downloaded archives.

package = {
    spec = "2",

    name = "pocketbase",
    description = "Open Source realtime backend in 1 file",
    homepage = "https://pocketbase.io",
    authors = {"Gani Georgiev"},
    maintainers = {"https://github.com/pocketbase/pocketbase/graphs/contributors"},
    licenses = {"MIT"},
    repo = "https://github.com/pocketbase/pocketbase",
    docs = "https://pocketbase.io/docs/",

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"backend", "database", "sqlite", "web", "tools"},
    keywords = {"pocketbase", "backend", "sqlite", "realtime", "auth", "api"},

    programs = {"pocketbase"},
    xvm_enable = true,
    ci = { mirror = true },

    extensions = {
        autoupdate = {
            source = "https://github.com/pocketbase/pocketbase/releases",
            resources = {
                GLOBAL = {
                    url = {
                        linux = {
                            x86_64 = "https://github.com/pocketbase/pocketbase/releases/download/${tag}/pocketbase_${version}_linux_amd64.zip",
                            aarch64 = "https://github.com/pocketbase/pocketbase/releases/download/${tag}/pocketbase_${version}_linux_arm64.zip",
                        },
                        macosx = {
                            x86_64 = "https://github.com/pocketbase/pocketbase/releases/download/${tag}/pocketbase_${version}_darwin_amd64.zip",
                            aarch64 = "https://github.com/pocketbase/pocketbase/releases/download/${tag}/pocketbase_${version}_darwin_arm64.zip",
                        },
                        windows = {
                            x86_64 = "https://github.com/pocketbase/pocketbase/releases/download/${tag}/pocketbase_${version}_windows_amd64.zip",
                            aarch64 = "https://github.com/pocketbase/pocketbase/releases/download/${tag}/pocketbase_${version}_windows_arm64.zip",
                        },
                    },
                    required = true,
                },
            },
        },
    },

    xpm = {
        linux = {
            source = "https://github.com/pocketbase/pocketbase/releases/download/v${version}/pocketbase_${version}_linux_${arch_alias}.zip",
            ["latest"] = { ref = "0.40.6" },
            ["0.40.6"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "0e1f609158ed945f809f8a02ae012aa0427129c66ebb63c1aee76f2c0309373f",
                    aarch64 = "d22c66ceb67ca92b7d767f36d826e848a276bcfa3c197ead20bf87c42208984f",
                },
            },
        },
        macosx = {
            source = "https://github.com/pocketbase/pocketbase/releases/download/v${version}/pocketbase_${version}_darwin_${arch_alias}.zip",
            ["latest"] = { ref = "0.40.6" },
            ["0.40.6"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "970464cfdb8faf0ad57e0b6b806fd85e81f99cb78000a1c9f78cdcb1b36d4b7a",
                    aarch64 = "7f2f7544e9ee5994ab69f84b22a4ab9a3bcfed58c1dad7206d05ebeb753f968b",
                },
            },
        },
        windows = {
            source = "https://github.com/pocketbase/pocketbase/releases/download/v${version}/pocketbase_${version}_windows_${arch_alias}.zip",
            ["latest"] = { ref = "0.40.6" },
            ["0.40.6"] = {
                arch_alias = { x86_64 = "amd64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "33a2a1d255cadded77346fc7f5de37dca21ba4bad0d9cae0235a50b3b703d6d9",
                    aarch64 = "7ca50a72b768965f0da194b907d2a1e8865e614cdbebb27fa64ca7ff1d7f5182",
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

function installed()
    return payload.present({ "pocketbase" }) or payload.present({ "pocketbase.exe" })
end

function install()
    local archive = tostring(pkginfo.install_file() or "")
    if archive == "" then
        error("pocketbase: install_file is empty")
    end

    local dir = pkginfo.install_dir()
    local normalized = archive:gsub("\\", "/")
    local parent = normalized:match("^(.*)/[^/]+$") or "."
    -- All platforms ship `.zip` archives; detect Windows by path, never by `.zip`.
    local is_win = normalized:match("windows") ~= nil
    local exe = is_win and "pocketbase.exe" or "pocketbase"

    os.tryrm(dir)
    fs.mkdir_p(dir)

    if is_win then
        if type(payload.unpack) == "function" then
            payload.unpack{}
        elseif os.isfile(parent .. "/" .. exe) then
            for _, f in ipairs({ exe, "LICENSE.md", "CHANGELOG.md" }) do
                if os.isfile(parent .. "/" .. f) then
                    os.mv(parent .. "/" .. f, dir .. "/" .. f)
                end
            end
        else
            local sysroot = (os.getenv("SystemRoot") or "C:\\Windows"):gsub("/", "\\"):gsub("\\+$", "")
            local systar = sysroot .. "\\System32\\tar.exe"
            -- exec-quoting-ok: the first token is the system's tar.exe, which cmd.exe must see unquoted
            system.exec(string.format('%s -xf "%s" -C "%s"', systar, archive:gsub("/", "\\"), dir:gsub("/", "\\")))
        end
    else
        if os.isfile(parent .. "/" .. exe) then
            for _, f in ipairs({ exe, "LICENSE.md", "CHANGELOG.md" }) do
                if os.isfile(parent .. "/" .. f) then
                    os.mv(parent .. "/" .. f, dir .. "/" .. f)
                end
            end
        elseif os.isfile(archive) then
            system.exec(string.format('unzip -q -o "%s" -d "%s"', archive, dir))
        else
            error("pocketbase: extracted binary (" .. exe .. ") not found in " .. parent)
        end
        if os.isfile(dir .. "/pocketbase") then
            system.exec(string.format('chmod +x "%s"', dir .. "/pocketbase"))
        end
    end

    payload.require({ exe })
    return true
end

function config()
    xvm.add("pocketbase", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("pocketbase")
    return true
end

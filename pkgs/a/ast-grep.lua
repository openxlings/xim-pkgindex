-- ast-grep: a fast and polyglot tool for code structural search, lint, and rewriting.
--
-- Official prebuilt archives verified against ast-grep/ast-grep release 0.51.3:
--   * Every archive is a flat .zip (no enclosing directory) shipping both
--     `ast-grep` and `sg` (`ast-grep.exe` and `sg.exe` on Windows); `sg` is a
--     deprecated alias that invokes `ast-grep` from PATH.
--   * linux/x86_64 (`unknown-linux-gnu`):
--       ast-grep: INTERP /lib64/ld-linux-x86-64.so.2
--                 NEEDED libgcc_s.so.1, libm.so.6, libc.so.6
--       sg:       NEEDED libgcc_s.so.1, libc.so.6
--   * linux/aarch64 (`unknown-linux-gnu`):
--       ast-grep: INTERP /lib/ld-linux-aarch64.so.1
--                 NEEDED libdl.so.2, libgcc_s.so.1, libpthread.so.0,
--                        libm.so.6, libc.so.6, ld-linux-aarch64.so.1
--       sg:       NEEDED libgcc_s.so.1, libpthread.so.0, libc.so.6
--     (Upstream `-unknown-linux-musl` builds dynamically link musl libc.so and
--     libgcc_s.so.1; `-unknown-linux-gnu` is used here so xlings elfpatch
--     closes cleanly against xim:glibc and xim:gcc-runtime.)
--   * macosx: x86_64 and aarch64 (`apple-darwin`).
--   * windows: x86_64 (`pc-windows-msvc`); PE imports for both `ast-grep.exe`
--     and `sg.exe` include VCRUNTIME140.dll, so `xim:vcruntime` DLLs are copied
--     app-local beside the executables. Windows ARM64 waits for `xim:vcruntime`
--     ARM64 CRT DLL support.

package = {
    spec = "2",

    name = "ast-grep",
    description = "A fast and polyglot tool for code structural search, lint, and rewriting",
    homepage = "https://ast-grep.github.io",
    authors = {"Herrington Darkholme"},
    maintainers = {"https://github.com/ast-grep/ast-grep/graphs/contributors"},
    licenses = {"MIT"},
    repo = "https://github.com/ast-grep/ast-grep",
    docs = "https://ast-grep.github.io/guide/introduction.html",
    ci = { mirror = true },

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"cli", "search", "lint", "tools"},
    keywords = {"ast-grep", "sg", "ast", "search", "lint", "refactor", "rust"},

    programs = {"ast-grep", "sg"},
    xvm_enable = true,

    extensions = {
        autoupdate = {
            source = "https://github.com/ast-grep/ast-grep/releases",
            resources = {
                GLOBAL = {
                    url = {
                        linux = {
                            x86_64 = "https://github.com/ast-grep/ast-grep/releases/download/${tag}/app-x86_64-unknown-linux-gnu.zip",
                            aarch64 = "https://github.com/ast-grep/ast-grep/releases/download/${tag}/app-aarch64-unknown-linux-gnu.zip",
                        },
                        macosx = {
                            x86_64 = "https://github.com/ast-grep/ast-grep/releases/download/${tag}/app-x86_64-apple-darwin.zip",
                            aarch64 = "https://github.com/ast-grep/ast-grep/releases/download/${tag}/app-aarch64-apple-darwin.zip",
                        },
                        windows = {
                            x86_64 = "https://github.com/ast-grep/ast-grep/releases/download/${tag}/app-x86_64-pc-windows-msvc.zip",
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
            ["latest"] = { ref = "0.51.3" },
            ["0.51.3"] = {
                x86_64 = {
                    url = "https://github.com/ast-grep/ast-grep/releases/download/0.51.3/app-x86_64-unknown-linux-gnu.zip",
                    sha256 = "22803eb0c5bf83164fb7fd76d4721d355ecf0c8466ef47342c1ec7d80897ca47",
                },
                aarch64 = {
                    url = "https://github.com/ast-grep/ast-grep/releases/download/0.51.3/app-aarch64-unknown-linux-gnu.zip",
                    sha256 = "5b44fd68e78744934b359b07badce347d4197ed50b341d50f1f99d056ecedb08",
                },
            },
        },
        macosx = {
            ["latest"] = { ref = "0.51.3" },
            ["0.51.3"] = {
                x86_64 = {
                    url = "https://github.com/ast-grep/ast-grep/releases/download/0.51.3/app-x86_64-apple-darwin.zip",
                    sha256 = "af04ed50179e51316a0139b8bb39502a3841d6c8e9fd9a4bac40987a8c7c3acd",
                },
                aarch64 = {
                    url = "https://github.com/ast-grep/ast-grep/releases/download/0.51.3/app-aarch64-apple-darwin.zip",
                    sha256 = "7954eab1e2803d1485f263377be7f359db6d3915312b5d773cd575eb009330b1",
                },
            },
        },
        windows = {
            deps = {
                runtime = { "xim:vcruntime" },
            },
            ["latest"] = { ref = "0.51.3" },
            ["0.51.3"] = {
                x86_64 = {
                    url = "https://github.com/ast-grep/ast-grep/releases/download/0.51.3/app-x86_64-pc-windows-msvc.zip",
                    sha256 = "1f27ff60ee033bdfe5d7ea781a869e410b2d882d6c84a6afea8280fc4bbf0716",
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
import("xim.pkgindex.payload")

local function binaries_for(is_win)
    if is_win then
        return { "ast-grep.exe", "sg.exe" }
    end
    return { "ast-grep", "sg" }
end

local function find_extracted_bin(parent, stem, name)
    local candidates = {
        parent .. "/" .. name,
        name,
    }
    if stem and stem ~= "" then
        table.insert(candidates, parent .. "/" .. stem .. "/" .. name)
        table.insert(candidates, stem .. "/" .. name)
    end
    for _, cand in ipairs(candidates) do
        if os.isfile(cand) then
            return cand
        end
    end
    return nil
end

function installed()
    return payload.present({ "ast-grep", "sg" })
        or payload.present({ "ast-grep.exe", "sg.exe" })
end

function install()
    local archive = tostring(pkginfo.install_file() or "")
    local dir = pkginfo.install_dir()
    local normalized = archive:gsub("\\", "/")
    local parent = normalized:match("^(.*)/[^/]+$") or "."
    local stem = normalized:match("([^/]+)%.zip$")
    local is_win = normalized:match("windows") ~= nil
    local bins = binaries_for(is_win)

    -- Some xim engines extract flat zip archives directly into install_dir().
    local already_in_dir = true
    for _, bin in ipairs(bins) do
        if not os.isfile(dir .. "/" .. bin) then
            already_in_dir = false
            break
        end
    end

    if not already_in_dir then
        os.tryrm(dir)
        fs.mkdir_p(dir)

        local moved_all = true
        for _, bin in ipairs(bins) do
            local src = find_extracted_bin(parent, stem, bin)
            if src then
                os.mv(src, dir .. "/" .. bin)
            else
                moved_all = false
            end
        end

        if not moved_all then
            if is_win and os.isfile(archive) then
                -- Let payload.unpack extract flat zip via %SystemRoot%\System32\tar.exe.
                payload.unpack{}
            elseif normalized:match("%.zip$") and os.isfile(archive) then
                system.exec(string.format('unzip -q -o "%s" -d "%s"', archive, dir))
            else
                error("ast-grep: failed to locate or extract binaries from " .. archive)
            end
        end
    end

    if is_win and pkginfo.dep_install_dir then
        local crt = assert(pkginfo.dep_install_dir("xim:vcruntime"),
                           "ast-grep: xim:vcruntime payload directory is missing")
        for _, dll in ipairs(fs.files(crt .. "/bin") or {}) do
            os.cp(dll, dir)
        end
    end

    if not is_win then
        system.exec(string.format('chmod +x "%s" "%s"', dir .. "/ast-grep", dir .. "/sg"))
    end

    payload.require(bins)
    log.info("ast-grep: installed binaries into %s", dir)
    return true
end

function config()
    local dir = pkginfo.install_dir()
    xvm.add("ast-grep", { bindir = dir })
    xvm.add("sg", { bindir = dir })
    return true
end

function uninstall()
    xvm.remove("sg")
    xvm.remove("ast-grep")
    return true
end

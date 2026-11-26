-- Difftastic - a structural diff tool that compares files based on their syntax (binary: `difft`).
--
-- Verified against upstream GitHub release Wilfred/difftastic 0.72.0:
--   Every SHA256 below was verified against the GitHub release asset digests
--   and computed locally from the downloaded archives. All archives are flat
--   (no enclosing directory) and contain a single `difft` (or `difft.exe`).
--   * linux/x86_64:  difft-0.72.0-x86_64-unknown-linux-musl.tar.gz
--                    static-pie ELF (no PT_INTERP, no DT_NEEDED; ldd: "statically linked")
--   * linux/aarch64: difft-0.72.0-aarch64-unknown-linux-gnu.tar.gz
--                    (upstream publishes no aarch64 musl archive)
--                    dynamically linked ELF, INTERP /lib/ld-linux-aarch64.so.1,
--                    NEEDED: libgcc_s.so.1, libpthread.so.0, libdl.so.2,
--                            libc.so.6, ld-linux-aarch64.so.1
--                    -> declares xim:glibc and xim:gcc-runtime on linux
--   * macosx:        x86_64-apple-darwin and aarch64-apple-darwin `.tar.gz`
--   * windows/x86_64: difft-0.72.0-x86_64-pc-windows-msvc.zip
--                    PE32+ x86_64 importing VCRUNTIME140.dll and UCRT API sets,
--                    so `xim:vcruntime` DLLs are copied app-local beside difft.exe.
--   * windows/aarch64: difft-0.72.0-aarch64-pc-windows-msvc.zip also imports
--                    VCRUNTIME140.dll and awaits `xim:vcruntime` ARM64 CRT support.
package = {
    spec = "2",

    name = "difftastic",
    description = "A structural diff tool that compares files based on their syntax",
    homepage = "https://difftastic.wilfred.me.uk/",
    authors = {"Wilfred Hughes"},
    maintainers = {"https://github.com/Wilfred/difftastic/graphs/contributors"},
    licenses = {"MIT"},
    repo = "https://github.com/Wilfred/difftastic",
    docs = "https://difftastic.wilfred.me.uk/introduction.html",

    ci = { mirror = true },

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"cli", "diff", "git", "tools"},
    keywords = {"difftastic", "difft", "diff", "syntax", "tree-sitter", "ast", "rust"},

    programs = {"difft"},
    xvm_enable = true,

    extensions = {
        autoupdate = {
            source = "https://github.com/Wilfred/difftastic/releases",
            resources = {
                GLOBAL = {
                    url = {
                        linux = {
                            x86_64 = "https://github.com/Wilfred/difftastic/releases/download/${tag}/difft-${version}-x86_64-unknown-linux-musl.tar.gz",
                            aarch64 = "https://github.com/Wilfred/difftastic/releases/download/${tag}/difft-${version}-aarch64-unknown-linux-gnu.tar.gz",
                        },
                        macosx = {
                            x86_64 = "https://github.com/Wilfred/difftastic/releases/download/${tag}/difft-${version}-x86_64-apple-darwin.tar.gz",
                            aarch64 = "https://github.com/Wilfred/difftastic/releases/download/${tag}/difft-${version}-aarch64-apple-darwin.tar.gz",
                        },
                        windows = {
                            x86_64 = "https://github.com/Wilfred/difftastic/releases/download/${tag}/difft-${version}-x86_64-pc-windows-msvc.zip",
                        },
                    },
                    required = true,
                },
            },
        },
    },

    xpm = {
        linux = {
            -- Upstream only ships a dynamically linked GNU binary for aarch64
            -- (no musl build). Declare runtime deps for its ELF closure.
            deps = {
                runtime = { "xim:glibc@>=2.39", "xim:gcc-runtime@15.1.0" },
            },
            source = "https://github.com/Wilfred/difftastic/releases/download/${version}/difft-${version}-${arch_alias}.tar.gz",
            ["latest"] = { ref = "0.72.0" },
            ["0.72.0"] = {
                arch_alias = {
                    x86_64 = "x86_64-unknown-linux-musl",
                    aarch64 = "aarch64-unknown-linux-gnu",
                },
                sha256 = {
                    x86_64 = "27b9c1fe038a95682eed241265a3cacb781227730f106104b617e10067d38ff4",
                    aarch64 = "0993a82a6708a24adc6c6b8de366924728ed08f537a5b488940082c8edc79353",
                },
            },
        },
        macosx = {
            source = "https://github.com/Wilfred/difftastic/releases/download/${version}/difft-${version}-${arch}-apple-darwin.tar.gz",
            ["latest"] = { ref = "0.72.0" },
            ["0.72.0"] = {
                sha256 = {
                    x86_64 = "31472d5cc1d40444beb697b58e6cf83febb3c7741df4007c3039952ffc1c36c6",
                    aarch64 = "959ce3e4b661663a6bb0b79de5e03051897e521e99c1b85f3c810b54f025ec93",
                },
            },
        },
        windows = {
            deps = {
                runtime = { "xim:vcruntime" },
            },
            source = "https://github.com/Wilfred/difftastic/releases/download/${version}/difft-${version}-${arch}-pc-windows-msvc.zip",
            -- Windows ARM64 imports VCRUNTIME140.dll and awaits `xim:vcruntime`
            -- ARM64 runtime DLL support.
            ["latest"] = { ref = "0.72.0" },
            ["0.72.0"] = {
                sha256 = {
                    x86_64 = "7b6295a9a433ba79978b02ad4b4b27f955423b8eb379927409b9ff4e5156379e",
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
    return payload.present({ "difft" })
        or payload.present({ "difft.exe" })
end

function install()
    local archive = tostring(pkginfo.install_file() or "")
    if archive == "" then
        error("difftastic: install_file is empty")
    end

    local dir = pkginfo.install_dir()
    local normalized = archive:gsub("\\", "/")
    local parent = normalized:match("^(.*)/[^/]+$") or "."
    local is_win = normalized:match("%.zip$") ~= nil
    local exe = is_win and "difft.exe" or "difft"

    os.tryrm(dir)

    -- Archives are flat (no top-level wrapper dir): extract straight from the
    -- archive into install_dir so files from unrelated flat archives in the
    -- shared runtime download directory are never pulled in.
    if is_win then
        payload.unpack{}
        if not pkginfo.dep_install_dir then
            error("difftastic: xim:vcruntime runtime dep lookup is unavailable")
        end
        local crt = assert(pkginfo.dep_install_dir("xim:vcruntime"),
                           "difftastic: xim:vcruntime payload directory is missing")
        local copied = 0
        for _, dll in ipairs(fs.files(crt .. "/bin") or {}) do
            os.cp(dll, dir)
            copied = copied + 1
        end
        if copied == 0 then
            error("difftastic: no CRT DLLs found in " .. crt .. "/bin")
        end
    elseif os.isfile(archive) then
        fs.mkdir_p(dir)
        system.exec(string.format('tar -xzf "%s" -C "%s"', normalized, dir))
    elseif os.isfile(parent .. "/" .. exe) then
        fs.mkdir_p(dir)
        os.mv(parent .. "/" .. exe, dir .. "/" .. exe)
    else
        error("difftastic: archive not found at " .. archive .. " and no extracted " .. exe .. " in " .. parent)
    end

    if not is_win and os.isfile(dir .. "/" .. exe) then
        system.exec(string.format('chmod +x "%s"', dir .. "/" .. exe))
    end

    payload.require({ exe })
    return true
end

function config()
    xvm.add("difft", { bindir = pkginfo.install_dir() })
    -- Group placeholder: the binary is `difft`, while the package name is
    -- `difftastic`. Registering `package.name` with `type = "group"` lets
    -- `xvm info difftastic` and `xlings remove` locate the package without
    -- creating an orphan `difftastic` shim in `bin/`.
    xvm.add(package.name, { type = "group" })
    return true
end

function uninstall()
    xvm.remove("difft")
    xvm.remove(package.name)
    return true
end

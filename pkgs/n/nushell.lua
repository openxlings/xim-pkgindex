-- nushell: a new type of shell (binary: `nu`).
--
-- Official prebuilt archives verified against nushell/nushell release 0.117.0:
--   * SHA256s verified against upstream `SHA256SUMS` and downloaded archives.
--   * POSIX tarballs (`linux`, `macosx`) pack a single top-level directory
--     `nu-<version>-<target>/` containing `nu`, 8 `nu_plugin_*` binaries,
--     `LICENSE`, and `README.txt`.
--   * Windows zips are flat (no enclosing directory) and pack `nu.exe`,
--     `less.exe`, 8 `nu_plugin_*.exe` binaries, `LICENSE`,
--     `LICENSE-for-less.txt`, and `README.txt`.
--   * Linux (`x86_64` static-pie musl, `aarch64` statically linked musl):
--     `nu` and all 8 `nu_plugin_*` ELFs have no `PT_INTERP` and zero `DT_NEEDED`
--     entries (`ldd`: statically linked / not a dynamic executable), so no
--     `xim:glibc` or `xim:gcc-runtime` dependency is needed.
--   * Windows `x86_64`: PE32+ binaries (`nu.exe`, `less.exe`, `nu_plugin_*.exe`)
--     are built with static CRT (import only Windows OS system DLLs; no
--     `VCRUNTIME140.dll`), so no `xim:vcruntime` dependency is needed.
--   * Windows `aarch64` is omitted because upstream `aarch64-pc-windows-msvc`
--     imports `VCRUNTIME140.dll` and `api-ms-win-crt-*` while `xim:vcruntime`
--     currently supports `x86_64` only.
package = {
    spec = "2",

    name = "nushell",
    description = "A new type of shell",
    homepage = "https://www.nushell.sh",
    authors = {"The Nushell Project Developers"},
    maintainers = {"https://github.com/nushell/nushell/graphs/contributors"},
    licenses = {"MIT"},
    repo = "https://github.com/nushell/nushell",
    docs = "https://www.nushell.sh/book/",

    ci = { mirror = true },

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"shell", "cli", "tools"},
    keywords = {"nushell", "nu", "shell", "rust", "pipeline"},

    programs = {"nu"},
    xvm_enable = true,

    extensions = {
        autoupdate = {
            source = "https://github.com/nushell/nushell/releases",
            resources = {
                GLOBAL = {
                    url = {
                        linux = {
                            x86_64 = "https://github.com/nushell/nushell/releases/download/${tag}/nu-${version}-x86_64-unknown-linux-musl.tar.gz",
                            aarch64 = "https://github.com/nushell/nushell/releases/download/${tag}/nu-${version}-aarch64-unknown-linux-musl.tar.gz",
                        },
                        macosx = {
                            x86_64 = "https://github.com/nushell/nushell/releases/download/${tag}/nu-${version}-x86_64-apple-darwin.tar.gz",
                            aarch64 = "https://github.com/nushell/nushell/releases/download/${tag}/nu-${version}-aarch64-apple-darwin.tar.gz",
                        },
                        windows = {
                            x86_64 = "https://github.com/nushell/nushell/releases/download/${tag}/nu-${version}-x86_64-pc-windows-msvc.zip",
                        },
                    },
                    required = true,
                },
            },
        },
    },

    xpm = {
        linux = {
            source = "https://github.com/nushell/nushell/releases/download/${version}/nu-${version}-${arch}-unknown-linux-musl.tar.gz",
            ["latest"] = { ref = "0.117.0" },
            ["0.117.0"] = {
                sha256 = {
                    x86_64 = "2b808786d44af41170a29f8b9a15b5113bb6ea5dda9221098eca932f8a149924",
                    aarch64 = "19966b94ae19f52e2cf0402cb99844ddfa06e2361cf6c77b1b2e29abd17e9188",
                },
            },
        },
        macosx = {
            source = "https://github.com/nushell/nushell/releases/download/${version}/nu-${version}-${arch}-apple-darwin.tar.gz",
            ["latest"] = { ref = "0.117.0" },
            ["0.117.0"] = {
                sha256 = {
                    x86_64 = "f44a99227d1fd19d7da9b4a60adbe32bf45700dc25f1a3cb08e4979dee0c1b2f",
                    aarch64 = "1d0e642ef3bff22113a82749a0fa24a0126f4fea0db46a5909e56e94a4b57527",
                },
            },
        },
        windows = {
            -- Upstream `aarch64-pc-windows-msvc` imports `VCRUNTIME140.dll` and
            -- awaits `xim:vcruntime` ARM64 CRT support; `x86_64` uses static CRT.
            source = "https://github.com/nushell/nushell/releases/download/${version}/nu-${version}-${arch}-pc-windows-msvc.zip",
            ["latest"] = { ref = "0.117.0" },
            ["0.117.0"] = {
                sha256 = {
                    x86_64 = "8a135f25d3f22f1542107eb117e94628af35ce65402cbc098bfb26914227d3b2",
                },
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.system")
import("xim.libxpkg.xvm")
import("xim.pkgindex.payload")

local PLUGINS = {
    "nu_plugin_custom_values",
    "nu_plugin_example",
    "nu_plugin_formats",
    "nu_plugin_gstat",
    "nu_plugin_inc",
    "nu_plugin_polars",
    "nu_plugin_query",
    "nu_plugin_stress_internals",
}

function installed()
    return payload.present({ "nu", "LICENSE" })
        or payload.present({ "nu.exe", "LICENSE" })
end

function install()
    local archive = tostring(pkginfo.install_file())
    local dir = pkginfo.install_dir()
    local normalized = archive:gsub("\\", "/")
    local stem = (normalized:match("([^/]+)$") or ""):gsub("%.tar%.gz$", ""):gsub("%.zip$", "")
    local is_win = normalized:match("%.zip$") ~= nil
    local exe = is_win and "nu.exe" or "nu"

    payload.unpack{ extracted = is_win and nil or stem }

    if not is_win then
        system.exec(string.format('chmod +x "%s"', dir .. "/nu"))
        for _, plugin in ipairs(PLUGINS) do
            local p = dir .. "/" .. plugin
            if os.isfile(p) then
                system.exec(string.format('chmod +x "%s"', p))
            end
        end
    end

    payload.require({ exe, "LICENSE" })
    return true
end

function config()
    local dir = pkginfo.install_dir()
    local ext = os.isfile(dir .. "/nu.exe") and ".exe" or ""
    local binding = package.name .. "@" .. pkginfo.version()

    -- Group placeholder: the binary is `nu`, while the package name is
    -- `nushell`. Registering `package.name` with `type = "group"` lets
    -- `xvm info nushell` and `xlings remove` locate the package without
    -- creating an orphan `nushell` shim in `bin/`.
    xvm.add(package.name, { type = "group" })
    xvm.add("nu", { bindir = dir })
    for _, plugin in ipairs(PLUGINS) do
        if os.isfile(dir .. "/" .. plugin .. ext) then
            xvm.add(plugin, { bindir = dir, binding = binding })
        end
    end
    return true
end

function uninstall()
    for _, plugin in ipairs(PLUGINS) do
        xvm.remove(plugin)
    end
    xvm.remove("nu")
    xvm.remove(package.name)
    return true
end

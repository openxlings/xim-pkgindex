-- mise - The front-end to your dev env (jdx/mise).
--
-- Verified against upstream GitHub release `jdx/mise` v2026.11.14
-- (published 2026-11-24); all six SHA-256 digests match upstream `SHASUMS256.txt`,
-- GitHub release asset digests, and locally downloaded archives.
--
-- Archive layout & binary inspection (v2026.11.14):
--   Every supported archive extracts under a single `mise/` top-level directory:
--     * POSIX (.tar.gz): `mise/bin/mise`, `mise/bin/mise.d`, `mise/man/man1/mise.1`,
--       `mise/share/fish/vendor_conf.d/mise-activate.fish`, `mise/LICENSE`, `mise/README.md`.
--     * Windows (.zip): `mise/bin/mise.exe`, `mise/bin/mise-shim.exe`,
--       `mise/LICENSE`, `mise/README.md`.
--   * linux/x86_64    : mise-v2026.11.14-linux-x64-musl.tar.gz
--                       static-pie ELF (no PT_INTERP; ldd: "statically linked"; zero DT_NEEDED)
--   * linux/aarch64   : mise-v2026.11.14-linux-arm64-musl.tar.gz
--                       statically linked ELF (no PT_INTERP, no .dynamic section, zero DT_NEEDED)
--   * macosx/x86_64   : mise-v2026.11.14-macos-x64.tar.gz (Mach-O 64-bit x86_64)
--   * macosx/aarch64  : mise-v2026.11.14-macos-arm64.tar.gz (Mach-O 64-bit arm64)
--   * windows/x86_64  : mise-v2026.11.14-windows-x64.zip
--                       PE32+ x86-64; mise.exe and mise-shim.exe statically link the MSVC CRT
--                       (import only Windows OS system DLLs, no VCRUNTIME140.dll -> no xim:vcruntime dep)
--   * windows/aarch64 : mise-v2026.11.14-windows-arm64.zip
--                       PE32+ ARM64; mise.exe and mise-shim.exe statically link the MSVC CRT
--                       (import only Windows OS system DLLs, no VCRUNTIME140.dll -> no xim:vcruntime dep)

package = {
    spec = "2",

    name = "mise",
    description = "The front-end to your dev env (dev tools, env vars, task runner)",
    homepage = "https://mise.jdx.dev",
    authors = {"jdx"},
    maintainers = {"https://github.com/jdx/mise/graphs/contributors"},
    licenses = {"MIT"},
    repo = "https://github.com/jdx/mise",
    docs = "https://mise.jdx.dev/",
    ci = { mirror = true },

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"cli", "env", "package-manager", "task-runner", "tools"},
    keywords = {"mise", "rtx", "asdf", "env", "task-runner", "dev-tools", "rust"},

    programs = {"mise"},
    xvm_enable = true,

    extensions = {
        autoupdate = {
            source = "https://github.com/jdx/mise/releases",
            resources = {
                GLOBAL = {
                    url = {
                        linux = {
                            x86_64 = "https://github.com/jdx/mise/releases/download/${tag}/mise-${tag}-linux-x64-musl.tar.gz",
                            aarch64 = "https://github.com/jdx/mise/releases/download/${tag}/mise-${tag}-linux-arm64-musl.tar.gz",
                        },
                        macosx = {
                            x86_64 = "https://github.com/jdx/mise/releases/download/${tag}/mise-${tag}-macos-x64.tar.gz",
                            aarch64 = "https://github.com/jdx/mise/releases/download/${tag}/mise-${tag}-macos-arm64.tar.gz",
                        },
                        windows = {
                            x86_64 = "https://github.com/jdx/mise/releases/download/${tag}/mise-${tag}-windows-x64.zip",
                            aarch64 = "https://github.com/jdx/mise/releases/download/${tag}/mise-${tag}-windows-arm64.zip",
                        },
                    },
                    required = true,
                },
            },
        },
    },

    xpm = {
        linux = {
            source = "https://github.com/jdx/mise/releases/download/v${version}/mise-v${version}-linux-${arch_alias}-musl.tar.gz",
            ["latest"] = { ref = "2026.11.14" },
            ["2026.11.14"] = {
                arch_alias = { x86_64 = "x64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "86a5c3d8cf3d62b45a10ddd6afe8225bada9423e517ec8df7d589aa7d02c171d",
                    aarch64 = "bf73525892d7942b881b885867bb028cab98ed528356c4490364eb1001ef9deb",
                },
            },
        },
        macosx = {
            source = "https://github.com/jdx/mise/releases/download/v${version}/mise-v${version}-macos-${arch_alias}.tar.gz",
            ["latest"] = { ref = "2026.11.14" },
            ["2026.11.14"] = {
                arch_alias = { x86_64 = "x64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "4ad598c502813f63cb9a82518f60e66f25d2c715e5bd5b949ca66323e94bd154",
                    aarch64 = "76ff289e5ef2ffdeec54ad75275795d3e05699cb74b9f2f656652d3d1ddd7d11",
                },
            },
        },
        windows = {
            source = "https://github.com/jdx/mise/releases/download/v${version}/mise-v${version}-windows-${arch_alias}.zip",
            ["latest"] = { ref = "2026.11.14" },
            ["2026.11.14"] = {
                arch_alias = { x86_64 = "x64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "f1a197ba2d5e4b0ccac323038efd55b007846c6d38828baf529439387b61eb5a",
                    aarch64 = "84b775314cb92f394c0974f514c591165c250618be86b1f8829c59a5763b4225",
                },
            },
        },
    },
}

import("xim.libxpkg.pkginfo")
import("xim.libxpkg.xvm")
import("xim.pkgindex.payload")

local REQUIRED_POSIX = { "bin/mise", "LICENSE" }
local REQUIRED_WINDOWS = { "bin/mise.exe", "bin/mise-shim.exe", "LICENSE" }

function installed()
    return payload.present(REQUIRED_POSIX)
        or payload.present(REQUIRED_WINDOWS)
end

function install()
    local archive = tostring(pkginfo.install_file() or "")
    if archive == "" then
        error("mise: install_file is empty")
    end
    local normalized = archive:gsub("\\", "/")
    local parent = normalized:match("^(.*)/[^/]+$") or "."
    if not os.isfile(archive) and not os.isdir(parent .. "/mise") then
        error("mise: neither archive (" .. archive .. ") nor extracted directory (" .. parent .. "/mise) exists")
    end
    local is_win = normalized:match("%.zip$") ~= nil or os.getenv("OS") == "Windows_NT"

    payload.unpack{ extracted = "mise", strip = 1 }
    payload.require(is_win and REQUIRED_WINDOWS or REQUIRED_POSIX)
    return true
end

function config()
    xvm.add("mise", { bindir = pkginfo.install_dir() .. "/bin" })
    return true
end

function uninstall()
    xvm.remove("mise")
    return true
end

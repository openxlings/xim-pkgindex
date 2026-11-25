-- biome — fast formatter and linter for web projects (biomejs/biome).
--
-- Distribution: upstream publishes raw single-file binaries under monorepo
-- release tags `@biomejs/biome@<version>`. All 6 asset basenames are unique
-- across platforms and architectures (`biome-linux-x64-musl`, etc.).
--
-- Verified against biomejs/biome release @biomejs/biome@2.6.9:
--   linux/x86_64    biome-linux-x64-musl    (static-pie ELF, no INTERP, no DT_NEEDED)
--   linux/aarch64   biome-linux-arm64-musl  (statically linked ELF, no DT_NEEDED)
--   macosx/x86_64   biome-darwin-x64        (Mach-O 64-bit x86_64)
--   macosx/aarch64  biome-darwin-arm64      (Mach-O 64-bit arm64)
--   windows/x86_64  biome-win32-x64.exe     (PE32+ x86_64, imports VCRUNTIME140.dll -> xim:vcruntime)
--   windows/aarch64 biome-win32-arm64.exe   (PE32+ ARM64, imports VCRUNTIME140.dll)
--
-- Linux uses the official `-musl` static binaries so no `xim:glibc` or
-- `xim:gcc-runtime` dependency is needed (the `-gnu` builds dynamically link
-- libgcc_s.so.1, libpthread.so.0, libm.so.6, libdl.so.2, libc.so.6).
-- Windows `x86_64` copies app-local CRT DLLs from `xim:vcruntime`; Windows
-- `aarch64` install awaits `xim:vcruntime` ARM64 CRT support.

package = {
    spec = "2",

    name = "biome",
    description = "Fast formatter and linter for JavaScript, TypeScript, JSX, JSON, CSS, and GraphQL",
    homepage = "https://biomejs.dev",
    authors = {"Biome"},
    licenses = {"MIT", "Apache-2.0"},
    repo = "https://github.com/biomejs/biome",
    docs = "https://biomejs.dev/guides/getting-started/",

    ci = { mirror = true },

    type = "package",
    archs = {"x86_64", "aarch64"},
    status = "stable",
    categories = {"cli", "formatter", "linter", "tools"},
    keywords = {"biome", "formatter", "linter", "javascript", "typescript", "json", "css"},

    programs = {"biome"},
    xvm_enable = true,

    -- Verified upstream release assets; no CN mirror has been verified.
    extensions = {
        autoupdate = {
            source = "https://github.com/biomejs/biome/releases",
            tag = "@biomejs/biome@${version}",
            resources = {
                GLOBAL = {
                    required = true,
                    url = {
                        linux = {
                            x86_64 = "https://github.com/biomejs/biome/releases/download/${tag}/biome-linux-x64-musl",
                            aarch64 = "https://github.com/biomejs/biome/releases/download/${tag}/biome-linux-arm64-musl",
                        },
                        macosx = {
                            x86_64 = "https://github.com/biomejs/biome/releases/download/${tag}/biome-darwin-x64",
                            aarch64 = "https://github.com/biomejs/biome/releases/download/${tag}/biome-darwin-arm64",
                        },
                        windows = {
                            x86_64 = "https://github.com/biomejs/biome/releases/download/${tag}/biome-win32-x64.exe",
                            aarch64 = "https://github.com/biomejs/biome/releases/download/${tag}/biome-win32-arm64.exe",
                        },
                    },
                },
            },
        },
    },

    xpm = {
        linux = {
            source = "https://github.com/biomejs/biome/releases/download/@biomejs/biome@${version}/biome-linux-${arch_alias}-musl",
            ["latest"] = { ref = "2.6.9" },
            ["2.6.9"] = {
                arch_alias = { x86_64 = "x64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "b39d1fcf5972f7975edec75ca378be0c8241200292ae05c8b6aeec638354f4fb",
                    aarch64 = "50dad6aea034a9551e5fba75137911c143a78e6beae108e48a6b2dc5a282db97",
                },
            },
        },
        macosx = {
            source = "https://github.com/biomejs/biome/releases/download/@biomejs/biome@${version}/biome-darwin-${arch_alias}",
            ["latest"] = { ref = "2.6.9" },
            ["2.6.9"] = {
                arch_alias = { x86_64 = "x64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "3613b6c703fdbbdb6353a350f245de8910dd81cf5af292b7df39054ea003a739",
                    aarch64 = "7c046458c6505ebb043f2e3402f17fbe185bf311e288ed51ed80cc38b102c6f5",
                },
            },
        },
        windows = {
            deps = {
                runtime = { "xim:vcruntime" },
            },
            source = "https://github.com/biomejs/biome/releases/download/@biomejs/biome@${version}/biome-win32-${arch_alias}.exe",
            ["latest"] = { ref = "2.6.9" },
            ["2.6.9"] = {
                arch_alias = { x86_64 = "x64", aarch64 = "arm64" },
                sha256 = {
                    x86_64 = "12ecf4622bd324046a4e2f0f469fb7c79254d77280277082a187183fa591b48a",
                    aarch64 = "eb4dd23f78c449218ba0d014ec0220c2abb7992b40ef112306785c806a1c537e",
                },
            },
        },
    },
}

import("xim.libxpkg.fs")
import("xim.libxpkg.pkginfo")
import("xim.libxpkg.system")
import("xim.libxpkg.xvm")

local function _is_windows_payload(file)
    return tostring(file):lower():match("%.exe$") ~= nil
end

function installed()
    local dir = pkginfo.install_dir()
    return os.isfile(dir .. "/biome") or os.isfile(dir .. "/biome.exe")
end

function install()
    local src = pkginfo.install_file()
    local dir = pkginfo.install_dir()
    local is_win = _is_windows_payload(src)
    local target = dir .. (is_win and "/biome.exe" or "/biome")

    os.tryrm(dir)
    os.mkdir(dir)
    os.mv(src, target)

    if is_win then
        if not pkginfo.dep_install_dir then
            error("biome: xim:vcruntime runtime dep lookup is unavailable")
        end
        local crt = assert(pkginfo.dep_install_dir("xim:vcruntime"),
                           "biome: xim:vcruntime payload directory is missing")
        local copied = 0
        for _, dll in ipairs(fs.files(crt .. "/bin") or {}) do
            os.cp(dll, dir)
            copied = copied + 1
        end
        if copied == 0 then
            error("biome: no CRT DLLs found in " .. crt .. "/bin")
        end
    else
        system.exec(string.format([[chmod +x "%s"]], target))
    end

    if not os.isfile(target) then
        error("biome: executable missing after install at " .. target)
    end
    return true
end

function config()
    xvm.add("biome", { bindir = pkginfo.install_dir() })
    return true
end

function uninstall()
    xvm.remove("biome")
    return true
end
